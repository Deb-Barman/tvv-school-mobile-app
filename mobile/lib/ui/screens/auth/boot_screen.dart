import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../state/session_controller.dart';
import '../../theme/tokens.dart';
import '../../widgets/states.dart';

/// Shown while the app checks the stored sign-in. If the server is unreachable the person can retry;
/// they are never signed out just because they are offline.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key, required this.session});
  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (session.status == SessionStatus.bootFailed) {
      return Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(child: ErrorState(message: session.bootError ?? 'Please try again.', offline: true, onRetry: session.boot)),
      );
    }
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 120,
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, boxShadow: c.raised(3)),
            child: Image.asset('assets/images/school_logo.png'),
          ),
          const SizedBox(height: 24),
          Text(AppConfig.schoolName, textAlign: TextAlign.center, style: c.display.copyWith(fontSize: 22)),
          const SizedBox(height: 22),
          SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.6, color: c.accent)),
        ]),
      ),
    );
  }
}
