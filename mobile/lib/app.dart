import 'package:flutter/material.dart';

import 'core/config.dart';
import 'state/app_scope.dart';
import 'state/app_services.dart';
import 'state/session_controller.dart';
import 'state/theme_controller.dart';
import 'ui/screens/auth/boot_screen.dart';
import 'ui/screens/auth/login_screen.dart';
import 'ui/screens/home/home_shell.dart';
import 'ui/theme/app_theme.dart';

class TvvApp extends StatefulWidget {
  const TvvApp({super.key, required this.services});
  final AppServices services;

  @override
  State<TvvApp> createState() => _TvvAppState();
}

class _TvvAppState extends State<TvvApp> {
  late final SessionController _session = SessionController(widget.services);
  final ThemeController _theme = ThemeController();
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  SessionStatus? _last;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSession);
    _theme.load();
    _session.boot();
  }

  /// When the person signs out (or the session ends) close every screen that was pushed on top of the home screen.
  void _onSession() {
    if (_last == SessionStatus.signedIn && _session.status != SessionStatus.signedIn) {
      _navKey.currentState?.popUntil((r) => r.isFirst);
    }
    _last = _session.status;
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    _theme.dispose();
    widget.services.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      session: _session,
      themeController: _theme,
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) => MaterialApp(
          title: AppConfig.schoolNameFull,
          debugShowCheckedModeBanner: false,
          navigatorKey: _navKey,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: _theme.mode,
          // Keep layouts intact for people who use very large system text (or a big "display size"), without ignoring
          // their setting: text may grow by up to 15%, and nothing is ever drawn wider than the screen.
          builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 0.9, maxScaleFactor: 1.15, child: ClipRect(child: child ?? const SizedBox.shrink())),
          home: ListenableBuilder(
            listenable: _session,
            builder: (context, _) {
              switch (_session.status) {
                case SessionStatus.booting:
                case SessionStatus.bootFailed:
                  return BootScreen(session: _session);
                case SessionStatus.signedOut:
                  return const LoginScreen();
                case SessionStatus.signedIn:
                  // A fresh key per person so a different account never sees the previous one's cached screens.
                  return HomeShell(key: ValueKey(_session.user!.id));
              }
            },
          ),
        ),
      ),
    );
  }
}
