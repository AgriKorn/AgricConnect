"""
SUPERSEDED by 07_add_shelf_life_output.py — running this script produces a
2-output model (crop_output, fresh_output only) and will REGRESS
model/agriconnect.tflite, dropping the shelf_life_days output the shipped
model currently has. Kept only as a record of the intermediate conversion
step between the corrective fine-tune and the final 3-output model. Use 07
instead for any real reconversion.

Convert the corrective fine-tune's weights (weights/agriconnect_corrected.weights.h5)
into a new agriconnect.tflite, using the same recipe as the project's own
tflite_model.ipynb: export SavedModel -> TFLiteConverter with dynamic-range
quantization (tf.lite.Optimize.DEFAULT).

Backs up the previous agriconnect.tflite first (non-destructive) so the old
one can be restored if the new one somehow regresses.
"""
import os
import shutil

import keras
import numpy as np
import tensorflow as tf
from keras import layers, Model
from keras.applications import MobileNetV2

IMG_SIZE = (224, 224)
NUM_CROPS = 9
NUM_FRESH = 3

WEIGHTS_PATH = "../weights/agriconnect_corrected.weights.h5"
SAVED_DIR = "_tmp_saved_model"  # local scratch, not committed
OLD_TFLITE = "../model/agriconnect.tflite"
BACKUP_TFLITE = "../model/agriconnect_PRE_mango_fix_backup.tflite"  # local only unless you choose to commit it
NEW_TFLITE = "../model/agriconnect.tflite"  # overwrite in place, after backup

CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']


def build_agriconnect_model(dropout_rate=0.3):
    inputs = layers.Input(shape=(*IMG_SIZE, 3), name="image_input")
    base_model = MobileNetV2(input_shape=(*IMG_SIZE, 3), include_top=False, weights=None)
    base_model.trainable = False
    x = keras.applications.mobilenet_v2.preprocess_input(inputs)
    x = base_model(x, training=False)
    x = layers.GlobalAveragePooling2D(name="gap")(x)
    x = layers.BatchNormalization(name="bn_shared")(x)
    x = layers.Dropout(dropout_rate, name="drop_shared")(x)
    x = layers.Dense(256, activation="relu", name="dense_shared")(x)
    x = layers.BatchNormalization(name="bn_trunk")(x)
    x = layers.Dropout(dropout_rate, name="drop_trunk")(x)
    crop_branch = layers.Dense(128, activation="relu", name="dense_crop")(x)
    crop_branch = layers.Dropout(dropout_rate * 0.5, name="drop_crop")(crop_branch)
    crop_output = layers.Dense(NUM_CROPS, activation="softmax", name="crop_output")(crop_branch)
    fresh_branch = layers.Dense(128, activation="relu", name="dense_fresh")(x)
    fresh_branch = layers.Dropout(dropout_rate * 0.5, name="drop_fresh")(fresh_branch)
    fresh_output = layers.Dense(NUM_FRESH, activation="softmax", name="fresh_output")(fresh_branch)
    model = Model(inputs=inputs,
                  outputs={"crop_output": crop_output, "fresh_output": fresh_output},
                  name="AgriConnect_MobileNetV2")
    return model


print("[1/5] Rebuilding architecture + loading fine-tuned weights...")
model = build_agriconnect_model()
model.load_weights(WEIGHTS_PATH)
print(f"      Loaded weights from {WEIGHTS_PATH}")

print(f"\n[2/5] Exporting SavedModel -> {SAVED_DIR}/")
if os.path.exists(SAVED_DIR):
    shutil.rmtree(SAVED_DIR)
model.export(SAVED_DIR)

print("\n[3/5] Converting to TFLite (dynamic range quantization)...")
converter = tf.lite.TFLiteConverter.from_saved_model(SAVED_DIR)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
size_mb = len(tflite_model) / (1024 * 1024)
print(f"      New TFLite size: {size_mb:.2f} MB")

print(f"\n[4/5] Backing up previous model -> {BACKUP_TFLITE}")
if os.path.exists(OLD_TFLITE):
    shutil.copy2(OLD_TFLITE, BACKUP_TFLITE)
    print(f"      Backed up {OLD_TFLITE} -> {BACKUP_TFLITE}")

with open(NEW_TFLITE, "wb") as f:
    f.write(tflite_model)
print(f"      Wrote new model -> {NEW_TFLITE}")

print("\n[5/5] Sanity check on new TFLite model...")
interpreter = tf.lite.Interpreter(model_path=NEW_TFLITE)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()
print(f"      Input  shape: {input_details[0]['shape'].tolist()} dtype={input_details[0]['dtype'].__name__}")
for d in output_details:
    print(f"      Output: name={d['name']!r} shape={d['shape'].tolist()}")

dummy = np.zeros((1, 224, 224, 3), dtype=np.float32)
interpreter.set_tensor(input_details[0]['index'], dummy)
interpreter.invoke()
crop_out = interpreter.get_tensor(output_details[0]['index'])
fresh_out = interpreter.get_tensor(output_details[1]['index'])
print(f"      Dummy inference OK. crop shape={crop_out.shape} fresh shape={fresh_out.shape}")
print("\n✅ Conversion complete.")
