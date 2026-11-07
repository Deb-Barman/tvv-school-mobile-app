import 'package:flutter/widgets.dart';

import 'app_services.dart';
import 'session_controller.dart';
import 'theme_controller.dart';
import '../data/models/user.dart';

/// Gives every screen the services and controllers without a state-management package.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required this.session, required this.themeController, required super.child});

  final AppServices services;
  final SessionController session;
  final ThemeController themeController;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      services != oldWidget.services || session != oldWidget.session || themeController != oldWidget.themeController;
}

extension AppContext on BuildContext {
  AppServices get svc => AppScope.of(this).services;
  SessionController get session => AppScope.of(this).session;
  ThemeController get themeCtl => AppScope.of(this).themeController;

  /// The signed-in user. Screens are only built while someone is signed in; the placeholder only exists so that a
  /// screen that is still animating away during sign-out can never crash on a missing user.
  AppUser get me => AppScope.of(this).session.user ?? _signedOut;
}

const AppUser _signedOut = AppUser(id: '', username: '', fullName: '', role: Role.student);
