import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The colourful ring around an avatar / shortcut (the "story" look). [child] is clipped to a circle.
class GradientRing extends StatelessWidget {
  const GradientRing({super.key, required this.size, required this.child, this.thickness = 2.5, this.gap = 2.5, this.active = true});

  final double size;
  final Widget child;
  final double thickness;
  final double gap;
  final bool active;

  /// Size of the picture inside the ring.
  double get inner => size - 2 * (thickness + gap);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(thickness),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: active ? AppColors.storyGradient : null,
        border: active ? null : Border.all(color: c.edge, width: thickness / 1.6),
      ),
      child: Container(
        padding: EdgeInsets.all(gap),
        decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg),
        child: ClipOval(child: SizedBox.expand(child: child)),
      ),
    );
  }
}

/// The school seal inside a ring.
class SchoolLogo extends StatelessWidget {
  const SchoolLogo({super.key, this.size = 40, this.ring = true});
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final logo = Container(color: Colors.white, padding: EdgeInsets.all(size * 0.06), child: Image.asset('assets/images/school_logo.png', fit: BoxFit.contain));
    if (!ring) return ClipOval(child: SizedBox(width: size, height: size, child: logo));
    return GradientRing(size: size, thickness: size > 60 ? 3 : 2, gap: size > 60 ? 3 : 2, child: logo);
  }
}

/// A round shortcut with a gradient ring and a label underneath (like a story).
class StoryBubble extends StatelessWidget {
  const StoryBubble({super.key, required this.icon, required this.label, required this.onTap, this.badge = 0});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: badge > 0 ? '$label, $badge' : label,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(clipBehavior: Clip.none, children: [
              GradientRing(
                size: 66,
                child: ColoredBox(color: c.inset, child: Icon(icon, color: c.text, size: 28)),
              ),
              if (badge > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.bad, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.bg, width: 2)),
                    child: Text(badge > 99 ? '99+' : '$badge', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: c.text)),
          ]),
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [StoryBubble]s.
class StoryRow extends StatelessWidget {
  const StoryRow({super.key, required this.bubbles});
  final List<StoryBubble> bubbles;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: bubbles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, i) => bubbles[i],
      ),
    );
  }
}

/// A feed "post": header (picture + name + subtitle + optional menu), then the content.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.title, this.subtitle = '', this.leading, this.trailing, required this.child, this.onTap});
  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final shape = BorderRadius.circular(16);
    return PressScale(
      enabled: onTap != null,
      child: DecoratedBox(
      decoration: BoxDecoration(color: c.surface, borderRadius: shape, border: Border.all(color: c.edge)),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: shape,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 6, 4),
              child: Row(children: [
                leading ?? const SchoolLogo(size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.bodyStrong.copyWith(fontSize: 14)),
                    if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: c.small.copyWith(fontSize: 12)),
                  ]),
                ),
                if (trailing != null) trailing!,
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 14), child: child),
          ]),
        ),
      ),
      ),
    );
  }
}

/// A one-pixel divider in the hairline colour.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(left: indent),
        child: SizedBox(height: 1, child: ColoredBox(color: AppColors.of(context).edge, child: const SizedBox.expand())),
      );
}

/// Presses in slightly while a finger is down (does not take part in the tap itself).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(scale: _down ? 0.978 : 1, duration: motionMs(context, 110), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Fades and slides a list item in the first time it appears (the first few items are staggered).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    final i = index > 7 ? 7 : index;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + i * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c)),
    );
  }
}

/// True when the person asked the phone to reduce motion (Settings -> Accessibility -> Remove animations).
bool reduceMotion(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// [ms] milliseconds, or no animation at all when reduced motion is on.
Duration motionMs(BuildContext context, int ms) => reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);
