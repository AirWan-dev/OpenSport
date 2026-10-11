import 'dart:ui';

import 'package:flutter/material.dart';

/// Panneau translucide flouté posé par-dessus la carte.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = const EdgeInsets.all(12),
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F17).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Bouton rond translucide.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool active;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Glass(
      radius: 16,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              icon,
              size: 22,
              color: active ? const Color(0xFFFC5200) : Colors.white,
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
