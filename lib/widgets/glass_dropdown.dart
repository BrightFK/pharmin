// lib/widgets/glass_dropdown.dart - Create a new file for reusable glass dropdown

import 'package:flutter/material.dart';

class GlassPopupMenu<T> extends StatelessWidget {
  final Widget icon;
  final List<PopupMenuItem<T>> items;
  final ValueChanged<T>? onSelected;

  const GlassPopupMenu({
    super.key,
    required this.icon,
    required this.items,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      icon: icon,
      offset: const Offset(0, 10),
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: onSelected,
      // Custom painter for glass dropdown background
      itemBuilder: (context) => items,
    );
  }
}

// Glass menu item with full glass effect
class GlassMenuItem<T> extends StatelessWidget {
  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback? onTap;

  const GlassMenuItem({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuItem<T>(
      value: value,
      padding: EdgeInsets.zero,
      child: // Less transparent - More visible glass effect
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.25), // Increased from 0.12
              Colors.white.withValues(alpha: 0.10), // Increased from 0.04
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(
              alpha: 0.3,
            ), // Increased border opacity
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.2,
              ), // Added shadow for depth
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? Colors.white70, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom glass dropdown theme wrapper
class GlassDropdownTheme extends StatelessWidget {
  final Widget child;

  const GlassDropdownTheme({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      child: child,
    );
  }
}
