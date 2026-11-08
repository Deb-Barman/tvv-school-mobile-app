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

class _HwData {
  _HwData(this.homework, this.classes, this.subjects);
  final List<Homework> homework;
  final List<SchoolClass> classes;
  final List<Subject> subjects;
}

/// Students tick homework inside its start-end window; teachers and the Super Admin set it and see who finished.
class HomeworkView extends StatelessWidget {
  const HomeworkView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_HwData>(
      load: () async {
        final (hw, subjects, classes) = await (
          svc.academics.homework(),
          svc.academics.subjects(),
          me.isStudent ? Future.value(<SchoolClass>[]) : svc.academics.classes(),
        ).wait;
        return _HwData(hw, classes, subjects);
      },
      builder: (ctx, data, reload) => me.isStudent ? _StudentHomework(data: data) : _StaffHomework(data: data, reload: reload),
    );
  }
}

// ------------------------------------------------------------------ student

class _StudentHomework extends StatefulWidget {
  const _StudentHomework({required this.data});
  final _HwData data;

  @override
  State<_StudentHomework> createState() => _StudentHomeworkState();
}

class _StudentHomeworkState extends State<_StudentHomework> {
  late List<Homework> _items = [...widget.data.homework];
  final Set<String> _busy = {};

  Future<void> _toggle(Homework h, bool value) async {
    final svc = context.svc;
    setState(() {
      _busy.add(h.id);
      _items = [for (final x in _items) x.id == h.id ? x.copyWith(done: value) : x];
    });
    try {
      final saved = await svc.academics.setHomeworkDone(h.id, value);
      if (!mounted) return;
      setState(() => _items = [for (final x in _items) x.id == h.id ? x.copyWith(done: saved) : x]);
    } catch (e) {
      if (!mounted) return;
      // Put the box back and tell the student exactly why (for example "opens on 12 Nov").
      setState(() => _items = [for (final x in _items) x.id == h.id ? x.copyWith(done: !value) : x]);
      toast(context, errorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(h.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final subjects = {for (final s in widget.data.subjects) s.id: s.name};
    final open = _items.where((h) => h.phase == 'open').toList();
    final upcoming = _items.where((h) => h.phase == 'upcoming').toList();
    final closed = _items.where((h) => h.phase == 'closed').toList();

    Widget card(Homework h) {
      final done = h.done == true;
      final locked = !h.canTick;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: NeuCard(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(
              value: done,
              activeColor: c.good,
              onChanged: (locked || _busy.contains(h.id)) ? null : (v) => _toggle(h, v ?? false),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.title, style: c.h2.copyWith(decoration: done ? TextDecoration.lineThrough : null, color: done ? c.muted : c.text)),
                if (h.details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(h.details, style: c.body)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Pill(h.subjectName.isNotEmpty ? h.subjectName : (subjects[h.subjectId] ?? 'Subject')),
                  if (h.phase == 'upcoming') Pill('Opens ${fmtDateShort(h.startDate)}', tone: 'warn', icon: Icons.lock_clock_outlined),
                  if (h.phase == 'closed') Pill('Closed', tone: 'bad', icon: Icons.lock_outline_rounded),
                  if (h.phase == 'open') Pill('Due ${relativeDay(h.dueDate).toLowerCase()}', tone: 'good'),
                  Text(fmtDate(h.dueDate), style: c.small),
                ]),
              ]),
            ),
          ]),
        ),
      );
    }

    return PageList(children: [
      if (_items.isEmpty) const EmptyState(icon: Icons.task_alt_rounded, title: 'No homework', message: 'You\u2019re all caught up.'),
      if (open.isNotEmpty) ...[SectionTitle('To do (${open.where((h) => h.done != true).length} left)'), for (final h in open) card(h)],
      if (upcoming.isNotEmpty) ...[const SectionTitle('Coming up'), for (final h in upcoming) card(h)],
      if (closed.isNotEmpty) ...[const SectionTitle('Closed'), for (final h in closed) card(h)],
    ]);
  }
}

// ------------------------------------------------------------------ staff

class _StaffHomework extends StatefulWidget {
  const _StaffHomework({required this.data, required this.reload});
  final _HwData data;
  final Future<void> Function() reload;

  @override
  State<_StaffHomework> createState() => _StaffHomeworkState();
}

class _StaffHomeworkState extends State<_StaffHomework> {
  String? _classFilter;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final svc = context.svc;
    final classes = widget.data.classes;
    final items = widget.data.homework.where((h) => _classFilter == null || h.classId == _classFilter).toList();
    return PageList(children: [
      NeuButton(
        label: 'Set new homework',
        icon: Icons.add_rounded,
        onPressed: () async {
          final saved = await showSheet<bool>(
              context, (_) => HomeworkForm(classes: classes, subjects: widget.data.subjects, initialClassId: _classFilter));
          if (saved == true) {
            if (context.mounted) toast(context, 'Homework set.');
            await widget.reload();
          }
        },
      ),
      const SizedBox(height: 12),
      PickerField(
        label: 'Show',
        value: _classFilter == null ? 'All classes' : classes.where((k) => k.id == _classFilter).firstOrNull?.label,
        onTap: () async {
          final v = await pickOne<SchoolClass>(context,
              title: 'Show homework for',
              options: classes,
              labelOf: (k) => k.label,
              selected: classes.where((k) => k.id == _classFilter).firstOrNull);
          if (v != null) setState(() => _classFilter = v.id);
        },
      ),
      if (_classFilter != null)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => setState(() => _classFilter = null), child: const Text('Show all classes'))),
      if (items.isEmpty)
        const EmptyState(
            icon: Icons.assignment_outlined, title: 'No homework yet', message: 'Set homework and it will show up for the class.'),
      for (final h in items)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: NeuCard(
            onTap: () => showSheet<void>(context, (_) => _CompletionsSheet(homework: h)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(h.title, style: c.h2)),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: c.muted),
                  onSelected: (v) async {
                    if (v == 'edit') {
                      final saved = await showSheet<bool>(
                          context, (_) => HomeworkForm(classes: classes, subjects: widget.data.subjects, existing: h));
                      if (saved == true) {
                        if (context.mounted) toast(context, 'Homework updated.');
                        await widget.reload();
                      }
                    } else {
                      final yes = await confirm(context,
                          title: 'Delete this homework?', message: '\u201c${h.title}\u201d and its tick marks will be removed.');
                      if (!yes || !context.mounted) return;
                      final ok = await guard(context, () => svc.academics.deleteHomework(h.id), success: 'Homework deleted.');
                      if (ok) await widget.reload();
                    }
                  },
                  itemBuilder: (_) =>
                      const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                ),
              ]),
              if (h.details.isNotEmpty) Text(h.details, style: c.body),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Pill(h.className.isNotEmpty ? h.className : (classes.where((k) => k.id == h.classId).firstOrNull?.label ?? 'Class')),
                Pill(h.subjectName, tone: 'warn'),
                Pill(h.phase == 'open' ? 'Open' : (h.phase == 'upcoming' ? 'Not open yet' : 'Closed'),
                    tone: h.phase == 'open' ? 'good' : (h.phase == 'upcoming' ? 'warn' : 'bad')),
                Text('${fmtDateShort(h.startDate)} \u2192 ${fmtDate(h.dueDate)}', style: c.small),
              ]),
              if (h.submitted != null && h.classSize != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: h.classSize == 0 ? 0 : h.submitted! / h.classSize!, minHeight: 8, backgroundColor: c.inset, color: c.good)),
                const SizedBox(height: 6),
                Text('${h.submitted} of ${h.classSize} students done \u00b7 tap to see who', style: c.small),
              ],
            ]),
          ),
        ),
    ]);
  }
}

class _CompletionsSheet extends StatelessWidget {
  const _CompletionsSheet({required this.homework});
  final Homework homework;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final c = AppColors.of(context);
    return SheetBody(
      title: homework.title,
      subtitle: 'Who has ticked this homework',
      children: [
        FutureBuilder<List<HomeworkCompletion>>(
          future: svc.academics.homeworkCompletions(homework.id),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done)
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
            if (snap.hasError) return Text(errorText(snap.error!), style: TextStyle(color: c.bad));
            final rows = snap.data ?? [];
            if (rows.isEmpty) return Text('No students in this class yet.', style: c.small);
            final done = rows.where((r) => r.done).length;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$done of ${rows.length} done', style: c.h2),
              const SizedBox(height: 10),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(r.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: r.done ? c.good : c.muted, size: 22),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.rollNumber.isEmpty ? r.fullName : '${r.rollNumber}. ${r.fullName}', style: c.body)),
                    if (r.completedAt != null) Text(fmtDateShort(r.completedAt), style: c.small),
                  ]),
                ),
            ]);
          },
        ),
      ],
    );
  }
}

class HomeworkForm extends StatefulWidget {
  const HomeworkForm({super.key, required this.classes, required this.subjects, this.existing, this.initialClassId});
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final Homework? existing;
  final String? initialClassId;

  @override
  State<HomeworkForm> createState() => _HomeworkFormState();
}

class _HomeworkFormState extends State<HomeworkForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _details = TextEditingController(text: widget.existing?.details);
  late String? _classId = widget.existing?.classId ?? widget.initialClassId;
  String? _subjectId;
  late DateTime _start = widget.existing?.startDate ?? schoolNow();
  late DateTime _due = widget.existing?.dueDate ?? schoolNow().add(const Duration(days: 3));
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subjectId = widget.existing?.subjectId;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    super.dispose();
  }

  List<Subject> get _classSubjects => widget.subjects.where((s) => s.classId == _classId).toList();

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_classId == null || _subjectId == null) {
      setState(() => _error = 'Choose the class and the subject.');
      return;
    }
    if (_due.isBefore(dayOnly(_start))) {
      setState(() => _error = 'The end date must be on or after the start date.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.saveHomework(
          id: widget.existing?.id,
          classId: _classId!,
          subjectId: _subjectId!,
          title: _title.text.trim(),
          details: _details.text.trim(),
          startDate: _start,
          dueDate: _due);
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
      title: widget.existing == null ? 'Set homework' : 'Edit homework',
      subtitle: 'Students can tick it only between the start and end dates.',
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
                          title: 'Subject', options: _classSubjects, labelOf: (s) => s.name, selected: subject);
                      if (s != null) setState(() => _subjectId = s.id);
                    },
            ),
            const SizedBox(height: 14),
            AppField(
                controller: _title,
                label: 'Title',
                icon: Icons.assignment_outlined,
                maxLength: 200,
                capitalization: TextCapitalization.sentences,
                validator: (v) => requiredField(v, 'Title')),
            const SizedBox(height: 14),
            AppField(controller: _details, label: 'Details (optional)', maxLines: 4, capitalization: TextCapitalization.sentences),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: PickerField(
                  label: 'Opens',
                  value: fmtDate(_start),
                  icon: Icons.calendar_month_rounded,
                  onTap: () async {
                    final d = await pickDate(context, initial: _start);
                    if (d != null) setState(() => _start = d);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: 'Ends',
                  value: fmtDate(_due),
                  icon: Icons.event_busy_rounded,
                  onTap: () async {
                    final d = await pickDate(context, initial: _due);
                    if (d != null) setState(() => _due = d);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 20),
            SaveBar(
                onSave: _busy ? null : _save, busy: _busy, error: _error, label: widget.existing == null ? 'Set homework' : 'Save changes'),
          ]),
        ),
      ],
    );
  }
}
