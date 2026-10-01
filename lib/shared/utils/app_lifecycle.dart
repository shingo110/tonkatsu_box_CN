import 'package:flutter/widgets.dart';

/// Whether periodic UI work should run right now.
///
/// Returns false while the app is backgrounded or detached so `Timer.periodic`
/// callbacks stop burning CPU and battery behind the user's back. A null
/// lifecycle state means the binding has not delivered its first event yet, so
/// the first tick is allowed through.
bool isAppInForeground() {
  final AppLifecycleState? state = WidgetsBinding.instance.lifecycleState;
  return state == null || state == AppLifecycleState.resumed;
}
