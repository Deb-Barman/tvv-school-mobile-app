import 'package:flutter/material.dart';

import '../../../core/clock.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';

String greeting() {
  final h = schoolNow().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Profile-style header at the top of every dashboard: picture with a ring, greeting, name and a few chips.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, required this.name, this.overline, this.chips = const []});
  final String name;
  final String? overline;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(children: [
        Avatar(name: context.me.fullName, size: 68, ring: true),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(overline ?? greeting(), maxLines: 1, overflow: TextOverflow.ellipsis, style: c.small),
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.display),
            if (chips.isNotEmpty) ...[const SizedBox(height: 6), Wrap(spacing: 6, runSpacing: 6, children: chips)],
          ]),
        ),
      ]),
    );
  }
}

/// A round coloured icon (used as the picture of a feed post).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.tone = 'accent', this.size = 38});
  final IconData icon;
  final String tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final col = AppColors.of(context).tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: col.withValues(alpha: 0.14), shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.52, color: col),
    );
  }
}

/// Small flat tile with a big number.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.tone = 'accent', this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final String tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(icon, tone: tone, size: 34),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.text)),
        Text(label, style: c.small, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

/// A row of two tiles per line (works for any count).
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: tiles[i]),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
        ]),
      ));
    }
    return Column(children: rows);
  }
}

/// Quick action button (kept for screens that still use it).
class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      radius: 14,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c.accent, size: 24),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: c.small.copyWith(color: c.text, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class QuickActionRow extends StatelessWidget {
  const QuickActionRow({super.key, required this.actions});
  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ]);
}
