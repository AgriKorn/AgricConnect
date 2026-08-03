"""
Add shelf_life_days as a THIRD native output of agriconnect.tflite, alongside
crop_output and fresh_output — so a single on-device inference call returns
crop type, freshness score, AND shelf life, matching the product requirement
("predicts the crop, its freshness and the shelf life").

Approach: a ShelfLifeLookup Keras Layer, added as a third branch in the same
Functional-API graph as crop_output/fresh_output, takes argmax of each head
and GATHERs the corresponding day-count out of a constant [9*3] lookup table
built directly from shelf_life.py (single source of truth — no duplicated
numbers here). Exported the same way script 06's working conversion did
(model.export() -> TFLiteConverter.from_saved_model), which handles Keras's
variable-freezing correctly; an earlier attempt wrapping the model in a raw
tf.Module + tf.saved_model.save hit an MLIR "missing attribute 'value'"
error during conversion, so that path was abandoned in favor of this one.

Deliberately a Layer subclass, NOT a keras.layers.Lambda: Lambda layers
serialize their Python function as marshaled bytecode, which is exactly what
made every other checkpoint in this repo (agriconnect_clean_model.h5,
best_model_phase01.keras, etc.) fail to reload in this environment ("bad
marshal data" / "could not be loaded" errors — see ai_eda/ for the
investigation). A registered Layer subclass stores its logic as class code,
not a marshaled closure, so it doesn't hit that failure mode. tf.argmax and
tf.gather are both standard TFLite builtins (ARG_MAX, GATHER), so the "no
Flex ops" property confirmed by structural EDA is preserved.
"""
import os
import shutil
import sys

import keras
import numpy as np
import tensorflow as tf
from keras import layers, Model
from keras.applications import MobileNetV2

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from shelf_life import CROP_NAMES, FRESH_NAMES, SHELF_LIFE_DAYS  # noqa: E402

IMG_SIZE = (224, 224)
NUM_CROPS = len(CROP_NAMES)
NUM_FRESH = len(FRESH_NAMES)

WEIGHTS_PATH = "../weights/agriconnect_corrected.weights.h5"
SAVED_DIR = "_tmp_saved_model"  # local scratch, not committed
CURRENT_TFLITE = "../model/agriconnect.tflite"
BACKUP_TFLITE = "../model/agriconnect_PRE_shelf_life_output_backup.tflite"  # local only unless you choose to commit it


# Flat [NUM_CROPS * NUM_FRESH] lookup table, index = crop_idx * NUM_FRESH + fresh_idx.
# Built straight from shelf_life.py's SHELF_LIFE_DAYS so there is exactly one
# place (shelf_life.py) that owns these numbers.
print("[1/6] Building shelf-life lookup table from shelf_life.py...")
flat_table = []
for crop in CROP_NAMES:
    for stage in FRESH_NAMES:
        flat_table.append(float(SHELF_LIFE_DAYS[crop][stage]))
print(f"      Table ({len(flat_table)} entries): {flat_table}")


@keras.saving.register_keras_serializable(package="agriconnect")
class ShelfLifeLookup(layers.Layer):
    """Gathers a day-count out of a constant crop x freshness table, given
    the two classification heads' argmax indices. A proper Layer subclass
    (not a Lambda) -- its logic lives in registered class code, not
    marshaled Python bytecode, so it doesn't hit the same reload failure
    that broke every other .keras/.h5 checkpoint in this repo."""

    def __init__(self, table, num_fresh, **kwargs):
        super().__init__(**kwargs)
        self.table_values = list(table)
        self.num_fresh = num_fresh
        self._table_const = tf.constant(self.table_values, dtype=tf.float32)

    def call(self, inputs):
        crop_output, fresh_output = inputs
        crop_idx = tf.argmax(crop_output, axis=-1, output_type=tf.int32)
        fresh_idx = tf.argmax(fresh_output, axis=-1, output_type=tf.int32)
        flat_idx = crop_idx * self.num_fresh + fresh_idx
        return tf.gather(self._table_const, flat_idx)

    def get_config(self):
        config = super().get_config()
        config.update({"table": self.table_values, "num_fresh": self.num_fresh})
        return config


print("\n[2/6] Rebuilding architecture (Functional API, shelf-life head included) "
      "+ loading fine-tuned (corrected) weights...")
inputs = layers.Input(shape=(*IMG_SIZE, 3), name="image_input")
base_model = MobileNetV2(input_shape=(*IMG_SIZE, 3), include_top=False, weights=None)
base_model.trainable = False
x = keras.applications.mobilenet_v2.preprocess_input(inputs)
x = base_model(x, training=False)
x = layers.GlobalAveragePooling2D(name="gap")(x)
x = layers.BatchNormalization(name="bn_shared")(x)
x = layers.Dropout(0.3, name="drop_shared")(x)
x = layers.Dense(256, activation="relu", name="dense_shared")(x)
x = layers.BatchNormalization(name="bn_trunk")(x)
x = layers.Dropout(0.3, name="drop_trunk")(x)
crop_branch = layers.Dense(128, activation="relu", name="dense_crop")(x)
crop_branch = layers.Dropout(0.15, name="drop_crop")(crop_branch)
crop_output = layers.Dense(NUM_CROPS, activation="softmax", name="crop_output")(crop_branch)
fresh_branch = layers.Dense(128, activation="relu", name="dense_fresh")(x)
fresh_branch = layers.Dropout(0.15, name="drop_fresh")(fresh_branch)
fresh_output = layers.Dense(NUM_FRESH, activation="softmax", name="fresh_output")(fresh_branch)

shelf_life_days = ShelfLifeLookup(flat_table, NUM_FRESH, name="shelf_life_days")([crop_output, fresh_output])

model_3out = Model(
    inputs=inputs,
    outputs={"crop_output": crop_output, "fresh_output": fresh_output, "shelf_life_days": shelf_life_days},
    name="AgriConnect_MobileNetV2_ShelfLife",
)

# The base architecture (crop_output/fresh_output branches) is identical to
# the 2-output model whose weights we already validated -- load by name so
# only those matching layers (everything except the new ShelfLifeLookup,
# which has no weights anyway) get restored.
model_3out.load_weights(WEIGHTS_PATH, skip_mismatch=False)
print(f"      Loaded weights from {WEIGHTS_PATH}")

test_out = model_3out(tf.zeros((1, 224, 224, 3), dtype=tf.float32), training=False)
print(f"      Eager test OK. Keys: {list(test_out.keys())}, "
      f"shelf_life_days shape={test_out['shelf_life_days'].shape}")

print(f"\n[3/6] Exporting SavedModel -> {SAVED_DIR}/")
if os.path.exists(SAVED_DIR):
    shutil.rmtree(SAVED_DIR)
model_3out.export(SAVED_DIR)

print("\n[4/6] Converting to TFLite (dynamic range quantization)...")
converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_DIR)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
size_mb = len(tflite_model) / (1024 * 1024)
print(f"      New TFLite size: {size_mb:.2f} MB")

if os.path.exists(CURRENT_TFLITE):
    shutil.copy2(CURRENT_TFLITE, BACKUP_TFLITE)
    print(f"      Backed up {CURRENT_TFLITE} -> {BACKUP_TFLITE}")
with open(CURRENT_TFLITE, "wb") as f:
    f.write(tflite_model)
print(f"      Wrote new 3-output model -> {CURRENT_TFLITE}")

print("\n[6/6] Sanity check on new TFLite model...")
interpreter = tf.lite.Interpreter(model_path=CURRENT_TFLITE)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print(f"      Input:  {input_details[0]['shape'].tolist()} {input_details[0]['dtype'].__name__}")
for d in output_details:
    print(f"      Output: name={d['name']!r} shape={d['shape'].tolist()} dtype={d['dtype'].__name__}")

dummy_np = np.zeros((1, 224, 224, 3), dtype=np.float32)
interpreter.set_tensor(input_details[0]['index'], dummy_np)
interpreter.invoke()
for d in output_details:
    val = interpreter.get_tensor(d['index'])
    print(f"      {d['name']}: shape={val.shape} sample={val.flatten()[:5]}")

print("\n✅ 3-output conversion complete: crop_output, fresh_output, shelf_life_days.")
