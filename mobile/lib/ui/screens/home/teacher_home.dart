import 'package:flutter/material.dart';

import '../../../core/clock.dart';
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

class _TeacherHomeData {
  _TeacherHomeData(this.mine, this.classes, this.homework, this.exams, this.notices);
  final List<TimetableEntry> mine;
  final List<SchoolClass> classes;
  final List<Homework> homework;
  final List<Exam> exams;
  final List<Notice> notices;
}

class TeacherHomeView extends StatelessWidget {
  const TeacherHomeView({super.key, required this.onOpen});
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_TeacherHomeData>(
      skeleton: const DashboardSkeleton(),
      load: () async {
        final (mine, classes, hw, ex, notices) = await (
          svc.academics.timetable(mineOnly: true),
          svc.academics.classes(),
          svc.academics.homework(),
          svc.academics.exams(upcomingOnly: true),
          svc.content.notices(),
        ).wait;
        return _TeacherHomeData(mine, classes, hw, ex, notices);
      },
      builder: (ctx, d, reload) {
        final c = AppColors.of(ctx);
        final now = schoolNow();
        final wd = now.weekday - 1;
        final today = d.mine.where((e) => e.weekday == wd).toList()..sort((a, b) => a.period.compareTo(b.period));
        final labels = {for (final k in d.classes) k.id: k.label};
        final open = d.homework.where((h) => h.phase == 'open').length;
        final exams = d.exams.where((e) => e.date != null && !e.date!.isBefore(dayOnly(now))).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
        return PageList(padding: const EdgeInsets.fromLTRB(12, 0, 12, 40), children: [
          StoryRow(bubbles: [
            StoryBubble(icon: Icons.fact_check_outlined, label: 'Attendance', onTap: () => onOpen('take_attendance')),
            StoryBubble(icon: Icons.assignment_outlined, label: 'Homework', badge: open, onTap: () => onOpen('homework')),
            StoryBubble(icon: Icons.edit_note_rounded, label: 'Marks', onTap: () => onOpen('results_entry')),
            StoryBubble(icon: Icons.calendar_view_week_outlined, label: 'Timetable', onTap: () => onOpen('timetable')),
            StoryBubble(icon: Icons.quiz_outlined, label: 'Exams', onTap: () => onOpen('exams')),
            StoryBubble(icon: Icons.groups_outlined, label: 'Students', onTap: () => onOpen('students')),
            StoryBubble(icon: Icons.campaign_outlined, label: 'Notices', onTap: () => onOpen('notices')),
            StoryBubble(icon: Icons.event_available_outlined, label: 'My days', onTap: () => onOpen('my_attendance')),
          ]),
          GreetingHeader(name: me.fullName, chips: [
            Pill(wd > 5 ? 'No classes today' : plural(today.where((e) => !e.isBreak).length, 'period') + ' today', tone: 'good'),
            Pill('$open open homework', tone: 'warn'),
          ]),
          SectionTitle("Today's periods", trailing: TextButton(onPressed: () => onOpen('timetable'), child: const Text('Timetable'))),
          if (wd > 5)
            const NeuCard(inset: true, child: Text('It\u2019s Sunday \u2014 no classes today.'))
          else if (today.isEmpty)
            const NeuCard(inset: true, child: Text('You have no periods today.'))
          else
            for (final e in today)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  radius: 14,
                  child: Row(children: [
                    SizedBox(
                        width: 78, child: Text(fmtTime(e.startTime), style: c.small.copyWith(color: c.text, fontWeight: FontWeight.w600))),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.title, style: c.bodyStrong),
                      if (labels[e.classId] != null) Text(labels[e.classId]!, style: c.small)
                    ])),
                    if (e.room.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text('Rm ${e.room}', style: c.small)),
                  ]),
                ),
              ),
          if (exams.isNotEmpty) ...[
            SectionTitle('Upcoming exams', trailing: TextButton(onPressed: () => onOpen('exams'), child: const Text('Schedule'))),
            for (final e in exams.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: NeuCard(
                  padding: const EdgeInsets.all(14),
                  radius: 14,
                  child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${e.subjectName} \u00b7 ${e.className}', style: c.bodyStrong),
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
