import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/app.dart';
import 'package:tvv_mobile/core/token_store.dart';
import 'package:tvv_mobile/state/app_services.dart';

void main() {
  testWidgets('with no saved session the app shows the sign-in screen', (tester) async {
    // A tall phone-like surface so nothing is below the fold.
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final services = AppServices.create(baseUrl: 'http://127.0.0.1:1/api', tokens: MemoryTokenStore(), warmUpOnStart: false);
    await tester.pumpWidget(TvvApp(services: services));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Tufanganj Vivekanand Vidyalaya (H.S.)'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Empty form: both fields complain and nothing is sent.
    final signInButton = find.widgetWithText(InkWell, 'Sign in').last;
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    await tester.pump();
    expect(find.text('Username is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // The Super Admin sign-in is hidden: long-press the school seal. It asks for an e-mail instead of a username.
    expect(find.text('Super Admin sign in'), findsNothing);
    await tester.longPress(find.byKey(const Key('login-logo')));
    await tester.pumpAndSettle();
    expect(find.text('Admin e-mail'), findsOneWidget);
  });
}
