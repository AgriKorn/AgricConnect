// Picks the real (native, tflite_flutter-backed) CropScanModel on
// Android/iOS/desktop, or a stub that throws UnsupportedError on web —
// dart:ffi (which tflite_flutter depends on) cannot compile for web at
// all. dart.library.io is present everywhere except web, which is why
// it's the standard conditional-import check for "is this a native target".
export 'crop_scan_model_web.dart' if (dart.library.io) 'crop_scan_model_io.dart';
export 'crop_scan_result.dart';
