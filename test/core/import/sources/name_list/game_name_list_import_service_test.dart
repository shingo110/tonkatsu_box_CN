import 'package:core/models/collection.dart';
import 'package:core/models/collection_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/game.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/universal_import_result.dart';
import 'package:core/models/wishlist_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/igdb_api.dart';
import 'package:tonkatsu_box/core/import/import_progress.dart';
import 'package:tonkatsu_box/core/import/sources/name_list/game_name_list_import_service.dart';

import '../../../../helpers/test_helpers.dart';

/// TapTap shifts its app ids out of IGDB's range; mirror that here so the two
/// catalogues cannot be confused for one another in assertions.
const int _tapTapIdBase = 1000000000;

Game _igdbGame(int id, String name, {List<int>? platformIds}) =>
    Game(id: id, name: name, platformIds: platformIds);

Game _tapTapGame(int appId, String name) =>
    Game(id: appId + _tapTapIdBase, name: name);

void main() {
  setUpAll(() {
    registerAllFallbacks();
    registerFallbackValue(<Map<String, dynamic>>[]);
    registerFallbackValue(<(int, Map<String, dynamic>)>[]);
    registerFallbackValue(<({String name, int? platformId})>[]);
  });

  late GameNameListImportService sut;
  late MockIgdbApi mockIgdb;
  late MockTapTapApi mockTapTap;
  late MockDatabaseService mockDb;
  late MockGameDao mockGameDao;
  late MockCollectionRepository mockRepo;
  late MockWishlistRepository mockWishlist;

  late List<ImportProgress> progressCalls;
  late Map<String, List<Game>> igdbByQuery;
  late Map<String, List<Game>> tapTapByQuery;

  setUp(() {
    mockIgdb = MockIgdbApi();
    mockTapTap = MockTapTapApi();
    mockDb = MockDatabaseService();
    mockGameDao = MockGameDao();
    when(() => mockDb.gameDao).thenReturn(mockGameDao);
    mockRepo = MockCollectionRepository();
    mockWishlist = MockWishlistRepository();

    progressCalls = <ImportProgress>[];
    igdbByQuery = <String, List<Game>>{};
    tapTapByQuery = <String, List<Game>>{};

    when(() => mockIgdb.multiSearchGamesByName(any()))
        .thenAnswer((Invocation inv) async {
      final List<({String name, int? platformId})> queries =
          inv.positionalArguments[0] as List<({String name, int? platformId})>;
      return <int, List<Game>>{
        for (int i = 0; i < queries.length; i++)
          i: igdbByQuery[queries[i].name] ?? <Game>[],
      };
    });

    when(() => mockTapTap.searchGames(
          query: any(named: 'query'),
          page: any(named: 'page'),
        )).thenAnswer((Invocation inv) async {
      final String query = inv.namedArguments[#query] as String;
      return (tapTapByQuery[query] ?? <Game>[], false, 1);
    });

    sut = GameNameListImportService(
      igdbApi: mockIgdb,
      tapTapApi: mockTapTap,
      database: mockDb,
      repository: mockRepo,
      wishlistRepository: mockWishlist,
    );
  });

  void setupWriteMocks() {
    when(() => mockGameDao.upsertGames(any())).thenAnswer((_) async {});
    when(() => mockRepo.create(
          name: any(named: 'name'),
          author: any(named: 'author'),
        )).thenAnswer((_) async => Collection(
          id: 1,
          name: 'Game List',
          author: 'me',
          type: CollectionType.own,
          createdAt: DateTime(2026, 9, 21),
        ));
    when(() => mockRepo.getItems(any()))
        .thenAnswer((_) async => <CollectionItem>[]);
    when(() => mockRepo.addItemsBatchReturningIds(any(), any())).thenAnswer(
        (Invocation inv) async => List<int?>.generate(
            (inv.positionalArguments[1] as List<dynamic>).length,
            (int index) => index + 1));
    when(() => mockRepo.updateItemFieldsBatch(any())).thenAnswer((_) async {});
    when(() => mockWishlist.getAll(
          includeResolved: any(named: 'includeResolved'),
        )).thenAnswer((_) async => <WishlistItem>[]);
    when(() => mockWishlist.addWishlistItemsBatch(any())).thenAnswer(
        (Invocation inv) async =>
            (inv.positionalArguments[0] as List<dynamic>).length);
  }

  Future<GameNameMatchSession> runMatch(
    List<String> names, {
    int? platformId,
  }) =>
      sut.match(
        names,
        platformId: platformId,
        onProgress: (ImportProgress p) => progressCalls.add(p),
      );

  group('match', () {
    test('routes Chinese names to TapTap and Latin names to IGDB', () async {
      tapTapByQuery['战神'] = <Game>[_tapTapGame(1, '战神')];
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(
        <String>['战神', 'God of War'],
      );

      expect(session.rows, hasLength(2));
      expect(session.rows[0].candidates.first.source, DataSource.taptap);
      expect(session.rows[0].candidates.first.game.name, '战神');
      expect(session.rows[1].candidates.first.source, DataSource.igdb);
      expect(session.rows[1].candidates.first.game.name, 'God of War');

      // The Latin title resolved on IGDB, so no TapTap request was spent on it.
      verifyNever(() => mockTapTap.searchGames(query: 'God of War', page: 1));
      verify(() => mockTapTap.searchGames(query: '战神', page: 1)).called(1);
    });

    test('falls back to TapTap when IGDB knows nothing about a Latin title',
        () async {
      tapTapByQuery['Mainland Indie'] = <Game>[_tapTapGame(7, 'Mainland Indie')];

      final GameNameMatchSession session =
          await runMatch(<String>['Mainland Indie']);

      expect(session.rows.first.candidates, hasLength(1));
      expect(session.rows.first.candidates.first.source, DataSource.taptap);
      expect(session.rows.first.isSelected, isTrue);
    });

    test('preselects a confident match', () async {
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(<String>['God of War']);

      expect(session.rows.first.selectedIndex, 0);
      expect(session.selectedCount, 1);
    });

    test('offers but does not preselect an unrelated candidate', () async {
      igdbByQuery['Halo'] = <Game>[_igdbGame(200, 'Gran Turismo 7')];

      final GameNameMatchSession session = await runMatch(<String>['Halo']);

      // The candidate is kept so the user can still see it, but nothing is
      // claimed on their behalf — this is the mismatch the review step exists
      // to catch.
      expect(session.rows.first.candidates, isNotEmpty);
      expect(session.rows.first.selectedIndex, -1);
      expect(session.selectedCount, 0);
    });

    test('leaves an unknown name unmatched and wishlist-bound', () async {
      final GameNameMatchSession session = await runMatch(<String>['Nothing']);

      expect(session.rows.first.candidates, isEmpty);
      expect(session.rows.first.selectedIndex, -1);
      expect(session.unmatchedCount, 1);
    });

    test('flags a row whose lookup threw', () async {
      when(() => mockIgdb.multiSearchGamesByName(any()))
          .thenThrow(const IgdbApiException('boom'));

      final GameNameMatchSession session = await runMatch(<String>['God of War']);

      expect(session.rows.first.searchFailed, isTrue);
      expect(session.rows.first.candidates, isEmpty);
    });

    test('prefers the candidate on the target platform when scores tie',
        () async {
      igdbByQuery['God of War'] = <Game>[
        _igdbGame(100, 'God of War', platformIds: <int>[48]),
        _igdbGame(101, 'God of War', platformIds: <int>[167]),
      ];

      final GameNameMatchSession session =
          await runMatch(<String>['God of War'], platformId: 167);

      expect(session.rows.first.selected?.game.id, 101);
    });

    test('reports progress that never exceeds the total', () async {
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];
      tapTapByQuery['战神'] = <Game>[_tapTapGame(1, '战神')];

      await runMatch(<String>['God of War', '战神', 'Nonexistent']);

      expect(progressCalls, isNotEmpty);
      for (final ImportProgress progress in progressCalls) {
        expect(progress.total, 3);
        expect(progress.current, lessThanOrEqualTo(progress.total));
      }
    });
  });

  group('import', () {
    test('writes the reviewed selection and wishlists the rest', () async {
      setupWriteMocks();
      tapTapByQuery['战神'] = <Game>[_tapTapGame(1, '战神')];

      final GameNameMatchSession session =
          await runMatch(<String>['战神', 'Unknown Title']);

      final UniversalImportResult result = await sut.import(
        GameNameListImportOptions(
          rows: session.rows,
          author: 'me',
          platformId: 167,
          wishlistReason: 'not found',
        ),
      );

      expect(result.success, isTrue);

      final List<Map<String, dynamic>> rows = verify(
        () => mockRepo.addItemsBatchReturningIds(any(), captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(rows, hasLength(1));
      expect(rows.single['external_id'], 1 + _tapTapIdBase);
      expect(rows.single['platform_id'], 167);
      expect(rows.single['media_type'], MediaType.game.value);
      // The TapTap row must not be stamped as IGDB, or a re-import would look
      // for it in the wrong catalogue.
      expect(rows.single['source'], DataSource.taptap.name);

      final List<Map<String, dynamic>> wishlistRows = verify(
        () => mockWishlist.addWishlistItemsBatch(captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(wishlistRows, hasLength(1));
      expect(wishlistRows.single['text'], 'Unknown Title');
      expect(wishlistRows.single['media_type_hint'], MediaType.game.value);
    });

    test('honours a row the user skipped', () async {
      setupWriteMocks();
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(<String>['God of War']);
      session.rows.first.selectedIndex = -1;

      final UniversalImportResult result = await sut.import(
        GameNameListImportOptions(
          rows: session.rows,
          author: 'me',
          platformId: 167,
        ),
      );

      expect(result.success, isTrue);
      // The shared writer is always invoked; what matters is that it was handed
      // no rows, so nothing reached the collection.
      final List<Map<String, dynamic>> writtenRows = verify(
        () => mockRepo.addItemsBatchReturningIds(any(), captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(writtenRows, isEmpty);
      final List<Map<String, dynamic>> wishlistRows = verify(
        () => mockWishlist.addWishlistItemsBatch(captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(wishlistRows.single['text'], 'God of War');
    });

    test('imports without a platform id', () async {
      setupWriteMocks();
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(<String>['God of War']);
      final UniversalImportResult result = await sut.import(
        GameNameListImportOptions(rows: session.rows, author: 'me'),
      );

      expect(result.success, isTrue);
      final List<Map<String, dynamic>> rows = verify(
        () => mockRepo.addItemsBatchReturningIds(any(), captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(rows.single['platform_id'], isNull);
    });

    test('caches every chosen game in the media table', () async {
      setupWriteMocks();
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(<String>['God of War']);
      await sut.import(
        GameNameListImportOptions(rows: session.rows, author: 'me'),
      );

      final List<Game> cached =
          verify(() => mockGameDao.upsertGames(captureAny())).captured.single
              as List<Game>;
      expect(cached, hasLength(1));
      expect(cached.single.id, 100);
    });

    test('applies the chosen status to a fresh item', () async {
      setupWriteMocks();
      igdbByQuery['God of War'] = <Game>[_igdbGame(100, 'God of War')];

      final GameNameMatchSession session = await runMatch(<String>['God of War']);
      await sut.import(
        GameNameListImportOptions(
          rows: session.rows,
          author: 'me',
          status: ItemStatus.completed,
        ),
      );

      final List<Map<String, dynamic>> rows = verify(
        () => mockRepo.addItemsBatchReturningIds(any(), captureAny()),
      ).captured.single as List<Map<String, dynamic>>;
      expect(rows.single['status'], ItemStatus.completed.value);
      expect(rows.single['completed_at'], isNotNull);
    });

    test('refuses an empty row list', () async {
      final UniversalImportResult result = await sut.import(
        const GameNameListImportOptions(rows: <GameNameMatchRow>[], author: 'me'),
      );

      expect(result.success, isFalse);
      expect(result.fatalError, isNotNull);
    });
  });
}
