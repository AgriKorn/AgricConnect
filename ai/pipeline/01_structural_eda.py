"""
Structural EDA on agriconnect.tflite
Checks: file size, I/O tensor specs, op list / mobile portability (flex ops),
quantization scheme, tensor count. Prints a verdict on whether the model is
safe to ship on-device before we move on to functional evaluation.
"""
import json
import os

import tensorflow as tf

MODEL_PATH = os.path.join(os.path.dirname(__file__), "..", "model", "agriconnect.tflite")
MODEL_PATH = os.path.abspath(MODEL_PATH)

print("=" * 70)
print("STRUCTURAL EDA — agriconnect.tflite")
print("=" * 70)

size_bytes = os.path.getsize(MODEL_PATH)
print(f"\nFile size: {size_bytes / (1024*1024):.2f} MB")

interpreter = tf.lite.Interpreter(model_path=MODEL_PATH)
interpreter.allocate_tensors()

input_details = interpreter.get_input_details()
output_details = interpreter.get_output_details()

print(f"\nInputs ({len(input_details)}):")
for d in input_details:
    print(f"  name={d['name']!r} shape={d['shape'].tolist()} dtype={d['dtype'].__name__} "
          f"quantization={d['quantization']}")

print(f"\nOutputs ({len(output_details)}):")
for d in output_details:
    print(f"  name={d['name']!r} shape={d['shape'].tolist()} dtype={d['dtype'].__name__} "
          f"quantization={d['quantization']}")

# Op-level inspection — flags any SELECT_TF_OPS / Flex ops, which are NOT
# guaranteed to run inside the standard TFLite runtime shipped with Flutter's
# tflite plugins (they require the much larger Flex delegate).
try:
    ops = interpreter._get_ops_details()  # noqa: SLF001 (only way to introspect via Python API)
except AttributeError:
    ops = None

print(f"\nTotal tensors: {len(interpreter.get_tensor_details())}")

if ops is not None:
    op_names = [o["op_name"] for o in ops]
    from collections import Counter
    counts = Counter(op_names)
    print(f"Total ops: {len(ops)}")
    print("Op type breakdown:")
    for name, cnt in sorted(counts.items(), key=lambda x: -x[1]):
        print(f"  {name}: {cnt}")

    flex_ops = [n for n in op_names if n.startswith("Flex") or n == "CUSTOM"]
    if flex_ops:
        print(f"\n⚠️  FLEX/CUSTOM ops present ({len(flex_ops)}): {sorted(set(flex_ops))}")
        print("   These require the TF Select delegate and will likely NOT run in a")
        print("   standard Flutter tflite plugin without extra native setup.")
    else:
        print("\n✅ No Flex/Custom ops — model uses only builtin TFLite ops (safe for")
        print("   standard on-device runtimes, including Flutter's tflite plugins).")
else:
    print("Could not introspect per-op details via public API (non-fatal).")

# Signature check
try:
    sigs = interpreter.get_signature_list()
    print(f"\nSignatures: {sigs}")
except Exception as e:
    print(f"\nNo signature info: {e}")

# Cross-check against expected label sets from tflite_model.ipynb
CROP_NAMES = ['carrot', 'cucumber', 'mango', 'okra',
              'orange', 'pepper', 'plantain', 'potato', 'tomato']
FRESH_NAMES = ['aging', 'fresh', 'spoiled']

print("\n--- Label/shape cross-check ---")
crop_out_shape = output_details[0]['shape'].tolist()
fresh_out_shape = output_details[1]['shape'].tolist()
print(f"crop_output shape {crop_out_shape} vs len(CROP_NAMES)={len(CROP_NAMES)}: "
      f"{'OK' if crop_out_shape[-1] == len(CROP_NAMES) else 'MISMATCH'}")
print(f"fresh_output shape {fresh_out_shape} vs len(FRESH_NAMES)={len(FRESH_NAMES)}: "
      f"{'OK' if fresh_out_shape[-1] == len(FRESH_NAMES) else 'MISMATCH'}")

result = {
    "size_mb": round(size_bytes / (1024 * 1024), 3),
    "input_shape": input_details[0]['shape'].tolist(),
    "input_dtype": input_details[0]['dtype'].__name__,
    "n_outputs": len(output_details),
    "output_shapes": [d['shape'].tolist() for d in output_details],
    "n_ops": len(ops) if ops is not None else None,
    "flex_ops": sorted(set(flex_ops)) if ops is not None else None,
}
out_path = os.path.join(os.path.dirname(__file__), "..", "results", "structural_eda_result.json")
with open(out_path, "w") as f:
    json.dump(result, f, indent=2)
print(f"\nSaved → {out_path}")
