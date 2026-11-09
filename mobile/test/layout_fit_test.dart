import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/core/clock.dart';
import 'package:tvv_mobile/data/next_period.dart';
import 'package:tvv_mobile/ui/screens/home/dashboard_parts.dart';
import 'package:tvv_mobile/data/results_stats.dart' show performanceTone;
import 'package:tvv_mobile/ui/theme/app_theme.dart';
import 'package:tvv_mobile/ui/widgets/common.dart';
import 'package:tvv_mobile/ui/widgets/hero.dart';
import 'package:tvv_mobile/ui/widgets/insta.dart';
import 'package:tvv_mobile/ui/widgets/neu.dart';
import 'package:tvv_mobile/ui/widgets/states.dart';

/// Pumps [body] on a small 320 dp wide phone with the system text set very large (the app limits it to +15%), in the
/// same wrapper the real app uses, and fails the test if anything overflows the screen.
Future<void> pumpOnSmallPhone(WidgetTester tester, Widget body, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(320 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = 1.6;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(brightness),
    builder: (context, child) =>
        MediaQuery.withClampedTextScaling(minScaleFactor: 0.9, maxScaleFactor: 1.15, child: ClipRect(child: child ?? const SizedBox.shrink())),
    home: Scaffold(body: body),
  ));
  await tester.pump(const Duration(milliseconds: 600));
  expect(tester.takeException(), isNull);
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shared building blocks fit a small phone with big text (${brightness.name})', (tester) async {
      debugSchoolClock = () => DateTime(2026, 11, 9, 10, 20);
      addTearDown(() => debugSchoolClock = null);
      await pumpOnSmallPhone(
        tester,
        ListView(padding: const EdgeInsets.all(12), children: [
          StoryRow(bubbles: [
            for (final label in const ['Timetable', 'Homework', 'Attendance', 'Results', 'Exams', 'Notices'])
              StoryBubble(icon: Icons.star_outline_rounded, label: label, badge: label == 'Homework' ? 120 : 0, onTap: () {}),
          ]),
          const Wrap(spacing: 6, runSpacing: 6, children: [Pill('Class XI Science and some more words'), Pill('3 open homework', tone: 'warn')]),
          const PostCard(
            title: 'A very long author name that has to be cut with dots somewhere',
            subtitle: '24 Oct 2026 \u00b7 All classes of the whole school',
            child: Text('Dear all students and teachers, this is a notice that is long enough to need several lines of text on a small phone.'),
          ),
          TileGrid(tiles: [
            const StatTile(icon: Icons.school_outlined, label: 'Students', value: '1,248'),
            const StatTile(icon: Icons.badge_outlined, label: 'Teachers present today', value: '34'),
          ]),
          SegmentStrip<int>(items: const [0, 1, 2, 3, 4, 5], selected: 2, labelOf: (d) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][d], onChanged: (_) {}),
          const NeuButton(label: 'Save attendance for the whole class', onPressed: null),
          const SizedBox(height: 12),
          HeroCard(
            child: Row(children: [
              const HeroRing(percent: 72, label: '72%', sub: 'of session'),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('138 of 200', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  const Text('days present of 200 working days'),
                  const SizedBox(height: 8),
                  const Wrap(spacing: 6, runSpacing: 6, children: [HeroChip('Needs attention'), HeroChip('72% so far')]),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const InsightCard(
              icon: Icons.lightbulb_outline_rounded,
              title: 'You can miss up to 12 more days',
              text: 'and still finish the session at 75% or above (62 working days left).'),
          const SizedBox(height: 12),
          const NeuCard(
            padding: EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: MiniBars(
              values: [50, null, 80, 95, 30, 100],
              labels: ['Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'],
              toneOf: performanceTone,
            ),
          ),
          const SizedBox(height: 12),
          const NextClassCard(slots: [PeriodSlot(startMin: 600, endMin: 645, title: 'Mathematics', subtitle: 'Class XI Science', room: '12')]),
        ]),
        brightness: brightness,
      );
    });
  }

  testWidgets('every loading placeholder fits a small phone', (tester) async {
    const placeholders = <Widget>[
      PostFeedSkeleton(),
      PostFeedSkeleton(image: true),
      DashboardSkeleton(),
      MosaicSkeleton(),
      AchievementSkeleton(),
      ProfileSkeleton(),
      TimetableSkeleton(),
      ListSkeleton(count: 5, header: true),
    ];
    for (final p in placeholders) {
      await pumpOnSmallPhone(tester, p);
    }
  });
}
