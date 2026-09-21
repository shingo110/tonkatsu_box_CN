import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/api/source_reachability.dart';
import 'package:tonkatsu_box/features/settings/screens/reachability_screen.dart';
import 'package:tonkatsu_box/l10n/app_localizations.dart';
import 'package:tonkatsu_box/shared/constants/source_catalog.dart';
import 'package:tonkatsu_box/shared/theme/app_theme.dart';

/// Answers from a canned list, so the screen can be driven with no network.
class _FakeProbe extends SourceReachabilityProbe {
  _FakeProbe(this.results);

  final List<SourceReachability> results;

  @override
  Future<List<SourceReachability>> run(List<SourceInfo> targets) async =>
      results;
}

SourceReachability _result(int index, ReachabilityOutcome outcome) =>
    SourceReachability(
      info: kDataSourceCatalog[index],
      outcome: outcome,
      statusCode: outcome == ReachabilityOutcome.reached ? 200 : null,
      elapsed: const Duration(milliseconds: 120),
    );

Future<void> _pump(WidgetTester tester, SourceReachabilityProbe probe) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: S.localizationsDelegates,
      supportedLocales: S.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: ReachabilityScreen(probe: probe)),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('opens with the prompt and no verdicts',
      (WidgetTester tester) async {
    await _pump(tester, _FakeProbe(<SourceReachability>[]));

    expect(find.text('Run Check'), findsOneWidget);
    expect(find.textContaining('sources reached'), findsNothing);
  });

  testWidgets('reports a mix of reached and unreachable providers',
      (WidgetTester tester) async {
    final List<SourceReachability> results = <SourceReachability>[
      _result(0, ReachabilityOutcome.reached),
      _result(10, ReachabilityOutcome.reached),
      _result(14, ReachabilityOutcome.timedOut),
      _result(2, ReachabilityOutcome.unreachable),
    ];
    await _pump(tester, _FakeProbe(results));

    await tester.tap(find.text('Run Check'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 4 sources reached'), findsOneWidget);
    expect(find.text('Reached'), findsNWidgets(2));
    expect(find.text('Timed Out'), findsOneWidget);
    expect(find.text('Unreachable'), findsOneWidget);
    // The host and the round trip are what make the verdict actionable.
    expect(find.textContaining('neodb.social'), findsOneWidget);
    expect(find.textContaining('120 ms'), findsNWidgets(4));
  });
}
