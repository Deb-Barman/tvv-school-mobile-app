import 'package:flutter/material.dart';

import '../../../data/models/academics.dart';
import '../../../data/models/admin.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import 'dashboard_parts.dart';

class AdminHomeView extends StatelessWidget {
  const AdminHomeView({super.key, required this.onOpen});
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<AdminStats>(
      skeleton: const DashboardSkeleton(),
      load: svc.admin.stats,
      builder: (ctx, s, reload) {
        final c = AppColors.of(ctx);
        final maxDay = s.last7.fold<int>(1, (m, d) => (d.present + d.absent) > m ? d.present + d.absent : m);
        return PageList(children: [
          NeuCard(
            depth: 3,
            radius: 26,
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${greeting()} \u00b7 SUPER ADMIN'.toUpperCase(), style: c.eyebrow),
              const SizedBox(height: 4),
              Text(me.fullName, style: c.display),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                Pill(s.currentSession == null ? 'No current session' : 'Session ${s.currentSession}',
                    tone: s.currentSession == null ? 'warn' : 'good'),
                if (s.passwordRequests > 0)
                  Pill('${s.passwordRequests} password request${s.passwordRequests == 1 ? '' : 's'}', tone: 'bad', icon: Icons.key_rounded),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          TileGrid(tiles: [
            StatTile(icon: Icons.school_outlined, label: 'Students', value: '${s.students}', onTap: () => onOpen('accounts')),
            StatTile(icon: Icons.badge_outlined, label: 'Teachers', value: '${s.teachers}', tone: 'warn', onTap: () => onOpen('accounts')),
            StatTile(
                icon: Icons.how_to_reg_outlined,
                label: 'New admissions',
                value: '${s.admissionsPending}',
                tone: s.admissionsPending > 0 ? 'bad' : 'good',
                onTap: () => onOpen('inbox')),
            StatTile(
                icon: Icons.mail_outline_rounded,
                label: 'New messages',
                value: '${s.newMessages}',
                tone: s.newMessages > 0 ? 'bad' : 'good',
                onTap: () => onOpen('inbox')),
          ]),
          if (s.studentsWithoutClass > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                onTap: () => onOpen('accounts'),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: c.warn),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          '${s.studentsWithoutClass} student${s.studentsWithoutClass == 1 ? ' has' : 's have'} no class yet. Open Accounts to place them.',
                          style: c.body)),
                ]),
              ),
            ),
          const SectionTitle('Attendance today'),
          NeuCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: _Mini(label: 'Present', value: '${s.presentToday}', tone: 'good')),
                Expanded(child: _Mini(label: 'Absent', value: '${s.absentToday}', tone: 'bad')),
                Expanded(child: _Mini(label: 'Marked', value: '${s.markedToday}', tone: 'accent')),
              ]),
              const SizedBox(height: 16),
              Text('LAST 7 DAYS', style: c.eyebrow),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final d in s.last7)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (d.absent > 0)
                            Container(
                                height: 64 * d.absent / maxDay,
                                decoration:
                                    BoxDecoration(color: c.bad, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)))),
                          Container(
                              height: d.present == 0 && d.absent == 0 ? 3 : 64 * d.present / maxDay,
                              decoration: BoxDecoration(
                                  color: d.present == 0 && d.absent == 0 ? c.edge : c.good,
                                  borderRadius: d.absent > 0 ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(6)))),
                          const SizedBox(height: 4),
                          Text(d.date == null ? '' : weekdayShort[d.date!.weekday - 1].substring(0, 1), style: c.small),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
          const SectionTitle('Quick actions'),
          QuickActionRow(actions: [
            QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'New account', onTap: () => onOpen('accounts')),
            QuickAction(icon: Icons.campaign_outlined, label: 'Post notice', onTap: () => onOpen('notices')),
            QuickAction(icon: Icons.fact_check_outlined, label: 'Attendance', onTap: () => onOpen('take_attendance')),
          ]),
          const SectionTitle('School at a glance'),
          TileGrid(tiles: [
            StatTile(icon: Icons.class_outlined, label: 'Classes', value: '${s.classes}', onTap: () => onOpen('class_info')),
            StatTile(
                icon: Icons.menu_book_outlined, label: 'Subjects', value: '${s.subjects}', tone: 'warn', onTap: () => onOpen('class_info')),
            StatTile(icon: Icons.campaign_outlined, label: 'Notices', value: '${s.notices}', onTap: () => onOpen('notices')),
            StatTile(
                icon: Icons.event_outlined,
                label: 'Upcoming events',
                value: '${s.eventsUpcoming}',
                tone: 'good',
                onTap: () => onOpen('events')),
          ]),
          if (s.recentAdmissions.isNotEmpty) ...[
            SectionTitle('Recent admission enquiries',
                trailing: TextButton(onPressed: () => onOpen('inbox'), child: const Text('Open inbox'))),
            for (final a in s.recentAdmissions.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  onTap: () => onOpen('inbox'),
                  child: Row(children: [
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['applicant_name'] ?? ''}', style: c.bodyStrong),
                      Text('For ${a['applying_for_class'] ?? ''}', style: c.small)
                    ])),
                    Pill(
                        '${a['status'] ?? ''}'.isEmpty
                            ? ''
                            : '${a['status']}'.substring(0, 1) + '${a['status']}'.substring(1).toLowerCase(),
                        tone: a['status'] == 'PENDING' ? 'warn' : 'good'),
                  ]),
                ),
              ),
          ],
        ]);
      },
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: c.tone(tone))),
      Text(label, style: c.small)
    ]);
  }
}
