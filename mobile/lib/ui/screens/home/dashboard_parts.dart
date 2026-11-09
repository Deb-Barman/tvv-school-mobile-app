import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/clock.dart';
import '../../../data/next_period.dart';
import '../../theme/tokens.dart';
import '../../widgets/hero.dart';
import '../../widgets/me_avatar.dart';
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
        const MeAvatar(size: 68, ring: true),
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

/// "Next class in 25 min" / "In progress \u00b7 12 min left": updates itself every 30 seconds.
class NextClassCard extends StatefulWidget {
  const NextClassCard({super.key, required this.slots, this.onTap});
  final List<PeriodSlot> slots;
  final VoidCallback? onTap;

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = schoolNow();
    final info = nextPeriod(widget.slots, now.hour * 60 + now.minute);
    if (info == null) return const SizedBox.shrink();
    final slot = info.slot;
    final sub = [if (slot.subtitle.isNotEmpty) slot.subtitle, if (slot.room.isNotEmpty) 'Room ${slot.room}'].join(' \u00b7 ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: widget.onTap,
        child: HeroCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(color: Color(0x29FFFFFF), shape: BoxShape.circle),
              child: Icon(info.live ? Icons.play_circle_outline_rounded : Icons.schedule_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.live ? 'IN PROGRESS' : 'NEXT CLASS', style: const TextStyle(fontSize: 11, letterSpacing: 1, color: Color(0xCCFFFFFF), fontWeight: FontWeight.w700)),
                Text(slot.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: Color(0xCCFFFFFF))),
              ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(minutesLabel(info.minutes), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(info.live ? 'left' : 'to go', style: const TextStyle(fontSize: 12, color: Color(0xCCFFFFFF))),
            ]),
          ]),
        ),
      ),
    );
  }
}
