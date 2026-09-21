import 'package:core/models/data_source.dart';
import 'package:core/models/game.dart';
import 'package:core/models/platform.dart' as model;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/database/database_service.dart';
import 'package:tonkatsu_box/core/import/sources/name_list/game_name_list_import_service.dart';
import 'package:tonkatsu_box/features/settings/content/game_name_list_import_content.dart';
import 'package:tonkatsu_box/features/settings/providers/settings_provider.dart';
import 'package:tonkatsu_box/l10n/app_localizations.dart';

import '../../../helpers/test_helpers.dart';

class MockGameNameListImportService extends Mock
    implements GameNameListImportService {}

/// Connected IGDB so the "no key" banner does not push the review list down
/// past the fold.
class _ConnectedSettingsNotifier extends SettingsNotifier {
  @override
  SettingsState build() {
    return const SettingsState(connectionStatus: ConnectionStatus.connected);
  }
}

/// Picking a candidate from the "Review" dialog must close **that dialog only**.
///
/// The dialog is pushed onto the root navigator (`showDialog`'s default), while
/// the import screen lives on the shell's per-tab navigator. Popping through
/// the screen's own context therefore resolves to the *tab* navigator and pops
/// the import screen itself — the user picks an option and loses the whole
/// review list before they can press Import. This test pins the review screen
/// as still present, and the tab root as still covered.
void main() {
  /// Sentinel route underneath the import screen on the tab navigator.
  const String rootMarker = 'TAB-ROOT';

  late MockGameNameListImportService service;
  late GlobalKey<NavigatorState> hostKey;

  setUpAll(registerAllFallbacks);

  /// One name that matched nothing, so the row shows the Review button.
  GameNameMatchSession session() {
    return GameNameMatchSession(
      rows: <GameNameMatchRow>[
        GameNameMatchRow(
          original: 'Hogwarts Legacy',
          candidates: const <GameNameCandidate>[
            GameNameCandidate(
              game: Game(id: 1, name: 'Hogwarts Legacy Deluxe Edition'),
              source: DataSource.igdb,
              score: 61,
            ),
            GameNameCandidate(
              game: Game(id: 2, name: '霍格沃茨之遗'),
              source: DataSource.taptap,
              score: 58,
            ),
          ],
          selectedIndex: -1,
        ),
      ],
    );
  }

  setUp(() {
    service = MockGameNameListImportService();
    hostKey = GlobalKey<NavigatorState>();

    when(
      () => service.match(
        any(),
        platformId: any(named: 'platformId'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) async => session());
  });

  Widget hostWithRoot(List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('en'),
        home: Navigator(
          key: hostKey,
          onGenerateInitialRoutes: (NavigatorState navigator, String name) {
            return <Route<void>>[
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    const Scaffold(body: Center(child: Text(rootMarker))),
              ),
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const Scaffold(
                  body: SingleChildScrollView(
                    child: GameNameListImportContent(
                      initialNames: <String>['Hogwarts Legacy'],
                    ),
                  ),
                ),
              ),
            ];
          },
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester, {int frames = 12}) async {
    for (int i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> driveToReview(WidgetTester tester) async {
    final MockDatabaseService database = MockDatabaseService();
    final MockGameDao gameDao = MockGameDao();
    when(() => database.gameDao).thenReturn(gameDao);
    when(() => gameDao.getAllPlatforms()).thenAnswer(
      (_) async => <model.Platform>[
        const model.Platform(id: 167, name: 'PlayStation 5', abbreviation: 'PS5'),
      ],
    );

    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      hostWithRoot(<Override>[
        gameNameListImportServiceProvider.overrideWithValue(service),
        databaseServiceProvider.overrideWithValue(database),
        settingsNotifierProvider.overrideWith(_ConnectedSettingsNotifier.new),
      ]),
    );
    await settle(tester);

    // The matching dialog stays up until the user acknowledges it.
    expect(find.text('Done'), findsOneWidget,
        reason: 'the seeded run should already be matching');
    await tester.tap(find.text('Done'));
    await settle(tester);

    expect(find.text('Back to edit'), findsOneWidget,
        reason: 'seeding initialNames should land on the review stage');
  }

  Future<void> openReviewDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Review'));
    await tester.tap(find.text('Review'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
  }

  testWidgets('picking a candidate keeps the review list on screen',
      (WidgetTester tester) async {
    await driveToReview(tester);
    await openReviewDialog(tester);

    await tester.tap(find.text('Hogwarts Legacy Deluxe Edition'));
    await settle(tester, frames: 24);

    // The dialog is done…
    expect(find.byType(AlertDialog), findsNothing);
    // …the review stage is still there, with the pick applied…
    expect(find.text('Back to edit'), findsOneWidget);
    expect(find.text('Hogwarts Legacy Deluxe Edition'), findsWidgets);
    // …and the tab root never came back: exactly one route was popped.
    expect(find.text(rootMarker), findsNothing,
        reason: 'picking a candidate must not pop the import screen too');
    expect(hostKey.currentState?.canPop(), isTrue);
  });

  testWidgets('"Do not import" also leaves the review list on screen',
      (WidgetTester tester) async {
    await driveToReview(tester);
    await openReviewDialog(tester);

    await tester.tap(find.text('Do not import'));
    await settle(tester, frames: 24);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Back to edit'), findsOneWidget);
    expect(find.text(rootMarker), findsNothing);
  });

  testWidgets('tapping the row body opens the same dialog and survives it',
      (WidgetTester tester) async {
    await driveToReview(tester);

    await tester.tap(find.text('Hogwarts Legacy'));
    await settle(tester);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.tap(find.text('霍格沃茨之遗'));
    await settle(tester, frames: 24);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text(rootMarker), findsNothing);
    expect(find.text('Back to edit'), findsOneWidget);
  });
}
