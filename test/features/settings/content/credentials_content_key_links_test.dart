import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/core/api/igdb_api.dart';
import 'package:tonkatsu_box/core/api/steamgriddb_api.dart';
import 'package:tonkatsu_box/core/api/tmdb_api.dart';
import 'package:tonkatsu_box/core/database/database_service.dart';
import 'package:tonkatsu_box/core/services/api_key_initializer.dart';
import 'package:tonkatsu_box/features/settings/content/credentials_content.dart';
import 'package:tonkatsu_box/features/settings/providers/settings_provider.dart';
import 'package:tonkatsu_box/l10n/app_localizations.dart';
import 'package:tonkatsu_box/shared/constants/source_catalog.dart';
import 'package:tonkatsu_box/shared/theme/app_theme.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockIgdbApi mockIgdbApi;
  late MockSteamGridDbApi mockSteamGridDbApi;
  late MockTmdbApi mockTmdbApi;
  late MockDatabaseService mockDbService;
  late MockGameDao mockGameDao;

  setUp(() {
    mockIgdbApi = MockIgdbApi();
    mockSteamGridDbApi = MockSteamGridDbApi();
    mockTmdbApi = MockTmdbApi();
    mockDbService = MockDatabaseService();
    mockGameDao = MockGameDao();
    when(() => mockDbService.gameDao).thenReturn(mockGameDao);
    when(() => mockGameDao.getPlatformCount()).thenAnswer((_) async => 0);
    when(() => mockIgdbApi.getAccessToken(
          clientId: any(named: 'clientId'),
          clientSecret: any(named: 'clientSecret'),
        )).thenThrow(const IgdbApiException('Test: no real API'));
  });

  Future<void> pumpContent(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          apiKeysProvider.overrideWithValue(const ApiKeys()),
          igdbApiProvider.overrideWithValue(mockIgdbApi),
          steamGridDbApiProvider.overrideWithValue(mockSteamGridDbApi),
          tmdbApiProvider.overrideWithValue(mockTmdbApi),
          databaseServiceProvider.overrideWithValue(mockDbService),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          localizationsDelegates: S.localizationsDelegates,
          supportedLocales: S.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(
            body: SingleChildScrollView(child: CredentialsContent()),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('every keyed source links to its provider page',
      (WidgetTester tester) async {
    await pumpContent(tester);

    // The link URL comes from the shared catalog, so this also pins that the
    // screen keeps reading it: drop the link and every source loses its way to
    // obtain a key. SteamGridDB and ScreenScraper are absent from the catalog,
    // so neither contributes a link.
    final int keyedSources = kDataSourceCatalog
        .where((SourceInfo info) =>
            info.keyRequirement != SourceKeyRequirement.none)
        .length;

    expect(find.text('Get a key'), findsNWidgets(keyedSources));
  });

  testWidgets('Douban has no key screen — the build ships its pair',
      (WidgetTester tester) async {
    await pumpContent(tester);

    // Frodo issues no new keys, so a field here would be a dead end. The
    // pair ships in the build and the source signs with it;
    // SettingsGroup upper-cases its title, hence the caps.
    expect(find.text('DOUBAN API (BOOKS & FILM)'), findsNothing);
    expect(find.text('DOUBAN API (BOOKS)'), findsNothing);
  });
}
