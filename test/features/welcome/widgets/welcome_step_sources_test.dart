import 'package:core/models/data_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/features/settings/providers/settings_provider.dart';
import 'package:tonkatsu_box/features/settings/widgets/inline_text_field.dart';
import 'package:tonkatsu_box/features/welcome/widgets/welcome_step_sources.dart';
import 'package:tonkatsu_box/l10n/app_localizations.dart';
import 'package:tonkatsu_box/shared/constants/source_catalog.dart';
import 'package:tonkatsu_box/shared/widgets/source_logo.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Widget createWidget() {
    return ProviderScope(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: Locale('en'),
        home: Scaffold(body: WelcomeStepSources()),
      ),
    );
  }

  /// Sources the catalog says need a key — the wizard only renders a key
  /// editor for these.
  int keyedSourceCount() => kDataSourceCatalog
      .where((SourceInfo info) =>
          info.keyRequirement != SourceKeyRequirement.none)
      .length;

  group('WelcomeStepSources', () {
    testWidgets('renders without exception', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(WelcomeStepSources), findsOneWidget);
    });

    testWidgets('shows one logo per catalog source',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(
        find.byType(SourceLogo),
        findsNWidgets(kDataSourceCatalog.length),
      );
    });

    testWidgets('exposes a key field for every keyed source',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Derived from the catalog, not a literal: the editor dispatches on the
      // source, and a keyed source missing from that switch renders nothing at
      // all, so a stale count would stay green while the card went blank.
      const Set<DataSource> pairSources = <DataSource>{
        DataSource.igdb,
        DataSource.podcastIndex,
      };

      expect(
        find.byType(InlineTextField),
        findsNWidgets(keyedSourceCount() + pairSources.length),
      );
    });

    testWidgets('links every keyed source to its provider page',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      expect(find.text('Get a key'), findsNWidgets(keyedSourceCount()));
    });
  });
}
