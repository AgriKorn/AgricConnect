# AgriConnect AI/ML

On-device crop freshness model: MobileNetV2 backbone, two classification heads (crop type, freshness stage), plus a derived shelf-life output. Everything here is what the Flutter app needs to integrate the on-device scan feature, plus the full reproducible pipeline behind it.

See **[MODEL_REPORT.md](MODEL_REPORT.md)** for the full EDA, accuracy numbers, bugs found/fixed, and known limitations — read that first.

## What's here

```
ai/
├── model/
│   └── agriconnect.tflite        # ships in the Flutter app — see "Using the model" below
├── shelf_life.py                 # shelf-life lookup table (crop x freshness -> days) + validated API
├── weights/
│   └── agriconnect_corrected.weights.h5   # loadable Keras weights checkpoint, for further fine-tuning
├── notebooks/                    # original training/conversion notebooks
│   ├── training_pipeline.ipynb   # MobileNetV2 training (phase 1: frozen backbone, phase 2: fine-tune)
│   ├── data_loader.ipynb         # dataset loading/preprocessing, original shelf-life table
│   └── tflite_model.ipynb        # first .h5 -> .tflite conversion
├── pipeline/                     # reproducible scripts (numbered = run order for a from-scratch redo)
│   ├── 01_structural_eda.py      # inspects agriconnect.tflite: I/O specs, ops, portability
│   ├── 02_functional_eval.py     # full test-set accuracy + confusion matrix
│   ├── 03_stability_test.py      # 20-consecutive-scan determinism/latency check
│   ├── 04_mango_cucumber_investigation.py  # root-cause tool for the mango/cucumber mislabeling bug
│   ├── 05_finetune_corrective.py # fine-tune from weights/agriconnect_corrected.weights.h5
│   ├── 06_convert_corrected_tflite.py      # SUPERSEDED by 07 — kept for history only
│   ├── 07_add_shelf_life_output.py         # rebuilds model/agriconnect.tflite (3 outputs) from any weights checkpoint
│   └── 08_validate_3output.py    # spot-checks shelf_life_days against shelf_life.py
└── results/                      # JSON metrics from each pipeline stage (before/after the mango fix)
```

## Using the model (Flutter integration)

`model/agriconnect.tflite` — single inference call, three native outputs:

| Output | Shape | Meaning |
|---|---|---|
| `crop_output` | `[1, 9]` | Softmax over 9 crops: `carrot, cucumber, mango, okra, orange, pepper, plantain, potato, tomato` |
| `fresh_output` | `[1, 3]` | Softmax over 3 freshness stages: `aging, fresh, spoiled` |
| `shelf_life_days` | `[1]` | Estimated days remaining, derived in-graph from the predicted crop+freshness (no separate lookup call needed) |

Input: `[1, 224, 224, 3]` float32, RGB, **resize-with-padding** to 224×224 (not stretched — see `load_and_preprocess()` in any `pipeline/*.py` script for the exact preprocessing, it must match at inference time). No Flex/Custom ops — works with the standard `tflite_flutter` plugin, no extra native setup.

`shelf_life.py`'s table is baked directly into the model graph (`ArgMax` + `Gather` against a constant table), so `shelf_life_days` is always consistent with that file — you don't need to port the lookup table into Dart separately.

**Known gap:** `cassava` is not a recognized crop (not in `CROP_NAMES` above) — the model was never trained on it. A scan of cassava will be misclassified as one of the 9 known crops. Would need labeled cassava photos and a crop-head retrain to add.

## Reproducing / extending the pipeline

Requires: `tensorflow`, `keras`, `numpy`, `pillow` (install into whatever Python environment you use for ML work here — not part of the Flutter/Node toolchains).

The labeled dataset itself (~28k train / ~5k val / ~8k test images) is **not committed** to this repo (too large, not app source). Scripts that need it read the path from the `AGRICONNECT_TEST_DIR` / `AGRICONNECT_DATA_DIR` environment variables, defaulting to `../AgriConnect_Final_dataset` relative to `ai/` — set those or edit the constant at the top of the script.

Typical flows:
- **Just inspect/validate the current model**: run `pipeline/01_structural_eda.py`, then `pipeline/02_functional_eval.py` (needs the dataset).
- **Push accuracy further** (e.g. the residual mango/cucumber weakness — see MODEL_REPORT.md §3): run `pipeline/05_finetune_corrective.py` (continues from the checked-in weights), then `pipeline/07_add_shelf_life_output.py` to reconvert `model/agriconnect.tflite`, then re-run `01`/`02`/`08` to confirm no regressions before committing the new model.

## A note on Keras checkpoint fragility

Every full-model `.keras`/`.h5` checkpoint produced earlier in this project fails to reload via `keras.models.load_model()` in a stock TF 2.16/Keras 3 environment (serialization break, unrelated to anything in this folder — see MODEL_REPORT.md §4). That's why only a **weights-only** checkpoint (`weights/agriconnect_corrected.weights.h5`) is committed here, loaded via `model.load_weights()` against a freshly-built architecture (the `build_agriconnect_model()`-equivalent code duplicated at the top of each `pipeline/*.py` script) rather than a full-model reload. Keep doing this for any future checkpoint you add.
