import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../data/models/academics.dart';
import '../../../data/models/user.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

class _Base {
  _Base({this.years = const [], this.classes = const [], this.teachers = const []});
  final List<ClassYear> years;
  final List<SchoolClass> classes;
  final List<TeacherProfileRow> teachers;
}

/// Weekly timetable. Students see their class (and earlier years); teachers see their own periods or any class;
/// the Super Admin can also add, edit and delete periods.
class TimetableView extends StatelessWidget {
  const TimetableView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_Base>(
      refreshable: false, // the body below has its own AsyncPage
      skeleton: const DashboardSkeleton(),
      load: () async {
        if (me.isStudent) return _Base(years: await svc.academics.myClassYears());
        final (classes, teachers) =
            await (svc.academics.classes(), me.isSuperAdmin ? svc.academics.teachers() : Future.value(<TeacherProfileRow>[])).wait;
        return _Base(classes: classes, teachers: teachers);
      },
      builder: (ctx, base, reload) => _TimetableBody(base: base, user: me),
    );
  }
}

class _TimetableBody extends StatefulWidget {
  const _TimetableBody({required this.base, required this.user});
  final _Base base;
  final AppUser user;

  @override
  State<_TimetableBody> createState() => _TimetableBodyState();
}

class _TimetableBodyState extends State<_TimetableBody> {
  late int _day = DateTime.now().weekday <= 6 ? DateTime.now().weekday - 1 : 0;
  String? _classId; // staff: chosen class (null + teacher => "my periods")
  String? _yearId; // student: chosen class year (null => current)
  late bool _mine = widget.user.isTeacher;
  int _version = 0;

  AppUser get _u => widget.user;

  @override
  void initState() {
    super.initState();
    if (_u.isSuperAdmin && widget.base.classes.isNotEmpty) _classId = widget.base.classes.first.id;
  }

  String get _title {
    if (_u.isStudent) {
      final y = widget.base.years.where((y) => y.id == _yearId).toList();
      return y.isEmpty ? 'My class' : y.first.title;
    }
    if (_mine) return 'My periods';
    final c = widget.base.classes.where((c) => c.id == _classId).toList();
    return c.isEmpty ? 'Choose a class' : c.first.label;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final c = AppColors.of(context);
    final canEdit = _u.isSuperAdmin && _classId != null;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(children: [
          if (_u.isStudent && widget.base.years.length > 1)
            Expanded(
              child: PickerField(
                label: 'Class year',
                value: _title,
                onTap: () async {
                  final y = await pickOne<ClassYear>(context,
                      title: 'Class year',
                      options: widget.base.years,
                      labelOf: (y) => y.title,
                      selected: widget.base.years.where((y) => y.id == _yearId).firstOrNull);
                  if (y != null) setState(() => _yearId = y.current ? null : y.id);
                },
              ),
            ),
          if (!_u.isStudent) ...[
            if (_u.isTeacher)
              // A horizontally scrolling bar needs a fixed width when it sits in a Row.
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                    width: 218,
                    child: ChipBar<bool>(
                        items: const [true, false],
                        selected: _mine,
                        labelOf: (v) => v ? 'My periods' : 'By class',
                        onChanged: (v) => setState(() => _mine = v),
                        padding: EdgeInsets.zero)),
              ),
            if (!_mine)
              Expanded(
                child: PickerField(
                  label: 'Class',
                  value: widget.base.classes.where((x) => x.id == _classId).firstOrNull?.label,
                  placeholder: 'Choose a class',
                  onTap: () async {
                    final x = await pickOne<SchoolClass>(context,
                        title: 'Choose a class',
                        options: widget.base.classes,
                        labelOf: (x) => x.label,
                        selected: widget.base.classes.where((x) => x.id == _classId).firstOrNull);
                    if (x != null) setState(() => _classId = x.id);
                  },
                ),
              ),
          ],
        ]),
      ),
      ChipBar<int>(
          items: const [0, 1, 2, 3, 4, 5], selected: _day, labelOf: (d) => weekdayShort[d], onChanged: (d) => setState(() => _day = d)),
      Expanded(
        child: (!_u.isStudent && !_mine && _classId == null)
            ? const EmptyState(
                icon: Icons.calendar_view_week_rounded, title: 'Choose a class', message: 'Pick a class above to see its timetable.')
            : AsyncPage<List<TimetableEntry>>(
                key: ValueKey('$_classId|$_yearId|$_mine|$_version'),
                load: () =>
                    svc.academics.timetable(classId: _u.isStudent ? _yearId : (_mine ? null : _classId), mineOnly: !_u.isStudent && _mine),
                builder: (ctx, entries, reload) {
                  final day = entries.where((e) => e.weekday == _day).toList()..sort((a, b) => a.period.compareTo(b.period));
                  final classLabels = {for (final k in widget.base.classes) k.id: k.label};
                  return PageList(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
                    if (canEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NeuButton(
                          label: 'Add a period on ${weekdayNames[_day]}',
                          icon: Icons.add_rounded,
                          secondary: true,
                          onPressed: () => _edit(ctx, null, day, () => setState(() => _version++)),
                        ),
                      ),
                    if (day.isEmpty)
                      EmptyState(
                          icon: Icons.event_available_outlined,
                          title: 'No periods on ${weekdayNames[_day]}',
                          message: _day == 5 ? 'Saturday may be a short day or a holiday.' : 'Nothing is scheduled for this day.'),
                    for (final e in day)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: NeuCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: e.isBreak ? c.inset : c.accentSoft, borderRadius: BorderRadius.circular(14)),
                              child: e.isBreak
                                  ? Icon(Icons.coffee_outlined, color: c.muted, size: 20)
                                  : Text('${e.period}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.accent)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.title, style: c.h2),
                                const SizedBox(height: 2),
                                Text('${fmtTime(e.startTime)} \u2013 ${fmtTime(e.endTime)}', style: c.small.copyWith(fontSize: 13.5)),
                                const SizedBox(height: 6),
                                Wrap(spacing: 8, runSpacing: 4, children: [
                                  if (e.teacherName.isNotEmpty) Pill(e.teacherName, icon: Icons.person_outline_rounded),
                                  if (e.room.isNotEmpty) Pill('Room ${e.room}', tone: 'warn'),
                                  if (_mine && classLabels[e.classId] != null) Pill(classLabels[e.classId]!, tone: 'good'),
                                ]),
                              ]),
                            ),
                            if (canEdit)
                              PopupMenuButton<String>(
                                icon: Icon(Icons.more_vert_rounded, color: c.muted),
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    await _edit(ctx, e, day, () => setState(() => _version++));
                                  } else {
                                    final yes = await confirm(ctx,
                                        title: 'Delete this period?',
                                        message: 'Period ${e.period} on ${weekdayNames[e.weekday]} will be removed.');
                                    if (!yes || !ctx.mounted) return;
                                    final ok = await guard(ctx, () => svc.academics.deleteTimetableEntry(e.id), success: 'Period deleted.');
                                    if (ok) setState(() => _version++);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete'))
                                ],
                              ),
                          ]),
                        ),
                      ),
                  ]);
                },
              ),
      ),
    ]);
  }

  Future<void> _edit(BuildContext ctx, TimetableEntry? existing, List<TimetableEntry> day, VoidCallback done) async {
    final svc = ctx.svc;
    List<Subject> subjects;
    try {
      subjects = await svc.academics.subjects(classId: _classId);
    } catch (e) {
      if (ctx.mounted) toast(ctx, errorText(e), error: true);
      return;
    }
    if (!ctx.mounted) return;
    final nextPeriod = day.isEmpty ? 1 : day.map((e) => e.period).reduce((a, b) => a > b ? a : b) + 1;
    final saved = await showSheet<bool>(
        ctx,
        (_) => _PeriodForm(
            classId: _classId!,
            weekday: _day,
            existing: existing,
            subjects: subjects,
            teachers: widget.base.teachers,
            suggestedPeriod: nextPeriod));
    if (saved == true) {
      if (ctx.mounted) toast(ctx, existing == null ? 'Period added.' : 'Period updated.');
      done();
    }
  }
}

class _PeriodForm extends StatefulWidget {
  const _PeriodForm(
      {required this.classId,
      required this.weekday,
      required this.existing,
      required this.subjects,
      required this.teachers,
      required this.suggestedPeriod});
  final String classId;
  final int weekday;
  final TimetableEntry? existing;
  final List<Subject> subjects;
  final List<TeacherProfileRow> teachers;
  final int suggestedPeriod;

  @override
  State<_PeriodForm> createState() => _PeriodFormState();
}

class _PeriodFormState extends State<_PeriodForm> {
  late final _period = TextEditingController(text: '${widget.existing?.period ?? widget.suggestedPeriod}');
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _room = TextEditingController(text: widget.existing?.room);
  late int _weekday = widget.existing?.weekday ?? widget.weekday;
  late String _start = _trim(widget.existing?.startTime) ?? '10:00';
  late String _end = _trim(widget.existing?.endTime) ?? '10:45';
  late bool _isBreak = widget.existing?.isBreak ?? false;
  String? _subjectId;
  String? _teacherId;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.existing?.subjectId;
    _teacherId = widget.existing?.teacherId;
  }

  static String? _trim(String? t) => (t == null || t.length < 5) ? null : t.substring(0, 5);

  @override
  void dispose() {
    _period.dispose();
    _label.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final cur = (start ? _start : _end).split(':');
    final t =
        await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(cur[0]) ?? 10, minute: int.tryParse(cur[1]) ?? 0));
    if (t == null) return;
    setState(() => start ? _start = apiTime(t.hour, t.minute) : _end = apiTime(t.hour, t.minute));
  }

  Future<void> _save() async {
    final period = int.tryParse(_period.text.trim());
    if (period == null || period < 1) {
      setState(() => _error = 'Enter a period number (1, 2, 3...).');
      return;
    }
    if (!_isBreak && _subjectId == null) {
      setState(() => _error = 'Choose a subject, or switch to "Break / other".');
      return;
    }
    if (_isBreak && _label.text.trim().isEmpty) {
      setState(() => _error = 'Give the break a name, for example "Lunch".');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.saveTimetableEntry(
        id: widget.existing?.id,
        classId: widget.classId,
        weekday: _weekday,
        period: period,
        startTime: _start,
        endTime: _end,
        subjectId: _isBreak ? null : _subjectId,
        label: _isBreak ? _label.text.trim() : '',
        teacherId: _isBreak ? null : _teacherId,
        room: _room.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subject = widget.subjects.where((s) => s.id == _subjectId).firstOrNull;
    final teacher = widget.teachers.where((t) => t.userId == _teacherId).firstOrNull;
    return SheetBody(
      title: widget.existing == null ? 'Add a period' : 'Edit period',
      children: [
        ChipBar<bool>(
            items: const [false, true],
            selected: _isBreak,
            labelOf: (v) => v ? 'Break / other' : 'Subject',
            onChanged: (v) => setState(() => _isBreak = v),
            padding: EdgeInsets.zero),
        const SizedBox(height: 14),
        PickerField(
          label: 'Day',
          value: weekdayNames[_weekday],
          onTap: () async {
            final d = await pickOne<int>(context,
                title: 'Day', options: const [0, 1, 2, 3, 4, 5], labelOf: (d) => weekdayNames[d], selected: _weekday);
            if (d != null) setState(() => _weekday = d);
          },
        ),
        const SizedBox(height: 14),
        AppField(controller: _period, label: 'Period number', icon: Icons.numbers_rounded, keyboard: TextInputType.number, maxLength: 2),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: PickerField(label: 'Starts', value: fmtTime(_start), icon: Icons.schedule_rounded, onTap: () => _pickTime(true))),
          const SizedBox(width: 12),
          Expanded(child: PickerField(label: 'Ends', value: fmtTime(_end), icon: Icons.schedule_rounded, onTap: () => _pickTime(false))),
        ]),
        const SizedBox(height: 14),
        if (_isBreak)
          AppField(controller: _label, label: 'Name', hint: 'Lunch, Assembly, Games...', icon: Icons.coffee_outlined, maxLength: 60)
        else ...[
          PickerField(
            label: 'Subject',
            value: subject?.name,
            onTap: () async {
              final s =
                  await pickOne<Subject>(context, title: 'Subject', options: widget.subjects, labelOf: (s) => s.name, selected: subject);
              if (s != null) setState(() => _subjectId = s.id);
            },
          ),
          const SizedBox(height: 14),
          PickerField(
            label: 'Teacher (optional)',
            value: teacher?.fullName,
            placeholder: 'Not assigned',
            onTap: () async {
              final t = await pickOne<TeacherProfileRow>(context,
                  title: 'Teacher', options: widget.teachers, labelOf: (t) => t.fullName, selected: teacher);
              if (t != null) setState(() => _teacherId = t.userId);
            },
          ),
          if (_teacherId != null)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _teacherId = null), child: const Text('Clear teacher'))),
        ],
        const SizedBox(height: 14),
        AppField(controller: _room, label: 'Room (optional)', icon: Icons.meeting_room_outlined, maxLength: 30),
        const SizedBox(height: 20),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: widget.existing == null ? 'Add period' : 'Save changes'),
      ],
    );
  }
}
