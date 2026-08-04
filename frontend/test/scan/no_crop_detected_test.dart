import 'package:flutter_test/flutter_test.dart';

import 'package:agriconnect/features/scan/data/crop_scan_presenter.dart';

void main() {
  test('NoCropDetectedException has a farmer-facing message, not a raw exception string', () {
    const exception = NoCropDetectedException();
    expect(exception.toString(), contains('No crop detected'));
  });
}
