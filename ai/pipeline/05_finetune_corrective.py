"""
Corrective fine-tune script, kept for reproducibility and for further
iteration. Originally run against the project's old `agriconnect_clean_model.h5`
on a CORRECTED dataset (269 mango photos that were mislabeled as
cucumber_fresh, moved into mango_fresh — see pipeline/04_mango_cucumber_investigation.py
and MODEL_REPORT.md §3 for the root-cause finding). That run produced
weights/agriconnect_corrected.weights.h5, which is what's checked into this
repo and what SOURCE_WEIGHTS points at below — so running this script as-is
CONTINUES fine-tuning from the current shipped checkpoint on the same
corrected dataset, rather than repeating the original one-off fix. Useful if
you want to push further on the residual mango (77.7%) / cucumber (83.1%)
weakness noted in MODEL_REPORT.md §3.

Why fine-tune rather than a full retrain-from-scratch:
  - Every other class is already good (90.8%-99.9% crop accuracy in the
    original run). The bug was localized to a training-data labeling error,
    not a general model capacity problem.
  - The original `agriconnect_clean_model.h5` could not be loaded via
    keras.models.load_model() (legacy HDF5 Lambda-layer config uses
    marshaled bytecode incompatible with the installed Keras/TF version —
    see MODEL_REPORT.md §4). model.load_weights() on a freshly-built,
    architecturally-identical model DOES work, since it only restores
    weight arrays by layer name and skips the broken Lambda config path.
    That's what this script does — and it's a good habit to keep even now
    that SOURCE_WEIGHTS is itself weights-only.
  - Mirrors the project's own Phase-2 fine-tuning recipe from
    training_pipeline.ipynb: unfreeze top 30 MobileNetV2 layers, LR=1e-5.

Saves weights only (`.weights.h5`), not a full model, to sidestep the same
HDF5/Keras full-model serialization fragility described above.

After running, use pipeline/07_add_shelf_life_output.py to reconvert the
updated weights into model/agriconnect.tflite (it rebuilds the 3-output
graph — crop, freshness, shelf_life_days — from any weights checkpoint).
"""
import json
import os
import time

import keras
import numpy as np
import tensorflow as tf
from keras import layers, Model
from keras.applications import MobileNetV2

DATA_DIR = os.environ.get("AGRICONNECT_DATA_DIR", "../AgriConnect_Final_dataset")  # dataset not committed; set env var or edit path
IMG_SIZE = (224, 224)
BATCH_SIZE = 32

CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']
NUM_CROPS = len(CROP_NAMES)
NUM_FRESH = len(FRESH_NAMES)

THREE_STAGE_CROPS = ['carrot', 'mango', 'pepper', 'plantain', 'potato', 'tomato']
TWO_STAGE_CROPS = ['cucumber', 'okra', 'orange']
MIN_IMAGES_PER_CLASS = 300

SOURCE_WEIGHTS = "../weights/agriconnect_corrected.weights.h5"  # continue from the already-corrected checkpoint (the original agriconnect_clean_model.h5 this was first run against is not committed - see MODEL_REPORT.md §4 for why)
OUT_WEIGHTS = "../weights/agriconnect_corrected.weights.h5"
OUT_LOG = "../results/finetune_history.json"


# ---------------------------------------------------------------------------
# Model (identical to training_pipeline.ipynb's build_agriconnect_model)
# ---------------------------------------------------------------------------
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
    return model, base_model


def compile_model(model, learning_rate, crop_loss_weight=0.4, fresh_loss_weight=0.6):
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=learning_rate),
        loss={"crop_output": "categorical_crossentropy", "fresh_output": "categorical_crossentropy"},
        loss_weights={"crop_output": crop_loss_weight, "fresh_output": fresh_loss_weight},
        metrics={
            "crop_output": [keras.metrics.CategoricalAccuracy(name="crop_acc")],
            "fresh_output": [keras.metrics.CategoricalAccuracy(name="fresh_acc")],
        },
    )
    return model


def unfreeze_top_layers(model, base_model, num_layers_to_unfreeze=30, new_lr=1e-5):
    base_model.trainable = True
    for layer in base_model.layers[:-num_layers_to_unfreeze]:
        layer.trainable = False
    model = compile_model(model, learning_rate=new_lr)
    return model


# ---------------------------------------------------------------------------
# Data pipeline (identical to training_pipeline.ipynb's build_dataset)
# ---------------------------------------------------------------------------
def get_stages_for_crop(crop_name):
    if crop_name in TWO_STAGE_CROPS:
        return ['aging', 'spoiled']
    return ['aging', 'fresh', 'spoiled']


def load_image(path, crop_label, fresh_label):
    image_bytes = tf.io.read_file(path)
    image = tf.image.decode_image(image_bytes, channels=3, expand_animations=False)
    image.set_shape([None, None, 3])
    image = tf.image.resize_with_pad(image, IMG_SIZE[0], IMG_SIZE[1])
    image = tf.cast(image, tf.float32)
    crop_onehot = tf.one_hot(crop_label, NUM_CROPS)
    fresh_onehot = tf.one_hot(fresh_label, NUM_FRESH)
    return image, {"crop_output": crop_onehot, "fresh_output": fresh_onehot}


def augment_image(image, labels):
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_flip_up_down(image)
    image = tf.image.random_brightness(image, max_delta=0.15)
    image = tf.image.random_contrast(image, lower=0.85, upper=1.15)
    image = tf.image.random_saturation(image, lower=0.8, upper=1.2)
    image = tf.clip_by_value(image, 0.0, 255.0)
    return image, labels


def build_dataset(data_dir, split='train', batch_size=BATCH_SIZE,
                  oversample=True, min_images=MIN_IMAGES_PER_CLASS, shuffle=True):
    image_paths, crop_labels, fresh_labels = [], [], []
    split_dir = os.path.join(data_dir, split)

    for crop in CROP_NAMES:
        crop_idx = CROP_NAMES.index(crop)
        for stage in get_stages_for_crop(crop):
            folder_name = f"{crop}_{stage}"
            stage_dir = os.path.join(split_dir, folder_name)
            if not os.path.exists(stage_dir):
                continue
            fresh_idx = FRESH_NAMES.index(stage)
            files = [os.path.join(stage_dir, f) for f in os.listdir(stage_dir)
                     if f.lower().endswith(('.jpg', '.jpeg', '.png'))]
            n = len(files)
            if oversample and split == 'train' and 0 < n < min_images:
                repeats = int(np.ceil(min_images / n))
                files = (files * repeats)[:min_images]
            image_paths.extend(files)
            crop_labels.extend([crop_idx] * len(files))
            fresh_labels.extend([fresh_idx] * len(files))

    print(f"  {split}: {len(image_paths)} images")
    dataset = tf.data.Dataset.from_tensor_slices((image_paths, crop_labels, fresh_labels))
    dataset = dataset.map(lambda p, c, f: load_image(p, c, f), num_parallel_calls=tf.data.AUTOTUNE)
    if split == 'train':
        dataset = dataset.map(augment_image, num_parallel_calls=tf.data.AUTOTUNE)
        if shuffle:
            dataset = dataset.shuffle(buffer_size=2000, seed=42)
    dataset = dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return dataset


class CheckpointEveryNSteps(keras.callbacks.Callback):
    """Belt-and-braces checkpointing: a prior background eval job in this
    session got silently killed by session teardown between turns, losing
    all progress. Saving weights every N steps (not just per epoch) means a
    repeat of that can't wipe out an hour of fine-tuning."""
    def __init__(self, every_n_steps, path):
        super().__init__()
        self.every_n_steps = every_n_steps
        self.path = path
        self.step = 0

    def on_train_batch_end(self, batch, logs=None):
        self.step += 1
        if self.step % self.every_n_steps == 0:
            self.model.save_weights(self.path)


class JSONHistoryLogger(keras.callbacks.Callback):
    def __init__(self, path):
        super().__init__()
        self.path = path
        self.history = []

    def on_epoch_end(self, epoch, logs=None):
        entry = {"epoch": epoch + 1, **{k: float(v) for k, v in (logs or {}).items()}}
        self.history.append(entry)
        with open(self.path, "w") as f:
            json.dump(self.history, f, indent=2)
        print(f"[history saved] epoch {epoch + 1}: {entry}", flush=True)


if __name__ == "__main__":
    print("Building model + loading weights from", SOURCE_WEIGHTS, flush=True)
    model, base_model = build_agriconnect_model()
    model.load_weights(SOURCE_WEIGHTS)
    print("Weights loaded OK.", flush=True)

    model = unfreeze_top_layers(model, base_model, num_layers_to_unfreeze=30, new_lr=1e-5)
    trainable = sum(1 for l in base_model.layers if l.trainable)
    print(f"Fine-tuning: {trainable}/{len(base_model.layers)} MobileNetV2 layers unfrozen (lr=1e-5)", flush=True)

    print("\nBuilding datasets (corrected labels)...", flush=True)
    train_ds = build_dataset(DATA_DIR, split='train', oversample=True)
    val_ds = build_dataset(DATA_DIR, split='val', oversample=False)

    os.makedirs(os.path.dirname(OUT_WEIGHTS), exist_ok=True)
    callbacks = [
        CheckpointEveryNSteps(every_n_steps=150, path=OUT_WEIGHTS),
        JSONHistoryLogger(OUT_LOG),
        keras.callbacks.EarlyStopping(
            monitor="val_fresh_output_fresh_acc", patience=2,
            restore_best_weights=True, mode="max", verbose=1,
        ),
    ]

    print("\nStarting corrective fine-tune: 3 epochs, full corrected train set...", flush=True)
    t0 = time.time()
    history = model.fit(
        train_ds,
        validation_data=val_ds,
        epochs=3,
        callbacks=callbacks,
        verbose=2,
    )
    print(f"\nFine-tune done in {(time.time()-t0)/60:.1f} min", flush=True)

    model.save_weights(OUT_WEIGHTS)
    print(f"Final weights saved -> {OUT_WEIGHTS}", flush=True)
