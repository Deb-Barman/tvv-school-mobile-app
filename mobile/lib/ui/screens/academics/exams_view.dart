import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../data/models/academics.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import '../../../core/clock.dart';

class _ExamData {
  _ExamData(this.exams, this.classes, this.subjects);
  final List<Exam> exams;
  final List<SchoolClass> classes;
  final List<Subject> subjects;
}

/// Examination schedule. Everyone reads it (students only see their own class); staff can add, edit and delete.
class ExamsView extends StatelessWidget {
  const ExamsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_ExamData>(
      load: () async {
        final (exams, subjects, classes) = await (
          svc.academics.exams(),
          svc.academics.subjects(),
          me.isStudent ? Future.value(<SchoolClass>[]) : svc.academics.classes()
        ).wait;
        return _ExamData(exams, classes, subjects);
      },
      builder: (ctx, data, reload) {
        final c = AppColors.of(ctx);
        final today = dayOnly(schoolNow());
        final subjects = {for (final s in data.subjects) s.id: s.name};
        final classes = {for (final k in data.classes) k.id: k.label};
        final upcoming = data.exams.where((e) => e.date != null && !e.date!.isBefore(today)).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
        final past = data.exams.where((e) => e.date == null || e.date!.isBefore(today)).toList()
          ..sort((a, b) => (b.date ?? today).compareTo(a.date ?? today));

        Widget row(Exam e, {bool dim = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: dim ? c.inset : c.accentSoft, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Text(e.date == null ? '\u2014' : '${e.date!.day}',
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dim ? c.muted : c.accent)),
                      Text(e.date == null ? '' : monthShort(e.date!.month).toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dim ? c.muted : c.accent)),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.subjectName.isNotEmpty ? e.subjectName : (subjects[e.subjectId] ?? 'Subject'), style: c.h2),
                      Text(e.name, style: c.small.copyWith(fontSize: 13.5)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        if (!dim) Pill(relativeDay(e.date), tone: 'good'),
                        if (e.startTime != null && e.startTime!.isNotEmpty) Pill(fmtTime(e.startTime), icon: Icons.schedule_rounded),
                        if (e.room.isNotEmpty) Pill('Room ${e.room}', tone: 'warn'),
                        if (!me.isStudent) Pill(e.className.isNotEmpty ? e.className : (classes[e.classId] ?? 'Class'), tone: 'good'),
                        Text(fmtDate(e.date), style: c.small),
                      ]),
                    ]),
                  ),
                  if (!me.isStudent)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: c.muted),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          final saved =
                              await showSheet<bool>(ctx, (_) => ExamForm(classes: data.classes, subjects: data.subjects, existing: e));
                          if (saved == true) {
                            if (ctx.mounted) toast(ctx, 'Exam updated.');
                            await reload();
                          }
                        } else {
                          final yes = await confirm(ctx, title: 'Delete this exam?', message: 'It will disappear from the schedule.');
                          if (!yes || !ctx.mounted) return;
                          final ok = await guard(ctx, () => svc.academics.deleteExam(e.id), success: 'Exam deleted.');
                          if (ok) await reload();
                        }
                      },
                      itemBuilder: (_) =>
                          const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                    ),
                ]),
              ),
            );

        return PageList(children: [
          if (!me.isStudent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeuButton(
                label: 'Add an exam',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final saved = await showSheet<bool>(ctx, (_) => ExamForm(classes: data.classes, subjects: data.subjects));
                  if (saved == true) {
                    if (ctx.mounted) toast(ctx, 'Exam added.');
                    await reload();
                  }
                },
              ),
            ),
          if (data.exams.isEmpty)
            const EmptyState(icon: Icons.quiz_outlined, title: 'No exams scheduled', message: 'The examination schedule will appear here.'),
          if (upcoming.isNotEmpty) const SectionTitle('Upcoming'),
          for (final e in upcoming) row(e),
          if (past.isNotEmpty) const SectionTitle('Earlier'),
          for (final e in past) row(e, dim: true),
        ]);
      },
    );
  }
}

class ExamForm extends StatefulWidget {
  const ExamForm({super.key, required this.classes, required this.subjects, this.existing});
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final Exam? existing;

  @override
  State<ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends State<ExamForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _room = TextEditingController(text: widget.existing?.room);
  late String? _classId = widget.existing?.classId;
  late String? _subjectId = widget.existing?.subjectId;
  late DateTime _date = widget.existing?.date ?? schoolNow().add(const Duration(days: 7));
  String? _time;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing?.startTime;
    _time = (t == null || t.length < 5) ? null : t.substring(0, 5);
  }

  @override
  void dispose() {
    _name.dispose();
    _room.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_classId == null || _subjectId == null) {
      setState(() => _error = 'Choose the class and the subject.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.saveExam(
          id: widget.existing?.id,
          classId: _classId!,
          subjectId: _subjectId!,
          name: _name.text.trim(),
          date: _date,
          startTime: _time,
          room: _room.text.trim());
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
    final klass = widget.classes.where((k) => k.id == _classId).firstOrNull;
    final subject = widget.subjects.where((s) => s.id == _subjectId).firstOrNull;
    return SheetBody(
      title: widget.existing == null ? 'Add an exam' : 'Edit exam',
      children: [
        Form(
          key: _key,
          child: Column(children: [
            PickerField(
              label: 'Class',
              value: klass?.label,
              onTap: () async {
                final k =
                    await pickOne<SchoolClass>(context, title: 'Class', options: widget.classes, labelOf: (k) => k.label, selected: klass);
                if (k != null) {
                  setState(() {
                    _classId = k.id;
                    if (subject != null && subject.classId != k.id) _subjectId = null;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            PickerField(
              label: 'Subject',
              value: subject?.name,
              onTap: _classId == null
                  ? null
                  : () async {
                      final s = await pickOne<Subject>(context,
                          title: 'Subject',
                          options: widget.subjects.where((s) => s.classId == _classId).toList(),
                          labelOf: (s) => s.name,
                          selected: subject);
                      if (s != null) setState(() => _subjectId = s.id);
                    },
            ),
            const SizedBox(height: 14),
            AppField(
                controller: _name,
                label: 'Exam name',
                hint: 'e.g. First Semester',
                icon: Icons.quiz_outlined,
                maxLength: 120,
                capitalization: TextCapitalization.words,
                validator: (v) => requiredField(v, 'Exam name')),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: PickerField(
                  label: 'Date',
                  value: fmtDate(_date),
                  icon: Icons.calendar_month_rounded,
                  onTap: () async {
                    final d = await pickDate(context, initial: _date);
                    if (d != null) setState(() => _date = d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: 'Time (optional)',
                  value: _time == null ? null : fmtTime(_time),
                  placeholder: 'Not set',
                  icon: Icons.schedule_rounded,
                  onTap: () async {
                    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 10, minute: 0));
                    if (t != null) setState(() => _time = apiTime(t.hour, t.minute));
                  },
                ),
              ),
            ]),
            const SizedBox(height: 14),
            AppField(controller: _room, label: 'Room (optional)', icon: Icons.meeting_room_outlined, maxLength: 30),
            const SizedBox(height: 20),
            SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: widget.existing == null ? 'Add exam' : 'Save changes'),
          ]),
        ),
      ],
    );
  }
}
