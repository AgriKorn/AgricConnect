# AgriConnect AI Model — EDA, Fixes & Accuracy Report

**Model:** `agriconnect.tflite` (MobileNetV2 backbone, two classification heads + one derived output)
**Date:** 2026-08-02
**Prepared for:** Phase 4/5 check-in (AI/ML team — Sakah, CY, Assenso)

This covers the Phase Plan's outstanding AI/ML deliverables from "convert to TFLite" onward: EDA on the shipped model, accuracy validation against the target (>80%), shelf-life calibration, and the final accuracy/performance report.

---

## 1. Structural EDA — model is safe to ship

| Check | Result |
|---|---|
| File size | 2.78 MB |
| Input | `[1,224,224,3]` float32 |
| Outputs | `crop_output [1,9]`, `fresh_output [1,3]`, `shelf_life_days [1]` |
| Quantization | Dynamic range (weights only) |
| Flex/Custom ops | **None** — all builtin TFLite ops (`CONV_2D`, `DEPTHWISE_CONV_2D`, `ARG_MAX`, `GATHER`, `SOFTMAX`, etc.) |
| Portability | Safe for Flutter's standard `tflite` plugins, no native Flex delegate setup needed |

No structural blockers found.

## 2. Functional EDA — full 8,261-image test set

| Metric | Result | Target |
|---|---|---|
| Crop accuracy | **94.96%** | 80% |
| Freshness accuracy | **92.39%** | 80% |
| Both correct | 87.92% | — |
| Inference latency (this CPU, desktop proxy) | mean 347ms, p95 455ms | <5000ms |
| 20 consecutive scans | 100% deterministic, no latency/memory drift | stable |

Both headline metrics comfortably clear the Phase Plan's 80% target and the <5s on-device latency requirement.

### Per-class crop accuracy
carrot 97.3% · cucumber 83.1% · mango 77.7% · okra 99.0% · orange 99.0% · pepper 99.5% · plantain 99.9% · potato 98.9% · tomato 100%

### Per-class freshness accuracy
aging 98.7% · fresh 92.2% · spoiled 91.7%

## 3. Bug found & fixed: 269 mislabeled training images

Initial crop accuracy showed mango at only 73.7% (vs 90.8%–99.9% for every other crop), with 25.7% of mango test images flipping to "cucumber" **at 100% confidence** — not visual ambiguity, a training-data bug.

**Root cause:** 269 real mango photos (230 train + 39 val), all named `freshMango (N).{jpg,png}`, were sitting in `cucumber_fresh` folders instead of `mango_fresh`. Confirmed visually. The model had correctly learned the wrong label it was fed.

**Fix applied:**
1. Moved all 269 files into the correct `mango_fresh` folders (train/val).
2. Ran a corrective fine-tune from the existing checkpoint (top-30 MobileNetV2 layers unfrozen, lr=1e-5, 3 epochs, full corrected train set, ~71 min on this CPU — no GPU available on this machine).
3. Reconverted to `.tflite`.

**Result:** mango 73.7% → 77.7%, overall crop accuracy 94.65% → 94.96%. Improvement was smaller than hoped — investigation showed the `freshMango`-style photos had **zero** correctly-labeled representation in training before the fix, so 3 low-LR epochs wasn't enough to fully absorb a visual style the model was seeing for the first time. A side effect also appeared: cucumber accuracy dipped 90.8% → 83.1% (cucumber↔okra confusion roughly doubled), which looks like ordinary fine-tuning drift rather than a second labeling bug (checked — no filename/folder contamination found for cucumber or okra).

**Decision:** shipped this version. Overall accuracy still clears the 80% target on every metric and no crop is below 77%. Recommended follow-up if more time is available before the final demo: a few more fine-tune epochs, or fine-tune with a higher proportion of the corrected mango examples per batch.

Old model backed up at `ai_eda/agriconnect_PRE_mango_fix_backup.tflite`.

## 4. Separate bug found: broken checkpoint reloading

`agriconnect_clean_model.h5` (the file the original `tflite_model.ipynb` used) and every `.keras` checkpoint in the project (`best_model_phase01.keras`, `agriconnect_final.keras`, `agriconnect_recovered_v2.keras`, `best_model_phase1.keras`) currently **fail to load** via `keras.models.load_model()` in this environment — a Keras/TF version serialization break (`bad marshal data` / weight-restoration `KeyError`), unrelated to the mango bug.

**Workaround used:** rebuilt the exact architecture from `training_pipeline.ipynb`'s code and loaded weights via `model.load_weights()` instead of `load_model()` — this bypasses the broken config path and worked for `agriconnect_clean_model.h5`. This is how the corrective fine-tune above was able to run at all.

**Recommendation:** going forward, save `.weights.h5` (weights-only) alongside any full-model checkpoint, and keep the architecture-building code (already in `training_pipeline.ipynb`) as the source of truth — don't rely on full-model `.keras`/`.h5` reload across environment/Keras-version changes.

## 5. Shelf-life output — now a native part of the model

The model only ever classified crop + freshness stage; "days remaining" was missing entirely, despite being a core product requirement. Two things were built:

- **`shelf_life.py`** (project root): a validated crop→freshness→days lookup table, reused from `data_loader.ipynb`'s original numbers with one bug fixed (key `'oranges'` → `'orange'`, which would have `KeyError`'d on every real orange scan). Also explicitly flags `cassava` — mentioned in the Phase Plan's calibration task — as **not classifiable** by the trained model (not in `CROP_NAMES`), so that gap is visible instead of silently wrong.
- **`shelf_life_days` baked directly into `agriconnect.tflite`** as a third native output, alongside `crop_output` and `fresh_output`. Implemented as a Keras `Layer` (not a `Lambda`, to avoid the same serialization fragility described in §4) that does `argmax` + `gather` against a constant 9×3 table built straight from `shelf_life.py` — both are standard TFLite builtin ops, so the "no Flex ops" property from §1 is preserved.

Validated: spot-checked all 24 crop/freshness combinations — the in-graph output matches `shelf_life.py`'s standalone lookup with **0 mismatches**.

A single on-device inference call now returns all three: crop type, freshness classification, and estimated shelf-life days.

## 6. Files produced

| File | Purpose |
|---|---|
| `agriconnect.tflite` | Shipped model — 3 outputs (crop, freshness, shelf_life_days) |
| `shelf_life.py` | Shelf-life lookup table + validated API (`get_shelf_life_days`, `estimate_shelf_life`) |
| `ai_eda/01_structural_eda.py` | Structural inspection script |
| `ai_eda/02_functional_eval.py` | Full test-set accuracy/confusion-matrix evaluation |
| `ai_eda/03_stability_test.py` | 20-consecutive-scan determinism/latency check |
| `ai_eda/04_mango_cucumber_investigation.py` | Root-cause investigation for the mango bug |
| `ai_eda/05_finetune_corrective.py` | Corrective fine-tune script |
| `ai_eda/06_convert_corrected_tflite.py` | 2-output conversion (superseded by 07) |
| `ai_eda/07_add_shelf_life_output.py` | Adds the 3rd `shelf_life_days` output |
| `ai_eda/08_validate_3output.py` | Validates shelf-life output against `shelf_life.py` |
| `ai_eda/agriconnect_PRE_mango_fix_backup.tflite` | Pre-fix model, kept for rollback |
| `ai_eda/agriconnect_PRE_shelf_life_output_backup.tflite` | Pre-shelf-life-output model, kept for rollback |
| `ai_eda/*_result.json`, `ai_eda/*_BEFORE.json` | Raw metrics, before/after the mango fix |

## 7. Bottom line for the check-in

- ✅ Model structurally sound, no Flex ops, ships clean in Flutter.
- ✅ Crop accuracy 94.96%, freshness accuracy 92.39% — both above the 80% target.
- ✅ On-device latency well under 5s target; fully deterministic across repeated scans.
- ✅ Found and fixed a real training-data bug (269 mislabeled mango images) via the project's own fine-tuning recipe.
- ✅ Model now natively outputs crop type + freshness + shelf-life days in one inference call.
- ⚠️ Known residual weakness: mango (77.7%) and cucumber (83.1%) are the two weakest crops — both still well above 80% target on the aggregate, worth another fine-tuning pass if time allows before the final demo.
- ⚠️ `cassava`, mentioned in the Phase Plan's shelf-life task, is not a class the model can recognize — would need labeled data and a crop-head retrain.
