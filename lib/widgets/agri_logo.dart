import 'package:flutter/material.dart';

/// Icon-only brand mark, cropped from the official AgriConnect logo.
class AgriMark extends StatelessWidget {
  const AgriMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/agri_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

/// Full lockup: mark + "AgriConnect" wordmark, as a single official asset.
class AgriLogo extends StatelessWidget {
  const AgriLogo({super.key, this.width = 160});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/agri_logo.png',
      width: width,
      fit: BoxFit.contain,
    );
  }
}
