import 'package:flutter/material.dart';

import '../../../data/attendance_stats.dart';
import '../../../data/models/academics.dart';
import '../../../data/models/admin.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

// ================================================================= my attendance (student / teacher)

class _HistoryData {
  _HistoryData(this.records, this.session);
  final List<AttendanceRecord> records;
  final AcademicSession? session;
}

/// A student's (or teacher's) own attendance: percentage of the session, month calendar and recent days.
class AttendanceHistoryView extends StatelessWidget {
  const AttendanceHistoryView({super.key, this.teacher = false});
  final bool teacher;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<_HistoryData>(
      skeleton: const DashboardSkeleton(),
      load: () async {
        final (records, sessions) =
            await (teacher ? svc.academics.myTeacherAttendance() : svc.academics.attendance(), svc.academics.sessions()).wait;
        final current = sessions.where((s) => s.isCurrent).firstOrNull;
        return _HistoryData(records, current);
      },
      builder: (ctx, data, reload) {
        final c = AppColors.of(ctx);
        final s = AttendanceSummary.of(data.records, workingDays: data.session?.workingDays, minPercent: data.session?.minPercent ?? 75);
        final byDay = {for (final r in data.records) dayOnly(r.date): r.status};
        final recent = [...data.records]..sort((a, b) => b.date.compareTo(a.date));
        return PageList(children: [
          NeuCard(
            depth: 3,
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              ProgressRing(
                  percent: s.ringPercent,
                  label: s.ringLabel,
                  sub: data.session?.workingDays != null ? 'of session' : 'present',
                  tone: s.tone,
                  size: 118),
              const SizedBox(width: 20),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.countLabel, style: c.display.copyWith(fontSize: 24)),
                  Text(
                      data.session?.workingDays != null
                          ? 'days present out of ${data.session!.workingDays} working days'
                          : 'days present out of days marked',
                      style: c.small),
                  const SizedBox(height: 10),
                  if (s.percentOfMarked != null) Pill('${pct(s.percentOfMarked, 0)} of days held so far', tone: s.tone),
                  const SizedBox(height: 6),
                  Text('Minimum needed: ${data.session?.minPercent ?? 75}%', style: c.small),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Stat(label: 'Present', value: '${s.present}', tone: 'good')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: 'Absent', value: '${s.absent}', tone: 'bad')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(label: 'Marked', value: '${s.marked}', tone: 'accent')),
          ]),
          const SizedBox(height: 14),
          _MonthCalendar(byDay: byDay),
          if (recent.isNotEmpty) ...[
            const SectionTitle('Recent days'),
            for (final r in recent.take(14))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  radius: 16,
                  child: Row(children: [
                    Expanded(child: Text(fmtDate(r.date), style: c.bodyStrong)),
                    Text(weekdayNames[r.date.weekday - 1], style: c.small),
                    const SizedBox(width: 12),
                    Pill(r.status.label, tone: r.status == AttendanceStatus.present ? 'good' : 'bad'),
                  ]),
                ),
              ),
          ] else
            const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No attendance marked yet',
                message: 'Your attendance will appear here once it is recorded.'),
        ]);
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.tone});
  final String label;
  final String value;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      radius: 18,
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c.tone(tone))),
        const SizedBox(height: 2),
        Text(label, style: c.small),
      ]),
    );
  }
}

class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({required this.byDay});
  final Map<DateTime, AttendanceStatus> byDay;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) => setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + days) / 7).ceil();
    final today = dayOnly(DateTime.now());

    Widget cell(int index) {
      final d = index - leading + 1;
      if (d < 1 || d > days) return const SizedBox(height: 40);
      final date = DateTime(_month.year, _month.month, d);
      final st = widget.byDay[date];
      final isToday = sameDay(date, today);
      final Color? bg = st == null ? null : (st == AttendanceStatus.present ? c.good : c.bad).withValues(alpha: 0.18);
      final Color fg = st == null ? c.text : (st == AttendanceStatus.present ? c.good : c.bad);
      return Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(12), border: isToday ? Border.all(color: c.accent, width: 1.6) : null),
        child: Text('$d', style: TextStyle(fontWeight: st == null ? FontWeight.w500 : FontWeight.w800, color: fg, fontSize: 13.5)),
      );
    }

    return NeuCard(
      child: Column(children: [
        Row(children: [
          NeuIconButton(icon: Icons.chevron_left_rounded, onPressed: () => _shift(-1), size: 38, tooltip: 'Previous month'),
          Expanded(child: Text('${monthName(_month.month)} ${_month.year}', textAlign: TextAlign.center, style: c.h2)),
          NeuIconButton(icon: Icons.chevron_right_rounded, onPressed: () => _shift(1), size: 38, tooltip: 'Next month'),
        ]),
        const SizedBox(height: 12),
        Row(children: [for (final w in weekdayShort) Expanded(child: Center(child: Text(w.substring(0, 2), style: c.small)))]),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++) Row(children: [for (var k = 0; k < 7; k++) Expanded(child: cell(r * 7 + k))]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Dot(c.good, 'Present'),
          const SizedBox(width: 18),
          _Dot(c.bad, 'Absent'),
        ]),
      ]),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: c.small)
    ]);
  }
}

// ================================================================= marking (staff)

class MarkRow {
  const MarkRow({required this.id, required this.title, this.subtitle = ''});
  final String id;
  final String title;
  final String subtitle;
}

/// Present / Absent toggles for a list of people with a save button. Used for students and for teachers.
class AttendanceMarkSheet extends StatefulWidget {
  const AttendanceMarkSheet(
      {super.key,
      required this.rows,
      required this.initial,
      required this.onSave,
      this.emptyTitle = 'Nobody to mark',
      this.emptyMessage = ''});
  final List<MarkRow> rows;
  final Map<String, AttendanceStatus> initial;
  final Future<int> Function(Map<String, AttendanceStatus> marks) onSave;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<AttendanceMarkSheet> createState() => _AttendanceMarkSheetState();
}

class _AttendanceMarkSheetState extends State<AttendanceMarkSheet> {
  late final Map<String, AttendanceStatus> _marks = {...widget.initial};
  bool _busy = false;

  int get _present => _marks.values.where((s) => s == AttendanceStatus.present).length;
  int get _absent => _marks.values.where((s) => s == AttendanceStatus.absent).length;

  void _set(String id, AttendanceStatus s) => setState(() {
        // Tapping the selected choice again clears it, so a slip is easy to undo.
        if (_marks[id] == s) {
          _marks.remove(id);
        } else {
          _marks[id] = s;
        }
      });

  Future<void> _save() async {
    if (_marks.isEmpty) {
      toast(context, 'Mark at least one person first.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await widget.onSave({..._marks});
      if (mounted) toast(context, 'Attendance saved for $n.');
    } catch (e) {
      if (mounted) toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.rows.isEmpty)
      return PageList(children: [EmptyState(icon: Icons.groups_outlined, title: widget.emptyTitle, message: widget.emptyMessage)]);
    final unmarked = widget.rows.length - _marks.length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Expanded(
              child: Wrap(spacing: 8, runSpacing: 6, children: [
            Pill('$_present present', tone: 'good'),
            Pill('$_absent absent', tone: 'bad'),
            Pill('$unmarked not marked', tone: 'warn')
          ])),
          TextButton(
            onPressed: () => setState(() {
              for (final r in widget.rows) {
                _marks[r.id] = AttendanceStatus.present;
              }
            }),
            child: const Text('All present'),
          ),
        ]),
      ),
      Expanded(
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          for (final r in widget.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                radius: 16,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, style: c.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (r.subtitle.isNotEmpty) Text(r.subtitle, style: c.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  _Choice(
                      label: 'P',
                      tooltip: 'Present',
                      on: _marks[r.id] == AttendanceStatus.present,
                      color: c.good,
                      onTap: () => _set(r.id, AttendanceStatus.present)),
                  const SizedBox(width: 8),
                  _Choice(
                      label: 'A',
                      tooltip: 'Absent',
                      on: _marks[r.id] == AttendanceStatus.absent,
                      color: c.bad,
                      onTap: () => _set(r.id, AttendanceStatus.absent)),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: NeuButton(label: 'Save attendance', icon: Icons.check_rounded, busy: _busy, onPressed: _save),
      ),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.tooltip, required this.on, required this.color, required this.onTap});
  final String label;
  final String tooltip;
  final bool on;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 44,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: on ? color : c.inset, borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? color : c.edge)),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: on ? Colors.white : c.muted)),
        ),
      ),
    );
  }
}

/// Take a class's attendance for a day (teachers and the Super Admin).
class TakeAttendanceView extends StatelessWidget {
  const TakeAttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<List<SchoolClass>>(
      refreshable: false, // the body below has its own AsyncPage
      skeleton: const ListSkeleton(count: 4),
      load: () => svc.academics.classes(),
      builder: (ctx, classes, reload) => _TakeBody(classes: classes),
    );
  }
}

class _TakeBody extends StatefulWidget {
  const _TakeBody({required this.classes});
  final List<SchoolClass> classes;

  @override
  State<_TakeBody> createState() => _TakeBodyState();
}

class _TakeBodyState extends State<_TakeBody> {
  String? _classId;
  DateTime _date = dayOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    if (widget.classes.isNotEmpty) _classId = widget.classes.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final klass = widget.classes.where((k) => k.id == _classId).firstOrNull;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: PickerField(
              label: 'Class',
              value: klass?.label,
              onTap: () async {
                final k = await pickOne<SchoolClass>(context,
                    title: 'Choose a class', options: widget.classes, labelOf: (k) => k.label, selected: klass);
                if (k != null) setState(() => _classId = k.id);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: PickerField(
              label: 'Date',
              value: fmtDateShort(_date),
              icon: Icons.calendar_month_rounded,
              onTap: () async {
                final d = await pickDate(context, initial: _date, last: dayOnly(DateTime.now()));
                if (d != null) setState(() => _date = dayOnly(d));
              },
            ),
          ),
        ]),
      ),
      Expanded(
        child: _classId == null
            ? const EmptyState(
                icon: Icons.class_outlined, title: 'No classes yet', message: 'The Super Admin needs to create classes first.')
            : AsyncPage<({List<StudentProfile> students, List<AttendanceRecord> existing})>(
                key: ValueKey('$_classId|${isoLike(_date)}'),
                skeleton: const ListSkeleton(count: 7),
                load: () async {
                  final (students, existing) =
                      await (svc.academics.students(classId: _classId), svc.academics.attendance(classId: _classId, date: _date)).wait;
                  return (students: students, existing: existing);
                },
                builder: (ctx, d, reload) {
                  final sorted = [...d.students]
                    ..sort((a, b) => (int.tryParse(a.rollNumber) ?? 9999).compareTo(int.tryParse(b.rollNumber) ?? 9999));
                  return AttendanceMarkSheet(
                    key: ValueKey('${_classId}_${isoLike(_date)}_${d.existing.length}'),
                    rows: [
                      for (final s in sorted)
                        MarkRow(id: s.userId, title: s.fullName, subtitle: s.rollNumber.isEmpty ? '' : 'Roll ${s.rollNumber}')
                    ],
                    initial: {for (final r in d.existing) r.studentId: r.status},
                    emptyTitle: 'No students in this class',
                    emptyMessage: 'Students appear here once the Super Admin adds them to the class.',
                    onSave: (marks) => svc.academics.saveClassAttendance(_date, marks),
                  );
                },
              ),
      ),
    ]);
  }
}

String isoLike(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Super Admin: mark teachers present / absent for a day.
class TeacherAttendanceAdminView extends StatefulWidget {
  const TeacherAttendanceAdminView({super.key});

  @override
  State<TeacherAttendanceAdminView> createState() => _TeacherAttendanceAdminViewState();
}

class _TeacherAttendanceAdminViewState extends State<TeacherAttendanceAdminView> {
  DateTime _date = dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: PickerField(
          label: 'Date',
          value: fmtDate(_date),
          icon: Icons.calendar_month_rounded,
          onTap: () async {
            final d = await pickDate(context, initial: _date, last: dayOnly(DateTime.now()));
            if (d != null) setState(() => _date = dayOnly(d));
          },
        ),
      ),
      Expanded(
        child: AsyncPage<List<TeacherSheetRow>>(
          key: ValueKey(isoLike(_date)),
          skeleton: const ListSkeleton(count: 6),
          load: () => svc.academics.teacherSheet(_date),
          builder: (ctx, rows, reload) => AttendanceMarkSheet(
            rows: [for (final t in rows) MarkRow(id: t.teacherId, title: t.fullName, subtitle: t.department)],
            initial: {
              for (final t in rows)
                if (t.status != null) t.teacherId: t.status!
            },
            emptyTitle: 'No teachers yet',
            emptyMessage: 'Create teacher accounts first.',
            onSave: (marks) => svc.academics.saveTeacherAttendance(_date, marks),
          ),
        ),
      ),
    ]);
  }
}

// ================================================================= report (Super Admin)

class AttendanceReportView extends StatefulWidget {
  const AttendanceReportView({super.key});

  @override
  State<AttendanceReportView> createState() => _AttendanceReportViewState();
}

class _AttendanceReportViewState extends State<AttendanceReportView> {
  String _kind = 'students';
  String? _classId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final c = AppColors.of(context);
    return Column(children: [
      ChipBar<String>(
          items: const ['students', 'teachers'],
          selected: _kind,
          labelOf: (k) => k == 'students' ? 'Students' : 'Teachers',
          onChanged: (k) => setState(() {
                _kind = k;
                _classId = null;
              })),
      if (_kind == 'students')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: FutureBuilder<List<SchoolClass>>(
            future: _classesFuture ??= svc.academics.classes(),
            builder: (ctx, snap) {
              final classes = snap.data ?? const <SchoolClass>[];
              final k = classes.where((x) => x.id == _classId).firstOrNull;
              return PickerField(
                label: 'Class',
                value: k?.label ?? 'All classes',
                onTap: classes.isEmpty
                    ? null
                    : () async {
                        final v = await pickOne<SchoolClass>(ctx,
                            title: 'Filter by class', options: classes, labelOf: (x) => x.label, selected: k);
                        if (v != null) setState(() => _classId = v.id);
                      },
              );
            },
          ),
        ),
      if (_classId != null && _kind == 'students')
        Align(
            alignment: Alignment.centerLeft,
            child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: TextButton(onPressed: () => setState(() => _classId = null), child: const Text('Show all classes')))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          style: c.body,
          decoration: InputDecoration(
            hintText: 'Search by name',
            prefixIcon: Icon(Icons.search_rounded, color: c.muted),
            filled: true,
            fillColor: c.inset,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.edge)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.edge)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent, width: 1.6)),
          ),
        ),
      ),
      Expanded(
        child: AsyncPage<AttendanceReport>(
          key: ValueKey('$_kind|$_classId'),
          skeleton: const ListSkeleton(header: true),
          load: () => svc.admin.attendanceReport(kind: _kind, classId: _classId),
          builder: (ctx, r, reload) {
            final rows = r.rows
                .where((x) => _query.isEmpty || x.name.toLowerCase().contains(_query) || x.username.toLowerCase().contains(_query))
                .toList();
            return PageList(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
              NeuCard(
                depth: 3,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.sessionLabel == null ? 'No current session' : 'Session ${r.sessionLabel}'}', style: c.eyebrow),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _Stat(label: 'People', value: '${r.people}', tone: 'accent')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _Stat(
                            label: 'Average',
                            value: r.averagePercent == null ? '\u2014' : '${r.averagePercent!.toStringAsFixed(0)}%',
                            tone: 'good')),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    Pill('${r.ok} on track', tone: 'good'),
                    Pill('${r.low} low', tone: 'warn'),
                    Pill('${r.critical} critical', tone: 'bad'),
                    Pill('${r.noData} no data'),
                  ]),
                  const SizedBox(height: 12),
                  Text(
                      r.workingDays == null
                          ? '${r.daysHeld} school days held. Set the session\u2019s working days to see the full-year view.'
                          : '${r.daysHeld} of ${r.workingDays} working days held \u00b7 ${r.daysLeft ?? 0} left \u00b7 minimum ${r.minPercent}%',
                      style: c.small),
                ]),
              ),
              const SizedBox(height: 14),
              if (rows.isEmpty)
                const EmptyState(icon: Icons.search_off_rounded, title: 'Nobody found', message: 'Try a different name or filter.'),
              for (final x in rows) _ReportTile(row: x, workingDays: r.workingDays),
            ]);
          },
        ),
      ),
    ]);
  }

  Future<List<SchoolClass>>? _classesFuture;
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.row, required this.workingDays});
  final ReportRow row;
  final int? workingDays;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final tone = {'ok': 'good', 'low': 'warn', 'critical': 'bad'}[row.status] ?? 'accent';
    final label = {'ok': 'On track', 'low': 'Low', 'critical': 'Critical', 'no_data': 'No data'}[row.status] ?? row.status;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NeuCard(
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(children: [
          ProgressRing(
              percent: row.percent ?? 0,
              label: row.percent == null ? '\u2014' : '${row.percent!.toStringAsFixed(0)}%',
              size: 54,
              tone: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.name, style: c.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text([row.group, if (row.rollNumber.isNotEmpty) 'Roll ${row.rollNumber}'].join(' \u00b7 '),
                  style: c.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                  'Present ${row.present} \u00b7 Absent ${row.absent}${workingDays != null ? ' \u00b7 ${pct(row.percentOfTotal, 1)} of year' : ''}',
                  style: c.small),
            ]),
          ),
          Pill(label, tone: tone),
        ]),
      ),
    );
  }
}
