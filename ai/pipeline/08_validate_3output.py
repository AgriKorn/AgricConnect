"""
Spot-check the new 3-output agriconnect.tflite: for a sample image from
every crop_freshness test folder, confirm the model's shelf_life_days output
exactly matches shelf_life.py's get_shelf_life_days(predicted_crop,
predicted_freshness) -- i.e. the in-graph lookup table is consistent with
the standalone Python module the app/backend would otherwise call.
"""
import os
import sys
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from shelf_life import get_shelf_life_days  # noqa: E402

MODEL_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "model", "agriconnect.tflite"))
TEST_DIR = Path(os.environ.get("AGRICONNECT_TEST_DIR", "../AgriConnect_Final_dataset/test"))  # dataset not committed; set env var or edit path
IMG_SIZE = (224, 224)

CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH, num_threads=4)
interpreter.allocate_tensors()
input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()


def load_and_preprocess(image_path):
    img = Image.open(image_path).convert("RGB")
    img = np.array(img).astype(np.float32)
    t = tf.convert_to_tensor(img)
    t = tf.image.resize_with_pad(t, IMG_SIZE[0], IMG_SIZE[1])
    t = tf.expand_dims(t, axis=0)
    return t.numpy()


def predict(image_path):
    x = load_and_preprocess(image_path)
    interpreter.set_tensor(input_details[0]['index'], x)
    interpreter.invoke()
    crop_out = interpreter.get_tensor(output_details[0]['index'])[0]
    fresh_out = interpreter.get_tensor(output_details[1]['index'])[0]
    shelf_life = float(interpreter.get_tensor(output_details[2]['index'])[0])
    return crop_out, fresh_out, shelf_life


folders = sorted(TEST_DIR.iterdir())
n_checked = 0
n_mismatch = 0

print(f"{'folder':22s} {'pred_crop':10s} {'pred_fresh':10s} {'model_days':>10s} {'lookup_days':>11s} {'match':>6s}")
for folder in folders:
    if not folder.is_dir():
        continue
    images = [p for p in folder.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}]
    if not images:
        continue
    img_path = sorted(images)[0]

    crop_out, fresh_out, model_days = predict(img_path)
    pred_crop = CROP_NAMES[int(np.argmax(crop_out))]
    pred_fresh = FRESH_NAMES[int(np.argmax(fresh_out))]
    expected_days = get_shelf_life_days(pred_crop, pred_fresh)

    match = abs(model_days - expected_days) < 1e-6
    n_checked += 1
    if not match:
        n_mismatch += 1
    print(f"{folder.name:22s} {pred_crop:10s} {pred_fresh:10s} {model_days:10.1f} {expected_days:11d} "
          f"{'OK' if match else 'MISMATCH!':>6s}")

print(f"\n{n_checked} checked, {n_mismatch} mismatches.")
if n_mismatch == 0:
    print("✅ In-graph shelf_life_days output is fully consistent with shelf_life.py's lookup table.")
else:
    print("⚠️  Mismatches found — investigate before shipping.")
