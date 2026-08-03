"""
Investigate the mango -> cucumber confusion found in the full-test-set eval
(330/1285 mango images misclassified as cucumber, virtually all one-directional).
Breaks it down by mango's freshness subfolder (aging/fresh/spoiled) to see if
the confusion is concentrated in one stage (e.g. unripe green mango looking
like cucumber) or spread evenly (more likely a genuine feature-overlap /
data problem).
"""
import os
import time
from pathlib import Path
from collections import defaultdict

import numpy as np
import tensorflow as tf
from PIL import Image

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
    return crop_out


mango_folders = sorted(TEST_DIR.glob("mango_*"))
print(f"Mango subfolders: {[f.name for f in mango_folders]}\n")

by_stage = defaultdict(lambda: {"total": 0, "correct": 0, "as_cucumber": 0})
worst_examples = []  # (confidence_gap, path, mango_prob, cucumber_prob)

t0 = time.time()
n = 0
for folder in mango_folders:
    stage = folder.name.split("_", 1)[1]
    images = [p for p in folder.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}]
    for img_path in images:
        try:
            crop_out = predict(img_path)
        except Exception as e:
            print(f"  skip {img_path}: {e}")
            continue
        n += 1
        pred_i = int(np.argmax(crop_out))
        pred = CROP_NAMES[pred_i]
        by_stage[stage]["total"] += 1
        if pred == "mango":
            by_stage[stage]["correct"] += 1
        if pred == "cucumber":
            by_stage[stage]["as_cucumber"] += 1
            mango_p = float(crop_out[CROP_NAMES.index("mango")])
            cuc_p = float(crop_out[CROP_NAMES.index("cucumber")])
            worst_examples.append((cuc_p - mango_p, str(img_path), mango_p, cuc_p))

elapsed = time.time() - t0
print(f"Processed {n} mango images in {elapsed:.0f}s\n")

print("Breakdown by mango freshness stage:")
for stage, d in by_stage.items():
    tot = d["total"]
    print(f"  mango_{stage:8s}: total={tot:4d}  correct={d['correct']:4d} "
          f"({d['correct']/tot*100:5.1f}%)  misclassified_as_cucumber={d['as_cucumber']:4d} "
          f"({d['as_cucumber']/tot*100:5.1f}%)")

worst_examples.sort(reverse=True)
print("\nTop 10 most confident mango->cucumber misclassifications (largest cucumber-mango prob gap):")
for gap, path, mango_p, cuc_p in worst_examples[:10]:
    print(f"  gap={gap*100:5.1f}pp  mango_prob={mango_p*100:5.1f}%  cucumber_prob={cuc_p*100:5.1f}%  {path}")
