import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/app_lifecycle.dart';

/// Overridable clock so season rows and countdowns can be tested against a
/// fixed date.
final Provider<DateTime Function()> showcaseClockProvider =
    Provider<DateTime Function()>((Ref _) => DateTime.now);

/// One minute tick shared by every countdown on the screen; dies with the
/// last card instead of running a timer per card.
final AutoDisposeNotifierProvider<ShowcaseNowNotifier, DateTime>
    showcaseNowProvider =
    NotifierProvider.autoDispose<ShowcaseNowNotifier, DateTime>(
  ShowcaseNowNotifier.new,
);

class ShowcaseNowNotifier extends AutoDisposeNotifier<DateTime> {
  static const Duration tick = Duration(minutes: 1);

  @override
  DateTime build() {
    final DateTime Function() clock = ref.watch(showcaseClockProvider);
    final Timer timer = Timer.periodic(tick, (Timer _) {
      // No rebuild while the screen is backgrounded — the countdowns are not
      // visible, and re-emitting the clock would repaint the whole tree.
      if (!isAppInForeground()) return;
      state = clock();
    });
    ref.onDispose(timer.cancel);
    return clock();
  }
}
