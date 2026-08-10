// lib/utils/color_ext.dart
import 'package:flutter/material.dart';

extension ColorExt on Color {
  /// Helper that mirrors withOpacity but named like your UI used: withValues(alpha: 0.5)
  Color withValues({double alpha = 1.0}) => withOpacity(alpha.clamp(0.0, 1.0));
}
