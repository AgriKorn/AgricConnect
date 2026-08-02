"""
Phase 5, Sakah's task: "Confirm on-device inference is stable across 20
consecutive scans." We don't have the real Android device this repo's phase
plan calls for, so this is a desktop CPU proxy: it re-runs inference on the
same fixed image 20 times back-to-back on a fresh interpreter instance each
time (matching how the Flutter app would spin up inference per scan) and
checks for two failure modes a mobile team would actually care about:
  1. Non-determinism — does the model give a different answer on the same
     input across runs? (would look like a flaky demo on stage)
  2. Latency blow-up / memory creep — does invoke() get slower or does the
     process RSS grow across repeated runs? (would look like the app
     freezing after a few scans)
"""
import json
import os
import time
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

try:
    import psutil
except ImportError:
    psutil = None

MODEL_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "model", "agriconnect.tflite"))
TEST_DIR = Path(os.environ.get("AGRICONNECT_TEST_DIR", "../AgriConnect_Final_dataset/test"))  # dataset not committed; set env var or edit path
IMG_SIZE = (224, 224)
N_RUNS = 20

CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']


def load_and_preprocess(image_path):
    img = Image.open(image_path).convert("RGB")
    img = np.array(img).astype(np.float32)
    t = tf.convert_to_tensor(img)
    t = tf.image.resize_with_pad(t, IMG_SIZE[0], IMG_SIZE[1])
    t = tf.expand_dims(t, axis=0)
    return t.numpy()


# Pick one real, fixed test image (deterministic choice, not random)
sample_folder = sorted(TEST_DIR.glob("tomato_fresh"))[0]
sample_image = sorted([p for p in sample_folder.iterdir()
                        if p.suffix.lower() in {".jpg", ".jpeg", ".png"}])[0]
print(f"Using fixed sample image: {sample_image}")

x = load_and_preprocess(sample_image)

process = psutil.Process(os.getpid()) if psutil is not None else None

results = []
for i in range(N_RUNS):
    interpreter = tf.lite.Interpreter(model_path=MODEL_PATH, num_threads=4)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()
    out = interpreter.get_output_details()

    t0 = time.perf_counter()
    interpreter.set_tensor(inp[0]['index'], x)
    interpreter.invoke()
    crop_out = interpreter.get_tensor(out[0]['index'])[0]
    fresh_out = interpreter.get_tensor(out[1]['index'])[0]
    latency_ms = (time.perf_counter() - t0) * 1000

    rss_mb = process.memory_info().rss / (1024 * 1024) if process else None

    results.append({
        "run": i + 1,
        "crop_pred": CROP_NAMES[int(np.argmax(crop_out))],
        "crop_conf": float(np.max(crop_out)),
        "fresh_pred": FRESH_NAMES[int(np.argmax(fresh_out))],
        "fresh_conf": float(np.max(fresh_out)),
        "latency_ms": latency_ms,
        "rss_mb": rss_mb,
    })
    del interpreter

crop_preds = {r["crop_pred"] for r in results}
fresh_preds = {r["fresh_pred"] for r in results}
crop_confs = [r["crop_conf"] for r in results]
fresh_confs = [r["fresh_conf"] for r in results]
latencies = [r["latency_ms"] for r in results]
rss = [r["rss_mb"] for r in results if r["rss_mb"] is not None]

print("\n" + "=" * 70)
print(f"STABILITY TEST — {N_RUNS} consecutive scans on the same image")
print("=" * 70)
print(f"Distinct crop predictions across runs:      {crop_preds} "
      f"({'DETERMINISTIC' if len(crop_preds) == 1 else 'NON-DETERMINISTIC ⚠️'})")
print(f"Distinct freshness predictions across runs:  {fresh_preds} "
      f"({'DETERMINISTIC' if len(fresh_preds) == 1 else 'NON-DETERMINISTIC ⚠️'})")
print(f"Crop confidence spread:      min={min(crop_confs)*100:.2f}%  max={max(crop_confs)*100:.2f}%  "
      f"(delta={((max(crop_confs)-min(crop_confs))*100):.4f} pp)")
print(f"Freshness confidence spread: min={min(fresh_confs)*100:.2f}%  max={max(fresh_confs)*100:.2f}%  "
      f"(delta={((max(fresh_confs)-min(fresh_confs))*100):.4f} pp)")
print(f"\nLatency across {N_RUNS} runs (ms): "
      f"mean={np.mean(latencies):.1f}  min={min(latencies):.1f}  max={max(latencies):.1f}  "
      f"first_run={latencies[0]:.1f}  last_run={latencies[-1]:.1f}")
if rss:
    print(f"RSS memory across runs (MB): first={rss[0]:.1f}  last={rss[-1]:.1f}  "
          f"growth={rss[-1]-rss[0]:.1f}  ({'STABLE' if rss[-1]-rss[0] < 50 else 'GROWING ⚠️'})")

under_5s = all(l < 5000 for l in latencies)
print(f"\nAll {N_RUNS} runs under 5000ms (Phase-plan target): {'YES ✅' if under_5s else 'NO ⚠️'}")

out_path = os.path.join(os.path.dirname(__file__), "..", "results", "stability_test_result.json")
with open(out_path, "w") as f:
    json.dump({
        "n_runs": N_RUNS,
        "sample_image": str(sample_image),
        "deterministic_crop": len(crop_preds) == 1,
        "deterministic_fresh": len(fresh_preds) == 1,
        "latency_ms_mean": float(np.mean(latencies)),
        "latency_ms_max": float(max(latencies)),
        "all_under_5s": under_5s,
        "runs": results,
    }, f, indent=2)
print(f"\nSaved → {out_path}")
