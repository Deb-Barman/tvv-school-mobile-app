import 'package:flutter/material.dart';

import '../../../data/models/content.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

class _InboxData {
  _InboxData(this.admissions, this.messages);
  final List<Admission> admissions;
  final List<ContactMessage> messages;
}

/// Super Admin: admission enquiries and contact-form messages from the website.
class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  String _tab = 'admissions';

  String _statusLabel(String s) => '${s[0]}${s.substring(1).toLowerCase()}';
  String _tone(String s) => (s == 'PENDING' || s == 'NEW') ? 'warn' : ((s == 'CONTACTED' || s == 'READ') ? 'accent' : 'good');

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return AsyncPage<_InboxData>(
      load: () async {
        final (a, m) = await (svc.content.admissions(), svc.content.messages()).wait;
        return _InboxData(a, m);
      },
      builder: (ctx, d, reload) {
        final c = AppColors.of(ctx);
        final pendingA = d.admissions.where((a) => a.status == 'PENDING').length;
        final newM = d.messages.where((m) => m.status == 'NEW').length;
        return PageList(children: [
          ChipBar<String>(
            padding: const EdgeInsets.only(bottom: 12),
            items: const ['admissions', 'messages'],
            selected: _tab,
            labelOf: (t) =>
                t == 'admissions' ? 'Admissions${pendingA > 0 ? ' ($pendingA new)' : ''}' : 'Messages${newM > 0 ? ' ($newM new)' : ''}',
            onChanged: (t) => setState(() => _tab = t),
          ),
          if (_tab == 'admissions') ...[
            if (d.admissions.isEmpty)
              const EmptyState(
                  icon: Icons.how_to_reg_outlined,
                  title: 'No admission enquiries',
                  message: 'Applications sent from the website will appear here.'),
            for (final a in d.admissions)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeuCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(a.applicantName, style: c.h2)),
                      Pill(_statusLabel(a.status), tone: _tone(a.status)),
                    ]),
                    const SizedBox(height: 6),
                    InfoRow('Applying for', a.applyingForClass),
                    InfoRow('Guardian', a.guardianContact),
                    if (a.message.isNotEmpty) InfoRow('Message', a.message),
                    Text('Received ${fmtDateTime(a.submittedAt)}', style: c.small),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: NeuButton(
                          label: _statusLabel(a.status),
                          icon: Icons.swap_horiz_rounded,
                          compact: true,
                          secondary: true,
                          onPressed: () async {
                            final s = await pickOne<String>(ctx,
                                title: 'Mark as', options: Admission.statuses, labelOf: _statusLabel, selected: a.status);
                            if (s == null || s == a.status || !ctx.mounted) return;
                            final ok = await guard(ctx, () => svc.content.setAdmissionStatus(a.id, s),
                                success: 'Marked as ${_statusLabel(s).toLowerCase()}.');
                            if (ok) await reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      NeuIconButton(
                        icon: Icons.delete_outline_rounded,
                        color: c.bad,
                        tooltip: 'Delete',
                        onPressed: () async {
                          final yes = await confirm(ctx,
                              title: 'Delete this enquiry?', message: 'The application from ${a.applicantName} will be removed.');
                          if (!yes || !ctx.mounted) return;
                          final ok = await guard(ctx, () => svc.content.deleteAdmission(a.id), success: 'Enquiry deleted.');
                          if (ok) await reload();
                        },
                      ),
                    ]),
                  ]),
                ),
              ),
          ] else ...[
            if (d.messages.isEmpty)
              const EmptyState(
                  icon: Icons.mail_outline_rounded,
                  title: 'No messages',
                  message: 'Messages from the website contact form will appear here.'),
            for (final m in d.messages)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeuCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(m.subject, style: c.h2)),
                      Pill(_statusLabel(m.status), tone: _tone(m.status)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${m.name}${m.email.isEmpty ? '' : ' \u00b7 ${m.email}'}${m.phone.isEmpty ? '' : ' \u00b7 ${m.phone}'}',
                        style: c.small),
                    const SizedBox(height: 8),
                    Text(m.message, style: c.body),
                    const SizedBox(height: 8),
                    Text(fmtDateTime(m.createdAt), style: c.small),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: NeuButton(
                          label: _statusLabel(m.status),
                          icon: Icons.swap_horiz_rounded,
                          compact: true,
                          secondary: true,
                          onPressed: () async {
                            final s = await pickOne<String>(ctx,
                                title: 'Mark as', options: ContactMessage.statuses, labelOf: _statusLabel, selected: m.status);
                            if (s == null || s == m.status || !ctx.mounted) return;
                            final ok = await guard(ctx, () => svc.content.setMessageStatus(m.id, s),
                                success: 'Marked as ${_statusLabel(s).toLowerCase()}.');
                            if (ok) await reload();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      NeuIconButton(
                        icon: Icons.delete_outline_rounded,
                        color: c.bad,
                        tooltip: 'Delete',
                        onPressed: () async {
                          final yes = await confirm(ctx, title: 'Delete this message?', message: 'It will be removed permanently.');
                          if (!yes || !ctx.mounted) return;
                          final ok = await guard(ctx, () => svc.content.deleteMessage(m.id), success: 'Message deleted.');
                          if (ok) await reload();
                        },
                      ),
                    ]),
                  ]),
                ),
              ),
          ],
        ]);
      },
    );
  }
}
