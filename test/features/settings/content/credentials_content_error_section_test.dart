import 'package:flutter/material.dart';
import 'package:tonkatsu_box/l10n/app_localizations.dart';
import 'package:tonkatsu_box/shared/theme/app_theme.dart';
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

import '../../../helpers/test_helpers.dart';

// `ConnectionStatus.error` carries two shapes: no message means the check never
// left the device (credentials missing), a message means the transport failed
// and that raw detail is the payload. The settings UI branches on exactly that,
// so both are pinned here — the hint comes from l10n, the detail stays verbatim
// because it is the only part worth copying into a bug report.
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
  });

  Future<ProviderContainer> pumpContent(
    WidgetTester tester,
    SharedPreferences prefs,
  ) async {
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
    return ProviderScope.containerOf(
      tester.element(find.byType(CredentialsContent)),
    );
  }

  testWidgets('a check with no credentials asks for them instead of failing',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final ProviderContainer container = await pumpContent(tester, prefs);
    // Precondition: nothing stored and no build-time built-in in test runs.
    expect(container.read(settingsNotifierProvider).hasCredentials, isFalse);
    await container.read(settingsNotifierProvider.notifier).verifyConnection();
    await tester.pump();

    expect(
      find.text('Please enter Client ID and Client Secret'),
      findsOneWidget,
    );
  });

  testWidgets('a transport failure pairs the localized hint with the detail',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{
      'igdb_client_id': 'client-id',
      'igdb_client_secret': 'client-secret',
    });
    when(() => mockIgdbApi.getAccessToken(
          clientId: any(named: 'clientId'),
          clientSecret: any(named: 'clientSecret'),
        )).thenThrow(
      const IgdbApiException('Auth request failed', detail: 'socket refused'),
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final ProviderContainer container = await pumpContent(tester, prefs);
    await container.read(settingsNotifierProvider.notifier).verifyConnection();
    await tester.pump();

    // The actionable line is localized...
    expect(
      find.textContaining('Check your network or proxy settings'),
      findsOneWidget,
    );
    // ...and the transport's own words survive underneath it untouched.
    expect(find.textContaining('socket refused'), findsOneWidget);
  });
}
