import 'package:flutter/material.dart';

import '../../../core/clock.dart';
import '../../../data/next_period.dart';
import '../../../data/attendance_stats.dart';
import '../../../data/models/academics.dart';
import '../../../data/models/content.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../content/notice_detail_screen.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import 'dashboard_parts.dart';

class _StudentHomeData {
  _StudentHomeData(
      {required this.attendance,
      required this.session,
      required this.timetable,
      required this.homework,
      required this.exams,
      required this.notices,
      required this.classLabel});
  final List<AttendanceRecord> attendance;
  final AcademicSession? session;
  final List<TimetableEntry> timetable;
  final List<Homework> homework;
  final List<Exam> exams;
  final List<Notice> notices;
  final String? classLabel;
}

class StudentHomeView extends StatelessWidget {
  const StudentHomeView({super.key, required this.onOpen});

  /// Opens another section by key (a tab or a feature screen).
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_StudentHomeData>(
      skeleton: const DashboardSkeleton(),
      load: () async {
        final (att, sessions, tt, hw, ex, notices, years) = await (
          svc.academics.attendance(),
          svc.academics.sessions(),
          svc.academics.timetable(),
          svc.academics.homework(upcomingOnly: false),
          svc.academics.exams(upcomingOnly: true),
          svc.content.notices(),
          svc.academics.myClassYears(),
        ).wait;
        return _StudentHomeData(
          attendance: att,
          session: sessions.where((s) => s.isCurrent).firstOrNull,
          timetable: tt,
          homework: hw,
          exams: ex,
          notices: notices,
          classLabel: years.where((y) => y.current).firstOrNull?.label,
        );
      },
      builder: (ctx, d, reload) {
        final c = AppColors.of(ctx);
        final now = schoolNow();
        final s = AttendanceSummary.of(d.attendance, workingDays: d.session?.workingDays, minPercent: d.session?.minPercent ?? 75);
        final wd = now.weekday - 1; // 0 = Monday
        final today = d.timetable.where((e) => e.weekday == wd).toList()..sort((a, b) => a.period.compareTo(b.period));
        final nowMin = now.hour * 60 + now.minute;
        int toMin(String t) {
          final p = t.split(':');
          return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
        }

        final todo = d.homework.where((h) => h.phase == 'open' && h.done != true).toList()
          ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
        final exams = d.exams.where((e) => e.date != null && !e.date!.isBefore(dayOnly(now))).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));

        return PageList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: [
          StoryRow(bubbles: [
            StoryBubble(icon: Icons.calendar_view_week_outlined, label: 'Timetable', onTap: () => onOpen('timetable')),
            StoryBubble(icon: Icons.assignment_outlined, label: 'Homework', badge: todo.length, onTap: () => onOpen('homework')),
            StoryBubble(icon: Icons.fact_check_outlined, label: 'Attendance', onTap: () => onOpen('attendance')),
            StoryBubble(icon: Icons.emoji_events_outlined, label: 'Results', onTap: () => onOpen('results')),
            StoryBubble(icon: Icons.quiz_outlined, label: 'Exams', onTap: () => onOpen('exams')),
            StoryBubble(icon: Icons.campaign_outlined, label: 'Notices', onTap: () => onOpen('notices')),
            StoryBubble(icon: Icons.event_outlined, label: 'Events', onTap: () => onOpen('events')),
            StoryBubble(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () => onOpen('gallery')),
          ]),
          GreetingHeader(name: me.firstName, chips: [if (d.classLabel != null) Pill(d.classLabel!, tone: 'good')]),
          if (wd <= 5 && today.any((e) => !e.isBreak))
            NextClassCard(
              onTap: () => onOpen('timetable'),
              slots: [
                for (final e in today)
                  PeriodSlot(startMin: minutesOfDay(e.startTime), endMin: minutesOfDay(e.endTime), title: e.title, room: e.room, isBreak: e.isBreak)
              ],
            ),
          const SizedBox(height: 8),
          PostCard(
            title: 'Attendance',
            subtitle: s.countLabel,
            leading: const IconBadge(Icons.fact_check_rounded, tone: 'good'),
            onTap: () => onOpen('attendance'),
            child: Row(children: [
              ProgressRing(percent: s.ringPercent, label: s.ringLabel, sub: 'attendance', tone: s.tone, size: 96),
              const SizedBox(width: 18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (s.percentOfMarked != null) Pill('${pct(s.percentOfMarked)} so far', tone: s.tone),
                  const SizedBox(height: 8),
                  Text('Tap to see your calendar and recent days.', style: c.small),
                ]),
              ),
            ]),
          ),
          SectionTitle("Today's classes", trailing: TextButton(onPressed: () => onOpen('timetable'), child: const Text('Timetable'))),
          if (wd > 5)
            const NeuCard(inset: true, child: Text('It\u2019s Sunday \u2014 no classes today. Enjoy your day!'))
          else if (today.isEmpty)
            const NeuCard(inset: true, child: Text('No periods are scheduled for today.'))
          else
            for (final e in today)
              Builder(builder: (_) {
                final live = !e.isBreak && nowMin >= toMin(e.startTime) && nowMin < toMin(e.endTime);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NeuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    radius: 14,
                    color: live ? c.accentSoft : null,
                    child: Row(children: [
                      SizedBox(
                          width: 78,
                          child: Text(fmtTime(e.startTime), style: c.small.copyWith(color: c.text, fontWeight: FontWeight.w600))),
                      Expanded(child: Text(e.title, style: e.isBreak ? c.small.copyWith(fontSize: 14) : c.bodyStrong)),
                      if (e.room.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text('Rm ${e.room}', style: c.small)),
                      if (live) ...[const SizedBox(width: 8), const Pill('Now', tone: 'good')],
                    ]),
                  ),
                );
              }),
          SectionTitle('Homework to do', trailing: TextButton(onPressed: () => onOpen('homework'), child: const Text('All homework'))),
          if (todo.isEmpty)
            NeuCard(
                inset: true,
                child: Row(children: [
                  Icon(Icons.task_alt_rounded, color: c.good),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Nothing pending \u2014 you\u2019re all caught up.'))
                ]))
          else
            for (final h in todo.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  onTap: () => onOpen('homework'),
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(h.title, style: c.bodyStrong), Text(h.subjectName, style: c.small)])),
                    const SizedBox(width: 8),
                    Pill(relativeDay(h.dueDate), tone: (h.dueDate != null && dayOnly(h.dueDate!).difference(dayOnly(now)).inDays <= 1) ? 'bad' : 'warn'),
                  ]),
                ),
              ),
          if (exams.isNotEmpty) ...[
            SectionTitle('Upcoming exams', trailing: TextButton(onPressed: () => onOpen('exams'), child: const Text('Schedule'))),
            for (final e in exams.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  onTap: () => onOpen('exams'),
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.subjectName, style: c.bodyStrong),
                      Text('${e.name} \u00b7 ${fmtDate(e.date)}', style: c.small)
                    ])),
                    const SizedBox(width: 8),
                    Pill(relativeDay(e.date), tone: 'good'),
                  ]),
                ),
              ),
          ],
          SectionTitle('Latest notices', trailing: TextButton(onPressed: () => onOpen('notices'), child: const Text('All notices'))),
          if (d.notices.isEmpty) const NeuCard(inset: true, child: Text('No notices right now.')),
          for (final n in d.notices.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PostCard(
                title: n.createdByName.isNotEmpty ? n.createdByName : 'School office',
                subtitle: fmtDate(n.createdAt),
                onTap: () => openNotice(ctx, n),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: c.h2),
                  const SizedBox(height: 4),
                  Text(n.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: c.body),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
