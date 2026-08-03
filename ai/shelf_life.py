"""
Shelf-life day estimation — AI/ML team deliverable (Phase 4, CY: "Calibrate
shelf-life day estimates per crop type").

The MobileNetV2 model (agriconnect.tflite) only classifies WHICH crop and
WHICH freshness stage (aging / fresh / spoiled) an image shows — it has no
regression head for "days remaining". Shelf life is therefore a calibrated
lookup, not a model output: crop + freshness stage -> estimated days left.

Source of truth for the day values: SHELF_LIFE_DAYS table originally defined
in data_loader.ipynb (attributed there to a since-lost `model.py`). That
table is reused here with one correctness fix — see CHANGES below — and is
now validated against the model's actual label vocabulary at import time so
drift between the two can never fail silently again.

CHANGES vs the data_loader.ipynb version:
  - Fixed key 'oranges' -> 'orange'. The trained model's CROP_NAMES (see
    agriconnect.tflite output ordering) and the dataset's folder names both
    use the singular 'orange'. The plural key meant any real lookup for
    orange shelf life would KeyError (or silently miss in a .get() call).
    Caught by the assertion at the bottom of this file, which now runs on
    import so this class of bug can't reappear silently.
"""
from __future__ import annotations

# Must exactly match agriconnect.tflite's output label ordering
# (see ai_eda/01_structural_eda.py / tflite_model.ipynb).
CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']

# Crops the dataset only has 'fresh' and 'spoiled' folders for (no 'aging'
# examples were collected). The model can still technically emit "aging" as
# its argmax for these crops (it's one of 3 output units for every crop),
# so we keep a day estimate for it rather than crashing — it's just an
# extrapolation, not something calibrated against real labeled photos.
TWO_STAGE_CROPS = {'cucumber', 'okra', 'orange'}

# Crops mentioned in the Phase Plan's shelf-life calibration task that the
# trained model CANNOT recognize (not in CROP_NAMES / not in the dataset).
# Retraining the crop head to add these is out of scope for this pass —
# flagged here so the gap is explicit instead of silently returning None.
UNSUPPORTED_CROPS = {'cassava'}

SHELF_LIFE_DAYS: dict[str, dict[str, int]] = {
    'tomato':   {'fresh': 7,  'aging': 3, 'spoiled': 0},
    'plantain': {'fresh': 6,  'aging': 3, 'spoiled': 0},
    'pepper':   {'fresh': 8,  'aging': 3, 'spoiled': 0},
    'carrot':   {'fresh': 14, 'aging': 5, 'spoiled': 0},
    'mango':    {'fresh': 6,  'aging': 2, 'spoiled': 0},
    'potato':   {'fresh': 21, 'aging': 7, 'spoiled': 0},
    'cucumber': {'fresh': 7,  'aging': 3, 'spoiled': 0},
    'okra':     {'fresh': 4,  'aging': 2, 'spoiled': 0},
    'orange':   {'fresh': 14, 'aging': 5, 'spoiled': 0},
}


class UnknownCropError(ValueError):
    pass


class UnknownFreshnessError(ValueError):
    pass


def get_shelf_life_days(crop: str, freshness: str) -> int:
    """Return estimated days of shelf life remaining for a crop/freshness pair."""
    crop = crop.strip().lower()
    freshness = freshness.strip().lower()

    if crop in UNSUPPORTED_CROPS:
        raise UnknownCropError(
            f"'{crop}' is not classifiable by the current model (CROP_NAMES={CROP_NAMES}); "
            f"it would need labeled training images and a crop-head retrain before shelf-life "
            f"calibration is meaningful for it."
        )
    if crop not in SHELF_LIFE_DAYS:
        raise UnknownCropError(f"No shelf-life calibration for crop '{crop}'. "
                                f"Known crops: {sorted(SHELF_LIFE_DAYS)}")
    if freshness not in FRESH_NAMES:
        raise UnknownFreshnessError(f"'{freshness}' is not a valid freshness stage. "
                                     f"Expected one of {FRESH_NAMES}")

    return SHELF_LIFE_DAYS[crop][freshness]


def estimate_shelf_life(crop: str, freshness: str, confidence: float | None = None) -> dict:
    """
    Full estimate used by the app layer: days remaining + a human-readable
    caveat when the estimate rests on extrapolated (not photo-calibrated)
    data, or when model confidence is low enough that the day count
    shouldn't be trusted at face value.
    """
    days = get_shelf_life_days(crop, freshness)
    caveats = []

    if crop.strip().lower() in TWO_STAGE_CROPS and freshness.strip().lower() == 'aging':
        caveats.append(
            f"'{crop}' has no labeled 'aging' training photos — this day estimate is "
            f"extrapolated, not validated against real images of that stage."
        )
    if confidence is not None and confidence < 0.60:
        caveats.append(
            f"Model confidence was only {confidence*100:.0f}% — treat the day estimate as "
            f"low-confidence and prompt the user to confirm visually."
        )

    return {
        "crop": crop.strip().lower(),
        "freshness_stage": freshness.strip().lower(),
        "days_remaining": days,
        "caveats": caveats,
    }


# ---------------------------------------------------------------------------
# Self-check on import: every crop the model can output MUST resolve to a
# complete set of freshness->days entries. This is what would have caught
# the 'oranges'/'orange' key bug immediately instead of it lying dormant
# until a real orange scan hit it in production.
# ---------------------------------------------------------------------------
_missing = [c for c in CROP_NAMES if c not in SHELF_LIFE_DAYS]
assert not _missing, f"SHELF_LIFE_DAYS is missing entries for model crops: {_missing}"
for _c, _stages in SHELF_LIFE_DAYS.items():
    _missing_stages = [s for s in FRESH_NAMES if s not in _stages]
    assert not _missing_stages, f"SHELF_LIFE_DAYS['{_c}'] missing stages: {_missing_stages}"


if __name__ == "__main__":
    print("Shelf-life table self-check passed.\n")
    print(f"{'crop':10s} {'fresh':>6s} {'aging':>6s} {'spoiled':>8s}")
    for c in CROP_NAMES:
        row = SHELF_LIFE_DAYS[c]
        flag = " (extrapolated aging)" if c in TWO_STAGE_CROPS else ""
        print(f"{c:10s} {row['fresh']:6d} {row['aging']:6d} {row['spoiled']:8d}{flag}")

    print(f"\nRequested-but-unsupported crops (Phase Plan mentions, model can't classify): "
          f"{sorted(UNSUPPORTED_CROPS)}")

    try:
        get_shelf_life_days("cassava", "fresh")
    except UnknownCropError as e:
        print(f"\ncassava lookup correctly raises: {e}")
