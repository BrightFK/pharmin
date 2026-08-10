// lib/widgets/glass_card.dart
import 'dart:ui';

import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double blur;
  final Color overlayColor;
  final BorderRadius borderRadius;
  final EdgeInsets margin;
  final bool showBorder;
  final bool showShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.blur = 8.0,
    this.margin = const EdgeInsets.only(bottom: 0),
    this.overlayColor = const Color.fromRGBO(255, 255, 255, 0.08),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.showBorder = true,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: overlayColor,
              borderRadius: borderRadius,
              border: showBorder
                  ? Border.all(color: Colors.white.withValues(alpha: 0.06))
                  : null,
              boxShadow: showShadow
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
