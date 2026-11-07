import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_exception.dart';
import '../../../data/models/academics.dart';
import '../../../data/models/user.dart';
import '../../../state/app_scope.dart';
import '../../format.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/neu.dart';
import '../../widgets/states.dart';

/// A random password that is easy to read out loud (no look-alike characters).
String generatePassword([int length = 12]) {
  const letters = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ';
  const digits = '23456789';
  const symbols = '@#%+=!';
  final r = Random.secure();
  String pick(String s) => s[r.nextInt(s.length)];
  final chars = <String>[pick(letters.toUpperCase()), pick(letters.toLowerCase()), pick(digits), pick(digits), pick(symbols)];
  while (chars.length < length) {
    chars.add(pick(letters + digits));
  }
  chars.shuffle(r);
  return chars.join();
}

class _AccountsData {
  _AccountsData(this.users, this.requests);
  final List<AdminUser> users;
  final List<({ResetRequest request, String? userId})> requests;
}

/// Super Admin: all Teacher and Student accounts.
class AccountsView extends StatefulWidget {
  const AccountsView({super.key});

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  String _tab = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final c = AppColors.of(context);
    return AsyncPage<_AccountsData>(
      load: () async {
        final (users, requests) = await (svc.admin.users(), svc.admin.resetRequests()).wait;
        return _AccountsData(users, requests);
      },
      builder: (ctx, d, reload) {
        final rows = d.users.where((u) {
          if (_tab == 'students' && u.role != Role.student) return false;
          if (_tab == 'teachers' && u.role != Role.teacher) return false;
          if (_query.isEmpty) return true;
          return u.fullName.toLowerCase().contains(_query) || u.username.toLowerCase().contains(_query);
        }).toList()
          ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));

        return PageList(children: [
          NeuButton(
            label: 'New account',
            icon: Icons.person_add_alt_1_rounded,
            onPressed: () async {
              final saved = await showSheet<bool>(ctx, (_) => const _CreateAccountForm());
              if (saved == true) {
                if (ctx.mounted) toast(ctx, 'Account created.');
                await reload();
              }
            },
          ),
          ChipBar<String>(
            padding: const EdgeInsets.symmetric(vertical: 12),
            items: const ['all', 'students', 'teachers', 'requests'],
            selected: _tab,
            labelOf: (t) => {
              'all': 'All (${d.users.length})',
              'students': 'Students',
              'teachers': 'Teachers',
              'requests': 'Password requests${d.requests.isEmpty ? '' : ' (${d.requests.length})'}'
            }[t]!,
            onChanged: (t) => setState(() => _tab = t),
          ),
          if (_tab != 'requests') ...[
            TextField(
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: c.body,
              decoration: InputDecoration(
                hintText: 'Search name or username',
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
            if (rows.isEmpty) const EmptyState(icon: Icons.person_search_outlined, title: 'No accounts found'),
            for (final u in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: NeuCard(
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  onTap: () async {
                    final changed = await showSheet<bool>(ctx, (_) => _AccountSheet(user: u));
                    if (changed == true) await reload();
                  },
                  child: Row(children: [
                    Avatar(name: u.fullName, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u.fullName, style: c.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('@${u.username}', style: c.small),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          Pill(u.role.label, tone: u.role == Role.teacher ? 'warn' : 'accent'),
                          if (!u.isActive) const Pill('Disabled', tone: 'bad'),
                          if (u.isLocked) const Pill('Locked', tone: 'bad', icon: Icons.lock_rounded),
                        ]),
                      ]),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.muted),
                  ]),
                ),
              ),
          ] else ...[
            if (d.requests.isEmpty)
              const EmptyState(
                  icon: Icons.mark_email_read_outlined,
                  title: 'No password requests',
                  message: 'When someone taps \u201cForgot password\u201d on the sign-in screen, they will appear here.'),
            for (final r in d.requests)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: NeuCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(r.request.fullName.isEmpty ? r.request.username : r.request.fullName, style: c.h2)),
                      Pill(r.request.known ? 'Known account' : 'Unknown username', tone: r.request.known ? 'good' : 'warn'),
                    ]),
                    Text(
                        '@${r.request.username}${r.request.roleLabel.isEmpty ? '' : ' \u00b7 ${r.request.roleLabel}'} \u00b7 ${fmtDateTime(r.request.createdAt)}',
                        style: c.small),
                    if (r.request.note.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('\u201c${r.request.note}\u201d', style: c.body.copyWith(fontStyle: FontStyle.italic))),
                    const SizedBox(height: 12),
                    Row(children: [
                      if (r.userId != null)
                        Expanded(
                          child: NeuButton(
                            label: 'Set new password',
                            icon: Icons.key_rounded,
                            compact: true,
                            onPressed: () async {
                              final id = r.userId!;
                              final done = await showSheet<bool>(
                                  ctx,
                                  (_) => _ResetPasswordForm(
                                      userId: id, name: r.request.fullName.isEmpty ? r.request.username : r.request.fullName));
                              if (done == true) {
                                if (ctx.mounted) await guard(ctx, () => svc.admin.dismissResetRequest(r.request.id));
                                await reload();
                              }
                            },
                          ),
                        ),
                      if (r.userId != null) const SizedBox(width: 10),
                      Expanded(
                        child: NeuButton(
                          label: 'Dismiss',
                          secondary: true,
                          compact: true,
                          onPressed: () async {
                            final ok = await guard(ctx, () => svc.admin.dismissResetRequest(r.request.id), success: 'Request dismissed.');
                            if (ok) await reload();
                          },
                        ),
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

// ------------------------------------------------------------------ create

class _CreateAccountForm extends StatefulWidget {
  const _CreateAccountForm();

  @override
  State<_CreateAccountForm> createState() => _CreateAccountFormState();
}

class _CreateAccountFormState extends State<_CreateAccountForm> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController(text: generatePassword());
  final _phone = TextEditingController();
  final _email = TextEditingController();
  Role _role = Role.student;
  bool _show = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _username, _password, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.admin.createUser(
          username: _username.text, password: _password.text, fullName: _name.text, role: _role, phone: _phone.text, email: _email.text);
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
      title: 'New account',
      subtitle: 'Share the username and password with the person. They can change the password after signing in.',
      children: [
        Form(
          key: _key,
          child: Column(children: [
            ChipBar<Role>(
                items: const [Role.student, Role.teacher],
                selected: _role,
                labelOf: (r) => r.label,
                onChanged: (r) => setState(() => _role = r),
                padding: EdgeInsets.zero),
            const SizedBox(height: 14),
            AppField(
                controller: _name,
                label: 'Full name',
                icon: Icons.person_outline_rounded,
                capitalization: TextCapitalization.words,
                maxLength: 150,
                validator: (v) => requiredField(v, 'Full name')),
            const SizedBox(height: 14),
            AppField(
                controller: _username,
                label: 'Username',
                icon: Icons.alternate_email_rounded,
                maxLength: 150,
                validator: (v) => requiredField(v, 'Username')),
            const SizedBox(height: 14),
            AppField(
              controller: _password,
              label: 'Password',
              icon: Icons.key_rounded,
              obscure: !_show,
              maxLength: 128,
              validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
              suffix: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                    tooltip: _show ? 'Hide' : 'Show',
                    icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted),
                    onPressed: () => setState(() => _show = !_show)),
                IconButton(
                    tooltip: 'Generate a new one',
                    icon: Icon(Icons.autorenew_rounded, color: c.accent),
                    onPressed: () => setState(() => _password.text = generatePassword())),
              ]),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _password.text));
                  if (context.mounted) toast(context, 'Password copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy password'),
              ),
            ),
            const SizedBox(height: 6),
            AppField(
                controller: _phone, label: 'Phone (optional)', icon: Icons.phone_outlined, keyboard: TextInputType.phone, maxLength: 20),
            const SizedBox(height: 14),
            AppField(
                controller: _email,
                label: 'E-mail (optional)',
                icon: Icons.mail_outline_rounded,
                keyboard: TextInputType.emailAddress,
                maxLength: 150),
            const SizedBox(height: 20),
            SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Create account'),
          ]),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ manage one account

class _AccountSheet extends StatefulWidget {
  const _AccountSheet({required this.user});
  final AdminUser user;

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  late AdminUser _u = widget.user;
  bool _changed = false;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String ok) async {
    setState(() => _busy = true);
    final done = await guard(context, action, success: ok);
    if (mounted) setState(() => _busy = false);
    if (done) _changed = true;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final svc = context.svc;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: SheetBody(
        title: _u.fullName,
        subtitle: '@${_u.username} \u00b7 ${_u.role.label}',
        children: [
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pill(_u.isActive ? 'Active' : 'Disabled', tone: _u.isActive ? 'good' : 'bad'),
            if (_u.isLocked) const Pill('Locked after failed sign-ins', tone: 'bad', icon: Icons.lock_rounded),
            if (_u.failedAttempts > 0) Pill('${_u.failedAttempts} failed sign-ins', tone: 'warn'),
          ]),
          const SizedBox(height: 10),
          InfoRow('Phone', _u.phone, icon: Icons.phone_outlined),
          InfoRow('E-mail', _u.email, icon: Icons.mail_outline_rounded),
          InfoRow('Last sign-in', _u.lastLogin == null ? 'Never' : fmtDateTime(_u.lastLogin), icon: Icons.history_rounded),
          const SizedBox(height: 14),
          if (_u.role == Role.student) ...[
            NeuButton(
              label: 'Class & roll number',
              icon: Icons.class_outlined,
              secondary: true,
              onPressed: _busy
                  ? null
                  : () async {
                      final done = await showSheet<bool>(context, (_) => _StudentPlacementForm(userId: _u.id, name: _u.fullName));
                      if (done == true) {
                        _changed = true;
                        if (context.mounted) toast(context, 'Student updated.');
                      }
                    },
            ),
            const SizedBox(height: 10),
          ],
          NeuButton(
            label: 'Edit details',
            icon: Icons.edit_outlined,
            secondary: true,
            onPressed: _busy
                ? null
                : () async {
                    final updated = await showSheet<AdminUser>(context, (_) => _EditAccountForm(user: _u));
                    if (updated != null) {
                      setState(() => _u = updated);
                      _changed = true;
                      if (context.mounted) toast(context, 'Details saved.');
                    }
                  },
          ),
          const SizedBox(height: 10),
          NeuButton(
            label: 'Set a new password',
            icon: Icons.key_rounded,
            secondary: true,
            onPressed: _busy
                ? null
                : () async {
                    final done = await showSheet<bool>(context, (_) => _ResetPasswordForm(userId: _u.id, name: _u.fullName));
                    if (done == true) {
                      _changed = true;
                      if (context.mounted) toast(context, 'Password changed. The person must sign in again.');
                    }
                  },
          ),
          if (_u.isLocked || _u.failedAttempts > 0) ...[
            const SizedBox(height: 10),
            NeuButton(
              label: 'Unlock account',
              icon: Icons.lock_open_rounded,
              secondary: true,
              busy: _busy,
              onPressed: () => _run(() async {
                await svc.admin.unlock(_u.id);
                final fresh = await svc.admin.updateUser(_u.id);
                if (mounted) setState(() => _u = fresh);
              }, 'Account unlocked.'),
            ),
          ],
          const SizedBox(height: 10),
          NeuButton(
            label: _u.isActive ? 'Disable account' : 'Enable account',
            icon: _u.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
            secondary: true,
            danger: _u.isActive,
            busy: _busy,
            onPressed: () async {
              if (_u.isActive) {
                final yes = await confirm(context,
                    title: 'Disable ${_u.fullName}?',
                    message: 'They will not be able to sign in until you enable the account again.',
                    confirmLabel: 'Disable');
                if (!yes || !context.mounted) return;
              }
              await _run(() async {
                final fresh = await svc.admin.updateUser(_u.id, isActive: !_u.isActive);
                if (mounted) setState(() => _u = fresh);
              }, _u.isActive ? 'Account disabled.' : 'Account enabled.');
            },
          ),
          const SizedBox(height: 10),
          NeuButton(
            label: 'Delete account',
            icon: Icons.delete_outline_rounded,
            danger: true,
            secondary: true,
            onPressed: _busy
                ? null
                : () async {
                    final yes = await confirm(context,
                        title: 'Delete ${_u.fullName}?',
                        message: 'Their attendance, marks and profile are deleted with the account. This cannot be undone.');
                    if (!yes || !context.mounted) return;
                    setState(() => _busy = true);
                    final ok = await guard(context, () => svc.admin.deleteUser(_u.id), success: 'Account deleted.');
                    if (mounted) setState(() => _busy = false);
                    if (ok && context.mounted) Navigator.of(context).pop(true);
                  },
          ),
          const SizedBox(height: 6),
          Center(child: Text('Tap outside to close', style: c.small)),
        ],
      ),
    );
  }
}

class _EditAccountForm extends StatefulWidget {
  const _EditAccountForm({required this.user});
  final AdminUser user;

  @override
  State<_EditAccountForm> createState() => _EditAccountFormState();
}

class _EditAccountFormState extends State<_EditAccountForm> {
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _username = TextEditingController(text: widget.user.username);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _email = TextEditingController(text: widget.user.email);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _username, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty) {
      setState(() => _error = 'Name and username are required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final u = await context.svc.admin
          .updateUser(widget.user.id, fullName: _name.text, username: _username.text, phone: _phone.text, email: _email.text);
      if (mounted) Navigator.of(context).pop(u);
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
      title: 'Edit details',
      children: [
        AppField(
            controller: _name,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
            capitalization: TextCapitalization.words,
            maxLength: 150),
        const SizedBox(height: 14),
        AppField(controller: _username, label: 'Username', icon: Icons.alternate_email_rounded, maxLength: 150),
        const SizedBox(height: 14),
        AppField(controller: _phone, label: 'Phone', icon: Icons.phone_outlined, keyboard: TextInputType.phone, maxLength: 20),
        const SizedBox(height: 14),
        AppField(
            controller: _email, label: 'E-mail', icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress, maxLength: 150),
        const SizedBox(height: 20),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error),
      ],
    );
  }
}

class _ResetPasswordForm extends StatefulWidget {
  const _ResetPasswordForm({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  State<_ResetPasswordForm> createState() => _ResetPasswordFormState();
}

class _ResetPasswordFormState extends State<_ResetPasswordForm> {
  final _password = TextEditingController(text: generatePassword());
  bool _show = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.admin.resetPassword(widget.userId, _password.text);
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
      title: 'New password',
      subtitle: 'For ${widget.name}. Copy it and give it to them \u2014 it is not shown again.',
      children: [
        AppField(
          controller: _password,
          label: 'New password',
          icon: Icons.key_rounded,
          obscure: !_show,
          maxLength: 128,
          suffix: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
                icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted),
                onPressed: () => setState(() => _show = !_show)),
            IconButton(
                icon: Icon(Icons.autorenew_rounded, color: c.accent), onPressed: () => setState(() => _password.text = generatePassword())),
          ]),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _password.text));
              if (context.mounted) toast(context, 'Password copied.');
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy password'),
          ),
        ),
        const SizedBox(height: 10),
        SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Set password'),
      ],
    );
  }
}

class _StudentPlacementForm extends StatefulWidget {
  const _StudentPlacementForm({required this.userId, required this.name});
  final String userId;
  final String name;

  @override
  State<_StudentPlacementForm> createState() => _StudentPlacementFormState();
}

class _StudentPlacementFormState extends State<_StudentPlacementForm> {
  final _roll = TextEditingController();
  final _guardian = TextEditingController();
  final _contact = TextEditingController();
  List<SchoolClass> _classes = const [];
  String? _classId;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = context.svc;
    try {
      final (classes, students) = await (svc.academics.classes(), svc.academics.students(hideAlumni: false)).wait;
      final me = students.where((s) => s.userId == widget.userId).firstOrNull;
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _classId = me?.classId;
        _roll.text = me?.rollNumber ?? '';
        _guardian.text = me?.guardianName ?? '';
        _contact.text = me?.guardianContact ?? '';
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = errorText(e);
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    _guardian.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.svc.academics.updateStudent(widget.userId,
          classId: _classId, rollNumber: _roll.text, guardianName: _guardian.text, guardianContact: _contact.text);
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
    final klass = _classes.where((k) => k.id == _classId).firstOrNull;
    return SheetBody(
      title: 'Class & roll number',
      subtitle: widget.name,
      children: [
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else ...[
          PickerField(
            label: 'Class',
            value: klass?.label,
            placeholder: 'No class',
            onTap: () async {
              final k = await pickOne<SchoolClass>(context, title: 'Class', options: _classes, labelOf: (k) => k.label, selected: klass);
              if (k != null) setState(() => _classId = k.id);
            },
          ),
          const SizedBox(height: 14),
          AppField(controller: _roll, label: 'Roll number', icon: Icons.tag_rounded, maxLength: 20),
          const SizedBox(height: 14),
          AppField(
              controller: _guardian,
              label: 'Guardian name',
              icon: Icons.family_restroom_outlined,
              maxLength: 150,
              capitalization: TextCapitalization.words),
          const SizedBox(height: 14),
          AppField(
              controller: _contact, label: 'Guardian contact', icon: Icons.phone_outlined, keyboard: TextInputType.phone, maxLength: 50),
          const SizedBox(height: 20),
          SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error),
        ],
      ],
    );
  }
}
