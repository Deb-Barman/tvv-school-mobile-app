import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../state/session_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/insta.dart';
import '../../widgets/states.dart';

/// Shown while the app checks the stored sign-in (and while the free school server wakes up).
///
/// * The seal fades in once; only the small ring and the progress bar keep moving (loaders may loop, decoration may not).
/// * After a few seconds it says in words what is happening, so a long wait is never unexplained.
/// * Respects "remove animations" in the phone's accessibility settings.
/// * If the server is unreachable the person can retry; they are never signed out just because they are offline.
class BootScreen extends StatefulWidget {
  const BootScreen({super.key, required this.session});
  final SessionController session;

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController _bar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  Timer? _clock;
  int _secs = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secs++);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _intro.value = 1;
      _spin.stop();
      _bar.stop();
    } else if (!_started) {
      _started = true;
      _intro.forward();
      _spin.repeat();
      _bar.repeat();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    _intro.dispose();
    _spin.dispose();
    _bar.dispose();
    super.dispose();
  }

  String get _status {
    if (_secs < 3) return 'Opening your school\u2026';
    if (_secs < 9) return 'Connecting to the school server\u2026';
    return 'The school server is waking up. The first open can take up to a minute \u2014 thank you for waiting.';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (widget.session.status == SessionStatus.bootFailed) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(child: ErrorState(message: widget.session.bootError ?? 'Please try again.', offline: true, onRetry: widget.session.boot)),
      );
    }

    final logo = FadeTransition(
      opacity: CurvedAnimation(parent: _intro, curve: const Interval(0, 0.6, curve: Curves.easeOut)),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.86, end: 1).animate(CurvedAnimation(parent: _intro, curve: Curves.easeOutCubic)),
        child: SizedBox(
          width: 176,
          height: 176,
          child: Stack(alignment: Alignment.center, children: [
            // soft glow
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.accent.withValues(alpha: c.isDark ? 0.35 : 0.28), blurRadius: 44, spreadRadius: 4)]),
            ),
            // the slowly turning colour ring (this is the loader)
            RepaintBoundary(
              child: RotationTransition(
                turns: _spin,
                child: Container(
                  width: 176,
                  height: 176,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [
                      Color(0xFFFEDA75),
                      Color(0xFFFA7E1E),
                      Color(0xFFD62976),
                      Color(0xFF962FBF),
                      Color(0xFF4F5BD5),
                      Color(0xFFFEDA75),
                    ]),
                  ),
                ),
              ),
            ),
            Container(width: 166, height: 166, decoration: BoxDecoration(shape: BoxShape.circle, color: c.bg)),
            ClipOval(
              child: SizedBox(
                width: 156,
                height: 156,
                child: ColoredBox(color: const Color(0xFF05101C), child: Image.asset('assets/images/school_logo.png', fit: BoxFit.cover)),
              ),
            ),
          ]),
        ),
      ),
    );

    Widget rise(double from, Widget child) => FadeTransition(
          opacity: CurvedAnimation(parent: _intro, curve: Interval(from, 1, curve: Curves.easeOut)),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(CurvedAnimation(parent: _intro, curve: Interval(from, 1, curve: Curves.easeOutCubic))),
            child: child,
          ),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: DecoratedBox(
        decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: const Alignment(0, 0.15), colors: [c.accent.withValues(alpha: c.isDark ? 0.22 : 0.12), c.bg])),
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 5),
            Semantics(label: AppConfig.schoolNameFull, image: true, child: logo),
            const SizedBox(height: 30),
            rise(
              0.35,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(AppConfig.schoolNameFull, textAlign: TextAlign.center, style: c.display.copyWith(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 8),
            rise(0.5, Text(AppConfig.motto, textAlign: TextAlign.center, style: c.small.copyWith(letterSpacing: 0.4))),
            const Spacer(flex: 4),
            // progress bar + plain-words status (announced to screen readers)
            rise(
              0.65,
              Column(children: [
                SizedBox(
                  width: 150,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(children: [
                      Positioned.fill(child: ColoredBox(color: c.edge)),
                      AnimatedBuilder(
                        animation: _bar,
                        builder: (_, __) {
                          final t = reduceMotion(context) ? 0.35 : _bar.value;
                          return Align(
                            alignment: Alignment(-1 + 2 * t, 0),
                            child: FractionallySizedBox(widthFactor: 0.38, child: DecoratedBox(decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(4)))),
                          );
                        },
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Semantics(
                    liveRegion: true,
                    child: AnimatedSwitcher(
                      duration: motionMs(context, 300),
                      child: Text(_status, key: ValueKey<String>(_status), textAlign: TextAlign.center, style: c.small.copyWith(fontSize: 13)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 26),
            Text('Version ${AppConfig.appVersion}', style: c.small.copyWith(fontSize: 11)),
            const SizedBox(height: 18),
          ]),
        ),
      ),
    );
  }
}
