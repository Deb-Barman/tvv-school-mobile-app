import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../data/models/content.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';
import '../../../core/clock.dart';

/// School notices. Everyone reads; only the Super Admin sees the add / edit / delete controls
/// (the server refuses everyone else anyway).
class NoticesView extends StatelessWidget {
  const NoticesView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final isAdmin = context.me.isSuperAdmin;
    return AsyncPage<List<Notice>>(
      load: svc.content.notices,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        return PageList(children: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: NeuButton(
                label: 'New notice',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final saved = await showSheet<bool>(ctx, (_) => const NoticeForm());
                  if (saved == true) {
                    if (ctx.mounted) toast(ctx, 'Notice published.');
                    await reload();
                  }
                },
              ),
            ),
          if (items.isEmpty)
            const EmptyState(
                icon: Icons.campaign_outlined, title: 'No notices yet', message: 'Announcements from the school will appear here.'),
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PostCard(
                title: n.createdByName.isNotEmpty ? n.createdByName : 'School office',
                subtitle: [fmtDate(n.createdAt), if (n.targetClass.isNotEmpty) n.targetClass].join(' \u00b7 '),
                trailing: isAdmin
                    ? PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded, color: c.text),
                        color: c.surface,
                        surfaceTintColor: Colors.transparent,
                        onSelected: (v) async {
                          if (v == 'edit') {
                            final saved = await showSheet<bool>(ctx, (_) => NoticeForm(existing: n));
                            if (saved == true) {
                              if (ctx.mounted) toast(ctx, 'Notice updated.');
                              await reload();
                            }
                          } else if (v == 'delete') {
                            final yes = await confirm(ctx,
                                title: 'Delete this notice?', message: '\u201c${n.title}\u201d will be removed for everyone.');
                            if (!yes || !ctx.mounted) return;
                            final ok = await guard(ctx, () => svc.content.deleteNotice(n.id), success: 'Notice deleted.');
                            if (ok) await reload();
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      )
                    : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: c.h2),
                  const SizedBox(height: 6),
                  Text(n.body, style: c.body),
                ]),
              ),
            ),
        ]);
      },
    );
  }
}

class NoticeForm extends StatefulWidget {
  const NoticeForm({super.key, this.existing});
  final Notice? existing;

  @override
  State<NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends State<NoticeForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late final _target = TextEditingController(text: widget.existing?.targetClass);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.content
          .saveNotice(id: widget.existing?.id, title: _title.text.trim(), body: _body.text.trim(), targetClass: _target.text.trim());
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
      title: widget.existing == null ? 'New notice' : 'Edit notice',
      children: [
        Form(
          key: _key,
          child: Column(children: [
            AppField(
                controller: _title,
                label: 'Title',
                icon: Icons.title_rounded,
                maxLength: 200,
                capitalization: TextCapitalization.sentences,
                validator: (v) => requiredField(v, 'Title')),
            const SizedBox(height: 14),
            AppField(
                controller: _body,
                label: 'Notice',
                maxLines: 6,
                capitalization: TextCapitalization.sentences,
                validator: (v) => requiredField(v, 'The notice')),
            const SizedBox(height: 14),
            AppField(
                controller: _target,
                label: 'For (optional label)',
                hint: 'e.g. Class XI Science',
                icon: Icons.groups_outlined,
                maxLength: 50),
            const SizedBox(height: 20),
            SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: widget.existing == null ? 'Publish' : 'Save changes'),
          ]),
        ),
      ],
    );
  }
}

// ================================================================= events

class EventsView extends StatelessWidget {
  const EventsView({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final isAdmin = context.me.isSuperAdmin;
    return AsyncPage<List<SchoolEvent>>(
      load: svc.content.events,
      builder: (ctx, items, reload) {
        final c = AppColors.of(ctx);
        final today = dayOnly(schoolNow());
        final upcoming = items.where((e) => e.date != null && !e.date!.isBefore(today)).toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
        final past = items.where((e) => e.date == null || e.date!.isBefore(today)).toList()
          ..sort((a, b) => (b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));

        Widget row(SchoolEvent e, {bool dim = false}) {
          final d = e.date;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: NeuCard(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: dim ? c.inset : c.accentSoft, borderRadius: BorderRadius.circular(14)),
                  child: Column(children: [
                    Text(d == null ? '\u2014' : '${d.day}',
                        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: dim ? c.muted : c.accent)),
                    Text(d == null ? '' : monthShort(d.month).toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dim ? c.muted : c.accent)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.title, style: c.h2),
                    if (e.description.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.description, style: c.body)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      if (!dim) Pill(relativeDay(d), tone: 'good'),
                      if (e.audience.isNotEmpty) Pill(e.audience),
                      Text(fmtDate(d), style: c.small),
                    ]),
                  ]),
                ),
                if (isAdmin)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: c.muted),
                    onSelected: (v) async {
                      if (v == 'edit') {
                        final saved = await showSheet<bool>(ctx, (_) => EventForm(existing: e));
                        if (saved == true) {
                          if (ctx.mounted) toast(ctx, 'Event updated.');
                          await reload();
                        }
                      } else if (v == 'delete') {
                        final yes = await confirm(ctx, title: 'Delete this event?', message: '\u201c${e.title}\u201d will be removed.');
                        if (!yes || !ctx.mounted) return;
                        final ok = await guard(ctx, () => svc.content.deleteEvent(e.id), success: 'Event deleted.');
                        if (ok) await reload();
                      }
                    },
                    itemBuilder: (_) =>
                        const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                  ),
              ]),
            ),
          );
        }

        return PageList(children: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: NeuButton(
                label: 'New event',
                icon: Icons.add_rounded,
                onPressed: () async {
                  final saved = await showSheet<bool>(ctx, (_) => const EventForm());
                  if (saved == true) {
                    if (ctx.mounted) toast(ctx, 'Event added.');
                    await reload();
                  }
                },
              ),
            ),
          if (items.isEmpty)
            const EmptyState(icon: Icons.event_outlined, title: 'No events yet', message: 'Upcoming school events will appear here.'),
          if (upcoming.isNotEmpty) const SectionTitle('Upcoming'),
          for (final e in upcoming) row(e),
          if (past.isNotEmpty) const SectionTitle('Past events'),
          for (final e in past) row(e, dim: true),
        ]);
      },
    );
  }
}

class EventForm extends StatefulWidget {
  const EventForm({super.key, this.existing});
  final SchoolEvent? existing;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _audience = TextEditingController(text: widget.existing?.audience);
  late DateTime _date = widget.existing?.date ?? schoolNow();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _audience.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.content.saveEvent(
          id: widget.existing?.id, title: _title.text.trim(), description: _desc.text.trim(), date: _date, audience: _audience.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetBody(
      title: widget.existing == null ? 'New event' : 'Edit event',
      children: [
        Form(
          key: _key,
          child: Column(children: [
            AppField(
                controller: _title,
                label: 'Event name',
                icon: Icons.event_rounded,
                maxLength: 200,
                capitalization: TextCapitalization.sentences,
                validator: (v) => requiredField(v, 'Event name')),
            const SizedBox(height: 14),
            PickerField(
              label: 'Date',
              value: fmtDate(_date),
              icon: Icons.calendar_month_rounded,
              onTap: () async {
                final d = await pickDate(context,
                    initial: _date, first: DateTime(schoolNow().year - 1), last: DateTime(schoolNow().year + 3, 12, 31));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 14),
            AppField(controller: _desc, label: 'Details (optional)', maxLines: 4, capitalization: TextCapitalization.sentences),
            const SizedBox(height: 14),
            AppField(
                controller: _audience, label: 'For (optional)', hint: 'e.g. All students', icon: Icons.groups_outlined, maxLength: 100),
            const SizedBox(height: 20),
            SaveBar(
                onSave: _busy ? null : _save, busy: _busy, error: _error, label: widget.existing == null ? 'Add event' : 'Save changes'),
          ]),
        ),
      ],
    );
  }
}
