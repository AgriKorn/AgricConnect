"""
Functional EDA / evaluation of agriconnect.tflite against the FULL test split
(8,261 images across 24 populated crop_freshness folders).

Produces:
  - overall crop accuracy / freshness accuracy
  - per-class accuracy (crop and freshness)
  - confusion matrices (raw counts, saved as JSON + PNG)
  - confidence distribution stats (mean confidence for correct vs wrong)
  - per-image latency stats
  - flags dataset/label mismatches (e.g. crop folders with no matching CROP_NAMES entry)
"""
import json
import os
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

MODEL_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "model", "agriconnect.tflite"))
TEST_DIR = Path(os.environ.get("AGRICONNECT_TEST_DIR", "../AgriConnect_Final_dataset/test"))  # dataset not committed; set env var or edit path
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "results")

CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']
IMG_SIZE = (224, 224)

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
    t0 = time.perf_counter()
    interpreter.invoke()
    latency = time.perf_counter() - t0
    crop_out = interpreter.get_tensor(output_details[0]['index'])[0]
    fresh_out = interpreter.get_tensor(output_details[1]['index'])[0]
    return crop_out, fresh_out, latency


# ---------------------------------------------------------------------------
# Discover dataset folders and cross-check against model's label vocabulary
# ---------------------------------------------------------------------------
folders = sorted([d for d in TEST_DIR.iterdir() if d.is_dir()])
dataset_crops = set()
skipped_folders = []
valid_folders = []
for d in folders:
    try:
        crop, freshness = d.name.lower().split("_", 1)
    except ValueError:
        skipped_folders.append(d.name)
        continue
    dataset_crops.add(crop)
    if crop not in CROP_NAMES or freshness not in FRESH_NAMES:
        skipped_folders.append(d.name)
        continue
    valid_folders.append((d, crop, freshness))

print(f"Dataset test folders: {len(folders)}, usable: {len(valid_folders)}, skipped: {skipped_folders}", flush=True)
print(f"Dataset crop vocabulary: {sorted(dataset_crops)}", flush=True)
print(f"Model crop vocabulary : {sorted(CROP_NAMES)}", flush=True)
print(f"Crops in dataset but NOT in model: {sorted(dataset_crops - set(CROP_NAMES))}", flush=True)
print(f"Crops in model but NOT in dataset: {sorted(set(CROP_NAMES) - dataset_crops)}", flush=True)

# ---------------------------------------------------------------------------
# Full evaluation
# ---------------------------------------------------------------------------
n_crop = len(CROP_NAMES)
n_fresh = len(FRESH_NAMES)
crop_idx = {c: i for i, c in enumerate(CROP_NAMES)}
fresh_idx = {c: i for i, c in enumerate(FRESH_NAMES)}

cm_crop = np.zeros((n_crop, n_crop), dtype=np.int64)
cm_fresh = np.zeros((n_fresh, n_fresh), dtype=np.int64)

per_class_crop_total = defaultdict(int)
per_class_crop_correct = defaultdict(int)
per_class_fresh_total = defaultdict(int)
per_class_fresh_correct = defaultdict(int)

conf_correct_crop, conf_wrong_crop = [], []
conf_correct_fresh, conf_wrong_fresh = [], []
latencies = []

n_total = 0
n_crop_correct = 0
n_fresh_correct = 0
n_both_correct = 0

t_start = time.time()
for folder, crop, freshness in valid_folders:
    images = [p for p in folder.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}]
    for img_path in images:
        try:
            crop_out, fresh_out, lat = predict(img_path)
        except Exception as e:
            print(f"  [skip, decode error] {img_path}: {e}")
            continue

        latencies.append(lat)
        n_total += 1

        p_crop_i = int(np.argmax(crop_out))
        p_fresh_i = int(np.argmax(fresh_out))
        a_crop_i = crop_idx[crop]
        a_fresh_i = fresh_idx[freshness]

        cm_crop[a_crop_i, p_crop_i] += 1
        cm_fresh[a_fresh_i, p_fresh_i] += 1

        per_class_crop_total[crop] += 1
        per_class_fresh_total[freshness] += 1

        crop_correct = p_crop_i == a_crop_i
        fresh_correct = p_fresh_i == a_fresh_i

        if crop_correct:
            n_crop_correct += 1
            per_class_crop_correct[crop] += 1
            conf_correct_crop.append(float(crop_out[p_crop_i]))
        else:
            conf_wrong_crop.append(float(crop_out[p_crop_i]))

        if fresh_correct:
            n_fresh_correct += 1
            per_class_fresh_correct[freshness] += 1
            conf_correct_fresh.append(float(fresh_out[p_fresh_i]))
        else:
            conf_wrong_fresh.append(float(fresh_out[p_fresh_i]))

        if crop_correct and fresh_correct:
            n_both_correct += 1

    if n_total % 500 < len(images):
        elapsed = time.time() - t_start
        print(f"  ...{n_total} images done ({elapsed:.0f}s elapsed)", flush=True)
        # Checkpoint so a killed process still leaves usable partial results.
        ckpt = {
            "n_total_so_far": n_total,
            "crop_accuracy_pct_so_far": round(n_crop_correct / n_total * 100, 2),
            "freshness_accuracy_pct_so_far": round(n_fresh_correct / n_total * 100, 2),
            "elapsed_s": elapsed,
        }
        with open(os.path.join(OUT_DIR, "functional_eval_checkpoint.json"), "w") as f:
            json.dump(ckpt, f, indent=2)

elapsed_total = time.time() - t_start
print(f"\nDone. {n_total} images evaluated in {elapsed_total:.1f}s "
      f"({elapsed_total/max(n_total,1)*1000:.1f} ms/image avg wall time incl. I/O).")

crop_acc = n_crop_correct / n_total * 100
fresh_acc = n_fresh_correct / n_total * 100
both_acc = n_both_correct / n_total * 100

print("\n" + "=" * 70)
print("OVERALL RESULTS")
print("=" * 70)
print(f"Total images:         {n_total}")
print(f"Crop accuracy:        {crop_acc:.2f}%")
print(f"Freshness accuracy:   {fresh_acc:.2f}%")
print(f"Both-correct accuracy:{both_acc:.2f}%")

print("\nPer-class CROP accuracy:")
for c in CROP_NAMES:
    tot = per_class_crop_total.get(c, 0)
    cor = per_class_crop_correct.get(c, 0)
    if tot:
        print(f"  {c:10s}: {cor:4d}/{tot:4d}  ({cor/tot*100:5.1f}%)")
    else:
        print(f"  {c:10s}: NO TEST IMAGES")

print("\nPer-class FRESHNESS accuracy:")
for f in FRESH_NAMES:
    tot = per_class_fresh_total.get(f, 0)
    cor = per_class_fresh_correct.get(f, 0)
    if tot:
        print(f"  {f:10s}: {cor:4d}/{tot:4d}  ({cor/tot*100:5.1f}%)")

print("\nConfidence stats:")
print(f"  Crop  — mean conf when correct: {np.mean(conf_correct_crop)*100:.1f}%, "
      f"when wrong: {np.mean(conf_wrong_crop)*100:.1f}%")
print(f"  Fresh — mean conf when correct: {np.mean(conf_correct_fresh)*100:.1f}%, "
      f"when wrong: {np.mean(conf_wrong_fresh)*100:.1f}%")

lat_arr = np.array(latencies) * 1000  # ms
print("\nInference latency (interpreter.invoke() only, this CPU, desktop proxy):")
print(f"  mean={lat_arr.mean():.1f}ms  p50={np.percentile(lat_arr,50):.1f}ms  "
      f"p95={np.percentile(lat_arr,95):.1f}ms  max={lat_arr.max():.1f}ms")

result = {
    "n_total": n_total,
    "crop_accuracy_pct": round(crop_acc, 2),
    "freshness_accuracy_pct": round(fresh_acc, 2),
    "both_correct_accuracy_pct": round(both_acc, 2),
    "per_class_crop_accuracy": {
        c: (per_class_crop_correct.get(c, 0) / per_class_crop_total[c] * 100
            if per_class_crop_total.get(c) else None)
        for c in CROP_NAMES
    },
    "per_class_fresh_accuracy": {
        f: (per_class_fresh_correct.get(f, 0) / per_class_fresh_total[f] * 100
            if per_class_fresh_total.get(f) else None)
        for f in FRESH_NAMES
    },
    "confidence": {
        "crop_correct_mean": float(np.mean(conf_correct_crop)) if conf_correct_crop else None,
        "crop_wrong_mean": float(np.mean(conf_wrong_crop)) if conf_wrong_crop else None,
        "fresh_correct_mean": float(np.mean(conf_correct_fresh)) if conf_correct_fresh else None,
        "fresh_wrong_mean": float(np.mean(conf_wrong_fresh)) if conf_wrong_fresh else None,
    },
    "latency_ms": {
        "mean": float(lat_arr.mean()),
        "p50": float(np.percentile(lat_arr, 50)),
        "p95": float(np.percentile(lat_arr, 95)),
        "max": float(lat_arr.max()),
    },
    "dataset_crops_not_in_model": sorted(dataset_crops - set(CROP_NAMES)),
    "model_crops_not_in_dataset": sorted(set(CROP_NAMES) - dataset_crops),
    "skipped_folders": skipped_folders,
    "cm_crop": cm_crop.tolist(),
    "cm_fresh": cm_fresh.tolist(),
    "crop_names": CROP_NAMES,
    "fresh_names": FRESH_NAMES,
}
with open(os.path.join(OUT_DIR, "functional_eval_result.json"), "w") as f:
    json.dump(result, f, indent=2)
print(f"\nSaved → {os.path.join(OUT_DIR, 'functional_eval_result.json')}")
