import 'package:flutter/material.dart';

import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../state/app_scope.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/insta.dart';
import '../../widgets/neu.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _key = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  LoginPortal _portal = LoginPortal.schoolMember;
  bool _show = false;
  bool _busy = false;
  String? _error;
  bool _warmed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_warmed) {
      _warmed = true;
      // The free server sleeps when idle; waking it while the person types makes the first sign-in fast.
      if (context.svc.warmUpOnStart) context.svc.api.warmUp();
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_key.currentState!.validate()) return;
    final session = context.session;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.login(username: _user.text, password: _pass.text, portal: _portal);
      // On success the app root swaps this screen for the dashboard.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not sign in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _togglePortal() {
    if (_busy) return;
    setState(() {
      _portal = _portal == LoginPortal.superAdmin ? LoginPortal.schoolMember : LoginPortal.superAdmin;
      _error = null;
      _user.clear();
      _pass.clear();
    });
    toast(context, _portal == LoginPortal.superAdmin ? 'Super Admin sign in' : 'Student / Teacher sign in');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final admin = _portal == LoginPortal.superAdmin;
    final notice = context.session.notice;
    return Scaffold(
      backgroundColor: c.bg,
      body: DecoratedBox(
        // A soft violet glow behind the seal.
        decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: const Alignment(0, -0.1), colors: [c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12), c.bg])),
        child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _key,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // Long-press the school seal to switch to the Super Admin sign-in (kept out of sight on purpose).
                    Center(
                      child: GestureDetector(
                        key: const Key('login-logo'),
                        onLongPress: _togglePortal,
                        child: const SchoolLogo(size: 108),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(AppConfig.schoolNameFull, textAlign: TextAlign.center, style: c.display),
                    const SizedBox(height: 4),
                    Text(AppConfig.motto, textAlign: TextAlign.center, style: c.small),
                    const SizedBox(height: 30),
                    Text(admin ? 'Super Admin sign in' : 'Sign in', textAlign: TextAlign.center, style: c.h1),
                    const SizedBox(height: 4),
                    Text(
                        admin ? 'Use the administrator e-mail and password.' : 'Use the username and password given by the school.',
                        textAlign: TextAlign.center,
                        style: c.small),
                    if (notice != null) ...[
                      const SizedBox(height: 14),
                      _Banner(text: notice, tone: 'warn', icon: Icons.info_outline_rounded),
                    ],
                    const SizedBox(height: 20),
                    AppField(
                      controller: _user,
                      label: admin ? 'Admin e-mail' : 'Username',
                      icon: admin ? Icons.mail_outline_rounded : Icons.person_outline_rounded,
                      keyboard: admin ? TextInputType.emailAddress : TextInputType.text,
                      action: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      validator: (v) => requiredField(v, admin ? 'E-mail' : 'Username'),
                    ),
                    const SizedBox(height: 12),
                    AppField(
                      controller: _pass,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_show,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _busy ? null : _submit(),
                      autofillHints: const [AutofillHints.password],
                      validator: (v) => requiredField(v, 'Password'),
                      suffix: IconButton(
                          tooltip: _show ? 'Hide password' : 'Show password',
                          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.muted),
                          onPressed: () => setState(() => _show = !_show)),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      _Banner(text: _error!, tone: 'bad', icon: Icons.error_outline_rounded),
                    ],
                    const SizedBox(height: 18),
                    NeuButton(label: 'Sign in', busy: _busy, onPressed: _submit),
                    if (!admin)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextButton(
                            onPressed: _busy ? null : () => showSheet<void>(context, (_) => _ForgotForm(initialUsername: _user.text.trim())),
                            child: Text('Forgot password?', style: TextStyle(color: c.accent, fontWeight: FontWeight.w600))),
                      )
                    else
                      TextButton(
                          onPressed: _busy ? null : _togglePortal,
                          child: Text('\u2190 Student / Teacher sign in', style: TextStyle(color: c.muted))),
                    const SizedBox(height: 22),
                    Text('${AppConfig.schoolTown}', textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 11.5)),
                    const SizedBox(height: 2),
                    Text('App version ${AppConfig.appVersion}', textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 11)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone, required this.icon});
  final String text;
  final String tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final col = c.tone(tone);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: col.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: col.withValues(alpha: 0.35))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: col),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: c.text, fontSize: 13.5, height: 1.35))),
      ]),
    );
  }
}

class _ForgotForm extends StatefulWidget {
  const _ForgotForm({this.initialUsername = ''});
  final String initialUsername;

  @override
  State<_ForgotForm> createState() => _ForgotFormState();
}

class _ForgotFormState extends State<_ForgotForm> {
  late final _user = TextEditingController(text: widget.initialUsername);
  final _note = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _user.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_user.text.trim().isEmpty) {
      setState(() => _error = 'Enter your username.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await context.svc.auth.forgotPassword(username: _user.text, note: _note.text.trim());
      if (mounted) setState(() => _done = msg);
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
      title: 'Forgot your password?',
      subtitle: 'Nobody can read your password. The school office will set a new one for you.',
      children: [
        if (_done != null) ...[
          _Banner(text: _done!, tone: 'good', icon: Icons.check_circle_outline_rounded),
          const SizedBox(height: 16),
          NeuButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ] else ...[
          AppField(controller: _user, label: 'Your username', icon: Icons.person_outline_rounded, maxLength: 150),
          const SizedBox(height: 14),
          AppField(controller: _note, label: 'Note for the office (optional)', hint: 'Class, roll number...', maxLines: 3, maxLength: 300),
          const SizedBox(height: 6),
          Text('Please also tell your class teacher so they can confirm it is really you.', style: c.small),
          const SizedBox(height: 18),
          SaveBar(onSave: _busy ? null : _send, busy: _busy, error: _error, label: 'Send request'),
        ],
      ],
    );
  }
}
