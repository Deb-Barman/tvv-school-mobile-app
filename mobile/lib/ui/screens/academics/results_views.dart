import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../data/attendance_stats.dart';
import '../../../data/models/academics.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

class _ResultsData {
  _ResultsData(this.groups, this.subjects, this.sessions);
  final List<ResultGroup> groups;
  final Map<String, String> subjects;
  final Map<String, String> sessions;
}

/// A student's examination results, grouped by session and term, with totals.
class ResultsView extends StatelessWidget {
  const ResultsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<_ResultsData>(
      load: () async {
        final (rows, subjects, sessions) = await (svc.academics.results(), svc.academics.subjects(), svc.academics.sessions()).wait;
        return _ResultsData(ResultGroup.group(rows, sessions: sessions), {for (final s in subjects) s.id: s.name},
            {for (final s in sessions) s.id: s.label});
      },
      builder: (ctx, d, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (d.groups.isEmpty)
            const EmptyState(
                icon: Icons.emoji_events_outlined,
                title: 'No results yet',
                message: 'Your marks will appear here once your teachers publish them.'),
          for (final g in d.groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: NeuCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${d.sessions[g.sessionId] ?? 'Session'} \u00b7 ${g.termLabel}'.toUpperCase(), style: c.eyebrow),
                  const SizedBox(height: 12),
                  for (final r in g.rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(d.subjects[r.subjectId] ?? 'Subject', style: c.bodyStrong)),
                          Text('${marks(r.marks)} / ${marks(r.fullMarks)}', style: c.bodyStrong),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                              value: (r.percent / 100).clamp(0, 1).toDouble(),
                              minHeight: 7,
                              backgroundColor: c.inset,
                              color: r.percent >= 60 ? c.good : (r.percent >= 40 ? c.warn : c.bad)),
                        ),
                      ]),
                    ),
                  Divider(color: c.edge),
                  Row(children: [
                    Expanded(child: Text('Total', style: c.h2)),
                    Text('${marks(g.total)} / ${marks(g.fullTotal)}', style: c.h2),
                    const SizedBox(width: 10),
                    Pill(pct(g.percent, 1), tone: g.percent >= 60 ? 'good' : (g.percent >= 40 ? 'warn' : 'bad')),
                  ]),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

// ================================================================= staff: enter marks

class _EntryBase {
  _EntryBase(this.classes, this.subjects, this.sessions);
  final List<SchoolClass> classes;
  final List<Subject> subjects;
  final List<AcademicSession> sessions;
}

/// Enter or correct marks for one class, subject and term. Saved in one go; the server rejects marks above full marks.
class ResultsEntryView extends StatelessWidget {
  const ResultsEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<_EntryBase>(
      refreshable: false, // the body below has its own AsyncPage
      skeleton: const ListSkeleton(count: 4),
      load: () async {
        final (classes, subjects, sessions) = await (svc.academics.classes(), svc.academics.subjects(), svc.academics.sessions()).wait;
        return _EntryBase(classes, subjects, sessions);
      },
      builder: (ctx, base, reload) => _EntryBody(base: base),
    );
  }
}

class _EntryBody extends StatefulWidget {
  const _EntryBody({required this.base});
  final _EntryBase base;

  @override
  State<_EntryBody> createState() => _EntryBodyState();
}

class _EntryBodyState extends State<_EntryBody> {
  String? _classId;
  String? _subjectId;
  String? _sessionId;
  String _term = 'SEM1';
  final _full = TextEditingController(text: '100');
  int _version = 0;

  @override
  void initState() {
    super.initState();
    final cur = widget.base.sessions.where((s) => s.isCurrent).firstOrNull ?? widget.base.sessions.firstOrNull;
    _sessionId = cur?.id;
    final classesInSession = widget.base.classes.where((k) => k.sessionId == _sessionId).toList();
    if (classesInSession.isNotEmpty) _classId = classesInSession.first.id;
  }

  @override
  void dispose() {
    _full.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.base;
    final svc = context.svc;
    final klass = b.classes.where((k) => k.id == _classId).firstOrNull;
    final subject = b.subjects.where((s) => s.id == _subjectId).firstOrNull;
    final session = b.sessions.where((s) => s.id == _sessionId).firstOrNull;
    final ready = _classId != null && _subjectId != null && _sessionId != null;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(children: [
          Row(children: [
            Expanded(
              child: PickerField(
                label: 'Class',
                value: klass?.label,
                onTap: () async {
                  final k =
                      await pickOne<SchoolClass>(context, title: 'Class', options: b.classes, labelOf: (k) => k.label, selected: klass);
                  if (k != null) {
                    setState(() {
                      _classId = k.id;
                      _sessionId = k.sessionId;
                      _subjectId = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PickerField(
                label: 'Subject',
                value: subject?.name,
                onTap: _classId == null
                    ? null
                    : () async {
                        final s = await pickOne<Subject>(context,
                            title: 'Subject',
                            options: b.subjects.where((s) => s.classId == _classId).toList(),
                            labelOf: (s) => s.name,
                            selected: subject);
                        if (s != null) setState(() => _subjectId = s.id);
                      },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              flex: 3,
              child: PickerField(
                label: 'Term',
                value: termLabels[_term],
                onTap: () async {
                  final t = await pickOne<String>(context,
                      title: 'Term', options: termOrder, labelOf: (t) => termLabels[t] ?? t, selected: _term);
                  if (t != null) setState(() => _term = t);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: AppField(
                  controller: _full,
                  label: 'Full marks',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  maxLength: 6,
                  onSubmitted: (_) => setState(() => _version++)),
            ),
          ]),
          if (session != null)
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(padding: const EdgeInsets.only(top: 6), child: Text('Session ${session.label}', style: c(context).small))),
        ]),
      ),
      Expanded(
        child: !ready
            ? const EmptyState(
                icon: Icons.edit_note_rounded, title: 'Choose a class and subject', message: 'Then type the marks for each student.')
            : AsyncPage<({List<StudentProfile> students, List<ResultRow> existing})>(
                key: ValueKey('$_classId|$_subjectId|$_sessionId|$_term|$_version'),
                skeleton: const ListSkeleton(count: 7),
                load: () async {
                  final (students, existing) = await (
                    svc.academics.students(classId: _classId),
                    svc.academics.results(subjectId: _subjectId, sessionId: _sessionId, term: _term)
                  ).wait;
                  return (students: students, existing: existing);
                },
                builder: (ctx, d, reload) {
                  final sorted = [...d.students]
                    ..sort((a, b) => (int.tryParse(a.rollNumber) ?? 9999).compareTo(int.tryParse(b.rollNumber) ?? 9999));
                  return _MarksGrid(
                    key: ValueKey('${_classId}_${_subjectId}_${_term}_${d.existing.length}'),
                    students: sorted,
                    existing: {for (final r in d.existing) r.studentId: r.marks},
                    fullMarksText: _full,
                    onSave: (map, full) async {
                      final n = await svc.academics
                          .saveResults(subjectId: _subjectId!, sessionId: _sessionId!, term: _term, fullMarks: full, marks: map);
                      await reload();
                      return n;
                    },
                  );
                },
              ),
      ),
    ]);
  }

  AppColors c(BuildContext context) => AppColors.of(context);
}

class _MarksGrid extends StatefulWidget {
  const _MarksGrid({super.key, required this.students, required this.existing, required this.fullMarksText, required this.onSave});
  final List<StudentProfile> students;
  final Map<String, double> existing;
  final TextEditingController fullMarksText;
  final Future<int> Function(Map<String, double> marks, double full) onSave;

  @override
  State<_MarksGrid> createState() => _MarksGridState();
}

class _MarksGridState extends State<_MarksGrid> {
  late final Map<String, TextEditingController> _ctl = {
    for (final s in widget.students)
      s.userId: TextEditingController(text: widget.existing[s.userId] == null ? '' : marks(widget.existing[s.userId]!))
  };
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final full = double.tryParse(widget.fullMarksText.text.trim());
    if (full == null || full <= 0) {
      setState(() => _error = 'Enter the full marks first (for example 100).');
      return;
    }
    final out = <String, double>{};
    for (final s in widget.students) {
      final t = _ctl[s.userId]!.text.trim();
      if (t.isEmpty) continue;
      final v = double.tryParse(t);
      if (v == null || v < 0) {
        setState(() => _error = 'Marks for ${s.fullName} must be a number.');
        return;
      }
      if (v > full) {
        setState(() => _error = 'Marks for ${s.fullName} are above the full marks ($full).');
        return;
      }
      out[s.userId] = v;
    }
    if (out.isEmpty) {
      setState(() => _error = 'Enter marks for at least one student.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await widget.onSave(out, full);
      if (mounted) toast(context, 'Marks saved for $n students.');
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
    if (widget.students.isEmpty)
      return const EmptyState(
          icon: Icons.groups_outlined, title: 'No students in this class', message: 'Students appear once the Super Admin adds them.');
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
          for (final s in widget.students)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeuCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                radius: 16,
                child: Row(children: [
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.fullName, style: c.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (s.rollNumber.isNotEmpty) Text('Roll ${s.rollNumber}', style: c.small)
                  ])),
                  SizedBox(
                    width: 92,
                    child: TextField(
                      controller: _ctl[s.userId],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      style: c.bodyStrong,
                      decoration: InputDecoration(
                        hintText: 'Marks',
                        isDense: true,
                        filled: true,
                        fillColor: c.inset,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.edge)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.edge)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.accent, width: 1.6)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Save marks')),
    ]);
  }
}

// ================================================================= marksheets

class _SheetData {
  _SheetData(this.sheets, this.sessions, this.students);
  final List<Marksheet> sheets;
  final Map<String, String> sessions;
  final List<StudentProfile> students;
}

class MarksheetsView extends StatelessWidget {
  const MarksheetsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final me = context.me;
    return AsyncPage<_SheetData>(
      load: () async {
        final (sheets, sessions, students) = await (
          svc.academics.marksheets(),
          svc.academics.sessions(),
          me.isStudent ? Future.value(<StudentProfile>[]) : svc.academics.students()
        ).wait;
        return _SheetData(sheets, {for (final s in sessions) s.id: s.label}, students);
      },
      builder: (ctx, d, reload) {
        final c = AppColors.of(ctx);
        final names = {for (final s in d.students) s.userId: s.fullName};
        return PageList(children: [
          if (me.isSuperAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NeuButton(
                label: 'Attach a marksheet',
                icon: Icons.add_link_rounded,
                onPressed: () async {
                  final sessions = d.sessions.entries.toList();
                  final saved = await showSheet<bool>(ctx, (_) => _MarksheetForm(students: d.students, sessions: sessions));
                  if (saved == true) {
                    if (ctx.mounted) toast(ctx, 'Marksheet attached.');
                    await reload();
                  }
                },
              ),
            ),
          if (d.sheets.isEmpty)
            const EmptyState(
                icon: Icons.description_outlined,
                title: 'No marksheets yet',
                message: 'Your marksheets will appear here when the school issues them.'),
          for (final m in d.sheets)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                onTap: () => openLink(ctx, m.url),
                child: Row(children: [
                  Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.description_rounded, color: c.accent)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Marksheet \u00b7 ${d.sessions[m.sessionId] ?? 'Session'}', style: c.bodyStrong),
                      if (!me.isStudent) Text(names[m.studentId] ?? 'Student', style: c.small),
                      if (m.generatedAt != null) Text('Issued ${fmtDate(m.generatedAt)}', style: c.small),
                    ]),
                  ),
                  if (me.isSuperAdmin)
                    IconButton(
                      tooltip: 'Delete',
                      icon: Icon(Icons.delete_outline_rounded, color: c.bad),
                      onPressed: () async {
                        final yes = await confirm(ctx, title: 'Delete this marksheet?', message: 'The student will no longer see it.');
                        if (!yes || !ctx.mounted) return;
                        final ok = await guard(ctx, () => ctx.svc.academics.deleteMarksheet(m.id), success: 'Marksheet deleted.');
                        if (ok) await reload();
                      },
                    )
                  else
                    Icon(Icons.open_in_new_rounded, color: c.muted, size: 20),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class _MarksheetForm extends StatefulWidget {
  const _MarksheetForm({required this.students, required this.sessions});
  final List<StudentProfile> students;
  final List<MapEntry<String, String>> sessions;

  @override
  State<_MarksheetForm> createState() => _MarksheetFormState();
}

class _MarksheetFormState extends State<_MarksheetForm> {
  final _link = TextEditingController();
  String? _studentId;
  String? _sessionId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_studentId == null || _sessionId == null || _link.text.trim().isEmpty) {
      setState(() => _error = 'Choose the student, the session and paste the link.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.createMarksheet(studentId: _studentId!, sessionId: _sessionId!, link: _link.text.trim());
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
    final st = widget.students.where((s) => s.userId == _studentId).firstOrNull;
    final se = widget.sessions.where((s) => s.key == _sessionId).firstOrNull;
    return SheetBody(
      title: 'Attach a marksheet',
      subtitle: 'Paste a share link (Google Drive, etc.). Make sure the link can be opened by whoever needs it.',
      children: [
        PickerField(
          label: 'Student',
          value: st?.fullName,
          onTap: () async {
            final s = await pickOne<StudentProfile>(context,
                title: 'Student',
                options: widget.students,
                labelOf: (s) => s.fullName,
                subtitleOf: (s) => s.rollNumber.isEmpty ? s.username : 'Roll ${s.rollNumber} \u00b7 ${s.username}',
                selected: st);
            if (s != null) setState(() => _studentId = s.userId);
          },
        ),
        const SizedBox(height: 14),
        PickerField(
          label: 'Session',
          value: se?.value,
          onTap: () async {
            final s = await pickOne<MapEntry<String, String>>(context,
                title: 'Session', options: widget.sessions, labelOf: (s) => s.value, selected: se);
            if (s != null) setState(() => _sessionId = s.key);
          },
        ),
        const SizedBox(height: 14),
        AppField(controller: _link, label: 'Marksheet link', icon: Icons.link_rounded, keyboard: TextInputType.url, maxLines: 2),
        const SizedBox(height: 20),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Attach'),
      ],
    );
  }
}
