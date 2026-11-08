import 'package:flutter/material.dart';

import 'common.dart';

/// Asks "discard your changes?" when someone presses Back on a form with unsaved work.
/// It only acts on screens opened on top of the home screen; inside the home tabs the entries are kept
/// (the tabs keep their state), so Back there must keep behaving normally.
class DirtyGuard extends StatelessWidget {
  const DirtyGuard({super.key, required this.dirty, required this.child, this.message = 'You have unsaved changes. Leave without saving?'});
  final bool dirty;
  final Widget child;
  final String message;

  @override
  Widget build(BuildContext context) {
    final inPushedScreen = Navigator.of(context).canPop();
    return PopScope(
      canPop: !(dirty && inPushedScreen),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, title: 'Discard changes?', message: message, confirmLabel: 'Discard');
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: child,
    );
  }
}
