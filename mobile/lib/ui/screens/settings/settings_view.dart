import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/me_avatar.dart';
import '../../widgets/neu.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.me;
    final theme = context.themeCtl;
    return ListenableBuilder(
      listenable: theme,
      builder: (ctx, _) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        NeuCard(
          child: Row(children: [
            const MeAvatar(size: 60, ring: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.fullName, style: c.h2),
                Text('@${me.username}', style: c.small),
                const SizedBox(height: 6),
                Pill(me.role.label, tone: me.isSuperAdmin ? 'bad' : (me.isTeacher ? 'warn' : 'accent')),
              ]),
            ),
          ]),
        ),
        const SectionTitle('Appearance'),
        NeuCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Theme', style: c.bodyStrong),
            const SizedBox(height: 4),
            ChipBar<ThemeMode>(
              padding: const EdgeInsets.symmetric(vertical: 8),
              items: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              selected: theme.mode,
              labelOf: (m) => m == ThemeMode.system ? 'Auto' : (m == ThemeMode.light ? 'Light' : 'Dark'),
              onChanged: theme.set,
            ),
            Text('Auto follows your phone\u2019s light / dark setting.', style: c.small),
          ]),
        ),
        const SectionTitle('Security'),
        NeuCard(
          onTap: () => showSheet<void>(ctx, (_) => const _ChangePasswordForm()),
          child: Row(children: [
            Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.key_rounded, color: c.accent)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text('Change password', style: c.bodyStrong), Text('You will be asked to sign in again.', style: c.small)])),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ]),
        ),
        const SectionTitle('About'),
        NeuCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Image.asset('assets/images/school_logo.png', width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(child: Text(AppConfig.schoolNameFull, style: c.h2)),
            ]),
            const SizedBox(height: 10),
            Text('${AppConfig.schoolTown} \u00b7 Est. ${AppConfig.establishedYear}', style: c.small),
            const SizedBox(height: 10),
            InfoRow('App version', AppConfig.appBuild > 0 ? '${AppConfig.appVersion} (build ${AppConfig.appBuild})' : AppConfig.appVersion),
            const SizedBox(height: 8),
            if (AppConfig.updateRepo.isNotEmpty) ...[
              NeuButton(
                  label: 'Check for updates',
                  icon: Icons.system_update_alt_rounded,
                  secondary: true,
                  compact: true,
                  onPressed: () async {
                    final svc = ctx.svc;
                    final ran = await svc.checkForUpdate();
                    if (!ctx.mounted) return;
                    toast(ctx, !ran ? 'Update check is only available in the downloaded app.' : (svc.update.value == null ? 'You have the latest version.' : 'A new version is ready \u2014 see the banner on the home screen.'));
                  }),
              const SizedBox(height: 8),
              NeuButton(
                  label: 'Share this app',
                  icon: Icons.share_rounded,
                  secondary: true,
                  compact: true,
                  onPressed: () async {
                    final link = AppConfig.downloadUrl.isNotEmpty ? AppConfig.downloadUrl : 'https://github.com/${AppConfig.updateRepo}/releases/tag/mobile-latest';
                    await Clipboard.setData(ClipboardData(text: 'Download the TVV School app: $link'));
                    if (ctx.mounted) toast(ctx, 'Download link copied \u2014 paste it in WhatsApp or anywhere.');
                  }),
              const SizedBox(height: 8),
            ],
            NeuButton(
                label: 'Open school website',
                icon: Icons.language_rounded,
                secondary: true,
                compact: true,
                onPressed: () => openLink(ctx, AppConfig.websiteUrl)),
          ]),
        ),
        const SizedBox(height: 22),
        NeuButton(
          label: 'Sign out',
          icon: Icons.logout_rounded,
          danger: true,
          secondary: true,
          onPressed: () async {
            final yes = await confirm(ctx,
                title: 'Sign out?',
                message: 'You will need your username and password to sign in again.',
                confirmLabel: 'Sign out',
                danger: false);
            if (yes && ctx.mounted) await ctx.session.logout();
          },
        ),
      ]),
    );
  }
}

class _ChangePasswordForm extends StatefulWidget {
  const _ChangePasswordForm();

  @override
  State<_ChangePasswordForm> createState() => _ChangePasswordFormState();
}

class _ChangePasswordFormState extends State<_ChangePasswordForm> {
  final _key = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final session = context.session;
    final svc = context.svc;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await svc.auth.changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      // The server ends every old session when the password changes, so go to the sign-in screen with a clear message.
      await session.logout(notice: 'Password changed. Please sign in with your new password.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors['new_password'] ?? e.fieldErrors['current_password'] ?? e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final eye = IconButton(
        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted),
        onPressed: () => setState(() => _show = !_show));
    return SheetBody(
      title: 'Change password',
      subtitle: 'Use at least 8 characters. Avoid your name or birth date.',
      children: [
        Form(
          key: _key,
          child: Column(children: [
            AppField(
                controller: _current,
                label: 'Current password',
                icon: Icons.lock_outline_rounded,
                obscure: !_show,
                maxLength: 128,
                validator: (v) => requiredField(v, 'Current password'),
                suffix: eye),
            const SizedBox(height: 14),
            AppField(
                controller: _next,
                label: 'New password',
                icon: Icons.key_rounded,
                obscure: !_show,
                maxLength: 128,
                validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null),
            const SizedBox(height: 14),
            AppField(
                controller: _again,
                label: 'Repeat new password',
                icon: Icons.key_rounded,
                obscure: !_show,
                maxLength: 128,
                validator: (v) => v != _next.text ? 'The two passwords do not match' : null),
            const SizedBox(height: 20),
            SaveBar(onSave: _busy ? null : _save, busy: _busy, error: _error, label: 'Change password'),
          ]),
        ),
      ],
    );
  }
}
