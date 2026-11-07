import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../data/models/academics.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

// ================================================================= students (staff)

class _StudentsData {
  _StudentsData(this.students, this.classes);
  final List<StudentProfile> students;
  final List<SchoolClass> classes;
}

class StudentsView extends StatefulWidget {
  const StudentsView({super.key});

  @override
  State<StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<StudentsView> {
  String _query = '';
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final c = AppColors.of(context);
    return AsyncPage<_StudentsData>(
      load: () async {
        final (students, classes) = await (svc.academics.students(), svc.academics.classes()).wait;
        return _StudentsData(students, classes);
      },
      builder: (ctx, d, reload) {
        final labels = {for (final k in d.classes) k.id: k.label};
        final rows = d.students.where((s) {
          if (_classId != null && s.classId != _classId) return false;
          if (_query.isEmpty) return true;
          return s.fullName.toLowerCase().contains(_query) || s.username.toLowerCase().contains(_query) || s.rollNumber == _query;
        }).toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
        final klass = d.classes.where((k) => k.id == _classId).firstOrNull;
        return PageList(children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            style: c.body,
            decoration: InputDecoration(
              hintText: 'Search name, username or roll',
              prefixIcon: Icon(Icons.search_rounded, color: c.muted),
              filled: true,
              fillColor: c.inset,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.edge)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.edge)),
              focusedBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: c.accent, width: 1.6)),
            ),
          ),
          const SizedBox(height: 12),
          PickerField(
            label: 'Class',
            value: klass?.label ?? 'All classes',
            onTap: () async {
              final v =
                  await pickOne<SchoolClass>(ctx, title: 'Filter by class', options: d.classes, labelOf: (k) => k.label, selected: klass);
              if (v != null) setState(() => _classId = v.id);
            },
          ),
          if (_classId != null)
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(onPressed: () => setState(() => _classId = null), child: const Text('Show all classes'))),
          const SizedBox(height: 4),
          Text(plural(rows.length, 'student'), style: c.small),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            const EmptyState(icon: Icons.person_search_outlined, title: 'No students found', message: 'Try a different search or class.'),
          for (final s in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuCard(
                padding: const EdgeInsets.all(14),
                radius: 18,
                child: Row(children: [
                  Avatar(name: s.fullName, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.fullName, style: c.bodyStrong),
                      Text([labels[s.classId] ?? 'No class', if (s.rollNumber.isNotEmpty) 'Roll ${s.rollNumber}'].join(' \u00b7 '),
                          style: c.small),
                      if (s.guardianName.isNotEmpty || s.guardianContact.isNotEmpty)
                        Text('Guardian: ${[s.guardianName, s.guardianContact].where((e) => e.isNotEmpty).join(' \u00b7 ')}',
                            style: c.small),
                    ]),
                  ),
                  if (s.isAlumni) const Pill('Alumni', tone: 'warn'),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ================================================================= classes + subjects

class _ClassInfo {
  _ClassInfo(this.sessions, this.classes, this.subjects, this.years);
  final List<AcademicSession> sessions;
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final List<ClassYear> years;
}

/// Class and subject information for everyone; the Super Admin can also manage sessions, classes and subjects.
class ClassInfoView extends StatelessWidget {
  const ClassInfoView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_ClassInfo>(
      load: () async {
        final (sessions, classes, subjects, years) = await (
          svc.academics.sessions(),
          svc.academics.classes(),
          svc.academics.subjects(),
          me.isStudent ? svc.academics.myClassYears() : Future.value(<ClassYear>[]),
        ).wait;
        return _ClassInfo(sessions, classes, subjects, years);
      },
      builder: (ctx, d, reload) =>
          me.isStudent ? _StudentClassInfo(info: d) : _StaffClassInfo(info: d, reload: reload, canEdit: me.isSuperAdmin),
    );
  }
}

class _StudentClassInfo extends StatelessWidget {
  const _StudentClassInfo({required this.info});
  final _ClassInfo info;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final years = info.years;
    return PageList(children: [
      if (years.isEmpty)
        const EmptyState(
            icon: Icons.class_outlined,
            title: 'No class yet',
            message: 'You will see your class and subjects once the school assigns you to one.'),
      for (final y in years)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: NeuCard(
            depth: y.current ? 3 : 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(y.label, style: c.h1)),
                if (y.current) const Pill('Current', tone: 'good'),
              ]),
              const SizedBox(height: 2),
              Text('Session ${y.session}${y.outcome.isNotEmpty ? ' \u00b7 ${y.outcome}' : ''}', style: c.small),
              const SizedBox(height: 14),
              Text('SUBJECTS', style: c.eyebrow),
              const SizedBox(height: 8),
              Builder(builder: (_) {
                final subs = info.subjects.where((s) => s.classId == y.id).toList();
                if (subs.isEmpty) return Text('No subjects listed for this class yet.', style: c.small);
                return Wrap(spacing: 8, runSpacing: 8, children: [for (final s in subs) Pill(s.name)]);
              }),
            ]),
          ),
        ),
    ]);
  }
}

class _StaffClassInfo extends StatelessWidget {
  const _StaffClassInfo({required this.info, required this.reload, required this.canEdit});
  final _ClassInfo info;
  final Future<void> Function() reload;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final svc = context.svc;
    final sessions = [...info.sessions]..sort((a, b) {
        if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
        return b.label.compareTo(a.label);
      });

    Future<void> run(Future<void> Function() action, String ok) async {
      final done = await guard(context, action, success: ok);
      if (done) await reload();
    }

    return PageList(children: [
      if (canEdit)
        Row(children: [
          Expanded(
            child: NeuButton(
              label: 'New session',
              icon: Icons.add_rounded,
              secondary: true,
              compact: true,
              onPressed: () async {
                final saved = await showSheet<bool>(context, (_) => const _SessionForm());
                if (saved == true) {
                  if (context.mounted) toast(context, 'Session created.');
                  await reload();
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NeuButton(
              label: 'New class',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: info.sessions.isEmpty
                  ? null
                  : () async {
                      final saved = await showSheet<bool>(context, (_) => _ClassForm(sessions: info.sessions));
                      if (saved == true) {
                        if (context.mounted) toast(context, 'Class created.');
                        await reload();
                      }
                    },
            ),
          ),
        ]),
      if (info.sessions.isEmpty)
        const EmptyState(
            icon: Icons.class_outlined,
            title: 'No sessions yet',
            message: 'Create an academic session first, then add classes and subjects.'),
      for (final s in sessions) ...[
        SectionTitle('Session ${s.label}${s.isCurrent ? ' \u00b7 current' : ''}',
            trailing: canEdit
                ? PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, color: c.muted),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        final saved = await showSheet<bool>(context, (_) => _SessionForm(existing: s));
                        if (saved == true) {
                          if (context.mounted) toast(context, 'Session updated.');
                          await reload();
                        }
                      } else {
                        final yes = await confirm(context,
                            title: 'Delete session ${s.label}?',
                            message: 'This also removes its classes and everything attached to them. This cannot be undone.');
                        if (yes && context.mounted) await run(() => svc.academics.deleteSession(s.id), 'Session deleted.');
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit session')),
                      PopupMenuItem(value: 'delete', child: Text('Delete session'))
                    ],
                  )
                : null),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
              [
                if (s.startDate != null) 'Starts ${fmtDate(s.startDate)}',
                if (s.workingDays != null) '${s.workingDays} working days',
                'Minimum attendance ${s.minPercent}%'
              ].join(' \u00b7 '),
              style: c.small),
        ),
        for (final k in info.classes.where((k) => k.sessionId == s.id))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeuCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(k.label, style: c.h2)),
                  if (canEdit)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, color: c.muted),
                      onSelected: (v) async {
                        if (v == 'edit') {
                          final saved = await showSheet<bool>(context, (_) => _ClassForm(sessions: info.sessions, existing: k));
                          if (saved == true) {
                            if (context.mounted) toast(context, 'Class updated.');
                            await reload();
                          }
                        } else if (v == 'subject') {
                          final saved = await showSheet<bool>(context, (_) => _SubjectForm(classId: k.id, className: k.label));
                          if (saved == true) {
                            if (context.mounted) toast(context, 'Subject added.');
                            await reload();
                          }
                        } else {
                          final yes = await confirm(context,
                              title: 'Delete ${k.label}?',
                              message: 'Its subjects, timetable, homework, exams and attendance are removed too.');
                          if (yes && context.mounted) await run(() => svc.academics.deleteClass(k.id), 'Class deleted.');
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'subject', child: Text('Add subject')),
                        PopupMenuItem(value: 'edit', child: Text('Edit class')),
                        PopupMenuItem(value: 'delete', child: Text('Delete class'))
                      ],
                    ),
                ]),
                const SizedBox(height: 8),
                Builder(builder: (_) {
                  final subs = info.subjects.where((x) => x.classId == k.id).toList();
                  if (subs.isEmpty) return Text('No subjects yet.', style: c.small);
                  return Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final sub in subs)
                      canEdit
                          ? InputChip(
                              label: Text(sub.name),
                              backgroundColor: c.accentSoft,
                              side: BorderSide.none,
                              labelStyle: TextStyle(color: c.accent, fontWeight: FontWeight.w700, fontSize: 12.5),
                              deleteIconColor: c.accent,
                              onDeleted: () async {
                                final yes = await confirm(context,
                                    title: 'Delete ${sub.name}?', message: 'Marks, homework and exams for this subject are removed too.');
                                if (yes && context.mounted) await run(() => svc.academics.deleteSubject(sub.id), 'Subject deleted.');
                              },
                            )
                          : Pill(sub.name),
                  ]);
                }),
              ]),
            ),
          ),
        if (info.classes.where((k) => k.sessionId == s.id).isEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('No classes in this session yet.', style: c.small)),
      ],
    ]);
  }
}

class _SessionForm extends StatefulWidget {
  const _SessionForm({this.existing});
  final AcademicSession? existing;

  @override
  State<_SessionForm> createState() => _SessionFormState();
}

class _SessionFormState extends State<_SessionForm> {
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _days = TextEditingController(text: widget.existing?.workingDays?.toString() ?? '');
  late final _min = TextEditingController(text: '${widget.existing?.minPercent ?? 75}');
  late DateTime? _start = widget.existing?.startDate;
  late bool _current = widget.existing?.isCurrent ?? false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _days.dispose();
    _min.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Give the session a name, for example 2026-27.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.saveSession(
        id: widget.existing?.id,
        label: _label.text.trim(),
        isCurrent: _current,
        startDate: _start,
        workingDays: int.tryParse(_days.text.trim()),
        minPercent: int.tryParse(_min.text.trim()) ?? 75,
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
    final c = AppColors.of(context);
    return SheetBody(
      title: widget.existing == null ? 'New session' : 'Edit session',
      children: [
        AppField(controller: _label, label: 'Session name', hint: 'e.g. 2026-27', icon: Icons.event_note_rounded, maxLength: 20),
        const SizedBox(height: 14),
        PickerField(
          label: 'Start date (optional)',
          value: _start == null ? null : fmtDate(_start),
          placeholder: 'Not set',
          icon: Icons.calendar_month_rounded,
          onTap: () async {
            final d = await pickDate(context, initial: _start ?? DateTime.now());
            if (d != null) setState(() => _start = d);
          },
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: AppField(controller: _days, label: 'Working days', keyboard: TextInputType.number, maxLength: 3)),
          const SizedBox(width: 12),
          Expanded(child: AppField(controller: _min, label: 'Min. attendance %', keyboard: TextInputType.number, maxLength: 3)),
        ]),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _current,
            onChanged: (v) => setState(() => _current = v),
            title: Text('This is the current session', style: c.bodyStrong)),
        const SizedBox(height: 10),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Save session'),
      ],
    );
  }
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({required this.sessions, this.existing});
  final List<AcademicSession> sessions;
  final SchoolClass? existing;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _stream = TextEditingController(text: widget.existing?.stream);
  late String? _sessionId =
      widget.existing?.sessionId ?? (widget.sessions.where((s) => s.isCurrent).firstOrNull ?? widget.sessions.firstOrNull)?.id;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _stream.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _sessionId == null) {
      setState(() => _error = 'Enter the class name and choose a session.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics
          .saveClass(id: widget.existing?.id, name: _name.text.trim(), stream: _stream.text.trim(), sessionId: _sessionId!);
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
    final session = widget.sessions.where((s) => s.id == _sessionId).firstOrNull;
    return SheetBody(
      title: widget.existing == null ? 'New class' : 'Edit class',
      children: [
        PickerField(
          label: 'Session',
          value: session?.label,
          onTap: () async {
            final s = await pickOne<AcademicSession>(context,
                title: 'Session', options: widget.sessions, labelOf: (s) => s.label, selected: session);
            if (s != null) setState(() => _sessionId = s.id);
          },
        ),
        const SizedBox(height: 14),
        AppField(
            controller: _name,
            label: 'Class name',
            hint: 'e.g. Class XI',
            icon: Icons.class_outlined,
            maxLength: 50,
            capitalization: TextCapitalization.words),
        const SizedBox(height: 14),
        AppField(
            controller: _stream, label: 'Stream (optional)', hint: 'e.g. Science', maxLength: 50, capitalization: TextCapitalization.words),
        const SizedBox(height: 20),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Save class'),
      ],
    );
  }
}

class _SubjectForm extends StatefulWidget {
  const _SubjectForm({required this.classId, required this.className});
  final String classId;
  final String className;

  @override
  State<_SubjectForm> createState() => _SubjectFormState();
}

class _SubjectFormState extends State<_SubjectForm> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter the subject name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.saveSubject(name: _name.text.trim(), classId: widget.classId);
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
    return SheetBody(
      title: 'Add a subject',
      subtitle: widget.className,
      children: [
        AppField(
            controller: _name,
            label: 'Subject name',
            hint: 'e.g. Physics',
            icon: Icons.menu_book_outlined,
            maxLength: 100,
            capitalization: TextCapitalization.words),
        const SizedBox(height: 20),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Add subject'),
      ],
    );
  }
}
