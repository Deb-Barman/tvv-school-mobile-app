import 'package:flutter/material.dart';

import '../../../data/attendance_stats.dart';
import '../../../data/models/academics.dart';
import '../../../data/models/content.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
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
        final s = AttendanceSummary.of(d.attendance, workingDays: d.session?.workingDays, minPercent: d.session?.minPercent ?? 75);
        final wd = DateTime.now().weekday - 1; // 0 = Monday
        final today = d.timetable.where((e) => e.weekday == wd).toList()..sort((a, b) => a.period.compareTo(b.period));
        final nowT = TimeOfDay.now();
        final nowMin = nowT.hour * 60 + nowT.minute;
        int toMin(String t) {
          final p = t.split(':');
          return (int.tryParse(p[0]) ?? 0) * 60 + (p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
        }

        final todo = d.homework.where((h) => h.phase == 'open' && h.done != true).toList()
          ..sort((a, b) => (a.dueDate ?? DateTime(2100)).compareTo(b.dueDate ?? DateTime(2100)));
        final exams = d.exams.where((e) => e.date != null && !e.date!.isBefore(dayOnly(DateTime.now()))).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));

        return PageList(children: [
          NeuCard(
            depth: 3,
            radius: 26,
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(greeting().toUpperCase(), style: c.eyebrow),
                  const SizedBox(height: 4),
                  Text(me.firstName, style: c.display),
                  const SizedBox(height: 8),
                  if (d.classLabel != null) Pill(d.classLabel!, tone: 'good'),
                  const SizedBox(height: 12),
                  Text('Attendance ${s.countLabel}', style: c.small),
                  if (s.percentOfMarked != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Pill('${pct(s.percentOfMarked)} so far', tone: s.tone)),
                ]),
              ),
              GestureDetector(
                  onTap: () => onOpen('attendance'),
                  child: ProgressRing(percent: s.ringPercent, label: s.ringLabel, sub: 'attendance', tone: s.tone, size: 104)),
            ]),
          ),
          SectionTitle("Today's classes", trailing: TextButton(onPressed: () => onOpen('timetable'), child: const Text('Timetable'))),
          if (wd > 5)
            const NeuCard(child: Text('It\u2019s Sunday \u2014 no classes today. Enjoy your day!'))
          else if (today.isEmpty)
            const NeuCard(child: Text('No periods are scheduled for today.'))
          else
            for (final e in today)
              Builder(builder: (_) {
                final live = !e.isBreak && nowMin >= toMin(e.startTime) && nowMin < toMin(e.endTime);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: NeuCard(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    radius: 18,
                    color: live ? c.accentSoft : null,
                    child: Row(children: [
                      SizedBox(
                          width: 70,
                          child: Text(fmtTime(e.startTime), style: c.small.copyWith(color: c.text, fontWeight: FontWeight.w600))),
                      Expanded(child: Text(e.title, style: e.isBreak ? c.small.copyWith(fontSize: 14) : c.bodyStrong)),
                      if (e.room.isNotEmpty) Text('Rm ${e.room}', style: c.small),
                      if (live) ...[const SizedBox(width: 8), const Pill('Now', tone: 'good')],
                    ]),
                  ),
                );
              }),
          SectionTitle('Homework to do', trailing: TextButton(onPressed: () => onOpen('homework'), child: const Text('All homework'))),
          if (todo.isEmpty)
            const NeuCard(
                child: Row(children: [
              Icon(Icons.task_alt_rounded),
              SizedBox(width: 12),
              Expanded(child: Text('Nothing pending \u2014 you\u2019re all caught up.'))
            ]))
          else
            for (final h in todo.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  onTap: () => onOpen('homework'),
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  child: Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [Text(h.title, style: c.bodyStrong), Text(h.subjectName, style: c.small)])),
                    Pill(relativeDay(h.dueDate),
                        tone: (h.dueDate != null && dayOnly(h.dueDate!).difference(dayOnly(DateTime.now())).inDays <= 1) ? 'bad' : 'warn'),
                  ]),
                ),
              ),
          if (exams.isNotEmpty) ...[
            SectionTitle('Upcoming exams', trailing: TextButton(onPressed: () => onOpen('exams'), child: const Text('Schedule'))),
            for (final e in exams.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  onTap: () => onOpen('exams'),
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.subjectName, style: c.bodyStrong),
                      Text('${e.name} \u00b7 ${fmtDate(e.date)}', style: c.small)
                    ])),
                    Pill(relativeDay(e.date), tone: 'good'),
                  ]),
                ),
              ),
          ],
          SectionTitle('Latest notices', trailing: TextButton(onPressed: () => onOpen('notices'), child: const Text('All notices'))),
          if (d.notices.isEmpty) const NeuCard(child: Text('No notices right now.')),
          for (final n in d.notices.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuCard(
                onTap: () => onOpen('notices'),
                padding: const EdgeInsets.all(14),
                radius: 18,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: c.bodyStrong),
                  const SizedBox(height: 2),
                  Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: c.small.copyWith(fontSize: 13.5)),
                  const SizedBox(height: 6),
                  Text(fmtDate(n.createdAt), style: c.small),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}
