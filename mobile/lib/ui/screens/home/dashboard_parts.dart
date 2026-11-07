import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/neu.dart';

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Small raised tile with a big number.
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
    final col = c.tone(tone);
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: col)),
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

/// Quick action chip-button used on dashboards.
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
      radius: 18,
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
