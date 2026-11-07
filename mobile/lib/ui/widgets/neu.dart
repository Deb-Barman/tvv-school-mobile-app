import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Raised (or inset) soft surface - the building block of the whole UI.
class NeuCard extends StatelessWidget {
  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 20,
    this.onTap,
    this.onLongPress,
    this.inset = false,
    this.depth = 2,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool inset;
  final int depth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final shape = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? (inset ? c.inset : c.surface),
          borderRadius: shape,
          border: inset ? Border.all(color: c.edge) : null,
          boxShadow: inset ? null : c.raised(depth),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: shape,
          child: InkWell(
            borderRadius: shape,
            onTap: onTap,
            onLongPress: onLongPress,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Primary / secondary action button.
class NeuButton extends StatelessWidget {
  const NeuButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.busy = false,
      this.secondary = false,
      this.danger = false,
      this.expand = true,
      this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool secondary;
  final bool danger;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final enabled = onPressed != null && !busy;
    final Color fg = secondary ? (danger ? c.bad : c.accent) : (danger ? Colors.white : c.onAccent);
    final Color? bg = secondary ? null : (danger ? c.bad : c.accent);
    final radius = BorderRadius.circular(compact ? 12 : 16);
    return Opacity(
      opacity: enabled || busy ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: bg ?? c.surface,
          borderRadius: radius,
          boxShadow: secondary
              ? c.raised(1)
              : [BoxShadow(color: (bg ?? c.accent).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20, vertical: compact ? 10 : 15),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
                  else if (icon != null)
                    Icon(icon, size: 19, color: fg),
                  if (busy || icon != null) const SizedBox(width: 8),
                  Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: compact ? 13.5 : 15))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button on a raised surface.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.size = 44, this.color});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final btn = DecoratedBox(
      decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: c.raised(1)),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: size, height: size, child: Icon(icon, size: size * 0.46, color: color ?? c.text)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Small coloured status chip.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone = 'accent', this.icon});

  final String label;
  final String tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final col = c.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: col.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: col), const SizedBox(width: 4)],
        Flexible(
            child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: col, fontSize: 11.5, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}
