import 'package:core/models/anime.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/bangumi_api.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/sources/bangumi_anime_source.dart';

import '../../../helpers/test_helpers.dart';

final Provider<Ref> _refProvider = Provider<Ref>((Ref ref) => ref);

/// Named arguments `BangumiAnimeSource` is expected to hand to the API.
const List<String> _apiArgumentNames = <String>[
  'query',
  'metaTags',
  'airDate',
  'rating',
  'rank',
  'sort',
  'page',
  'perPage',
];

/// `verify(...).captured` flattens named arguments in an undocumented order,
/// and `Symbol` exposes no `name`, so the stub looks arguments up by symbol.
Map<String, Object?> _namedArgumentsOf(Invocation invocation) =>
    <String, Object?>{
      for (final String name in _apiArgumentNames)
        name: invocation.namedArguments[Symbol(name)],
    };

void main() {
  late BangumiAnimeSource source;

  setUp(() {
    source = BangumiAnimeSource();
  });

  group('BangumiAnimeSource', () {
    test('is a keyless bangumi source serving the anime type', () {
      expect(source.id, 'bangumi_anime');
      expect(source.dataSource, DataSource.bangumi);
      expect(source.outputMediaType, MediaType.anime);
      expect(source.supportsBrowse, isTrue);
      expect(source.supportsSortDuringSearch, isTrue);
    });

    group('filters', () {
      test('exposes category, year, minimum rating and rank', () {
        expect(
          source.filters.map((SearchFilter f) => f.key).toList(),
          <String>['metaTags', 'year', 'minRating', 'maxRank'],
        );
      });

      test('only the category filter is multi-select', () {
        final List<SearchFilter> multi =
            source.filters.where((SearchFilter f) => f.multiSelect).toList();

        expect(multi, hasLength(1));
        expect(multi.single.key, 'metaTags');
      });
    });

    group('sort options', () {
      test('offers match, rank and heat with match first', () {
        expect(
          source.sortOptions.map((BrowseSortOption o) => o.apiValue).toList(),
          <String>['match', 'rank', 'heat'],
        );
        expect(source.defaultSort.apiValue, 'match');
      });
    });

    group('fetch', () {
      late MockBangumiApi api;
      late Ref ref;
      late Invocation lastInvocation;

      setUp(() {
        api = MockBangumiApi();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[bangumiApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        ref = container.read(_refProvider);
        when(() => api.browseAnime(
              query: any(named: 'query'),
              metaTags: any(named: 'metaTags'),
              airDate: any(named: 'airDate'),
              rating: any(named: 'rating'),
              rank: any(named: 'rank'),
              sort: any(named: 'sort'),
              page: any(named: 'page'),
              perPage: any(named: 'perPage'),
            )).thenAnswer((Invocation invocation) async {
          lastInvocation = invocation;
          return (<Anime>[createTestAnime(id: 1)], true, 5);
        });
      });

      /// Runs one fetch and returns the named arguments handed to the API.
      Future<Map<String, Object?>> capture(
        Map<String, Object?> filterValues, {
        String? query,
        String sortBy = 'match',
        int page = 2,
      }) async {
        await source.fetch(
          ref,
          query: query,
          filterValues: filterValues,
          sortBy: sortBy,
          page: page,
        );
        return _namedArgumentsOf(lastInvocation);
      }

      test('hands the API every documented argument', () async {
        await capture(<String, Object?>{});

        // The VM materialises untouched optional named parameters too (e.g.
        // `tags`), so only assert that every argument we care about is there.
        expect(
          lastInvocation.namedArguments.keys.toSet(),
          containsAll(_apiArgumentNames.map((String name) => Symbol(name))),
        );
      });

      test('returns the page with the anime media type', () async {
        final BrowseResult result = await source.fetch(
          ref,
          filterValues: <String, Object?>{},
          sortBy: 'match',
          page: 2,
        );

        expect(result.items, hasLength(1));
        expect(result.mediaType, MediaType.anime);
        expect(result.hasMore, isTrue);
        expect(result.totalPages, 5);
        expect(result.currentPage, 2);
      });

      test('sends the page number and the 20-item page size', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{}, page: 3);

        expect(args['page'], 3);
        expect(args['perPage'], 20);
      });

      test('turns a year selection into a one-year air_date range', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'year': 2020});

        expect(args['airDate'], <String>['>=2020-01-01', '<2021-01-01']);
      });

      test('turns a decade tuple into an inclusive-span range', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'year': (2000, 2009)});

        expect(args['airDate'], <String>['>=2000-01-01', '<2010-01-01']);
      });

      test('omits air_date when no year is selected', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'year': null});

        expect(args['airDate'], isNull);
      });

      test('formats the minimum rating without a trailing .0', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'minRating': 8.0});

        expect(args['rating'], <String>['>=8']);
      });

      test('keeps a fractional rating bound as-is', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'minRating': 7.5});

        expect(args['rating'], <String>['>=7.5']);
      });

      test('omits the rating bound when none is selected', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'minRating': null});

        expect(args['rating'], isNull);
      });

      test('turns a rank floor into a 1..floor range', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'maxRank': 500});

        expect(args['rank'], <String>['>=1', '<=500']);
      });

      test('omits the rank range when no floor is selected', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{'maxRank': null});

        expect(args['rank'], isNull);
      });

      test('forwards the category selection', () async {
        final Map<String, Object?> args = await capture(<String, Object?>{
          'metaTags': <String>['TV', '日本'],
        });

        expect(args['metaTags'], <String>['TV', '日本']);
      });

      test('sends no category when nothing is selected', () async {
        final Map<String, Object?> args = await capture(<String, Object?>{});

        expect(args['metaTags'], isNull);
      });

      test('keeps match while a query is active', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{}, query: '巨人');

        expect(args['query'], '巨人');
        expect(args['sort'], 'match');
      });

      test('falls back to the ranking when browsing without a query', () async {
        final Map<String, Object?> args = await capture(<String, Object?>{});

        expect(args['query'], isNull);
        expect(args['sort'], 'rank');
      });

      test('treats a blank query as no query', () async {
        final Map<String, Object?> args =
            await capture(<String, Object?>{}, query: '   ');

        expect(args['sort'], 'rank');
      });

      test('passes a chosen sort through untouched', () async {
        final Map<String, Object?> args = await capture(
          <String, Object?>{},
          query: '巨人',
          sortBy: 'heat',
        );

        expect(args['sort'], 'heat');
      });

      test('propagates a source failure', () async {
        when(() => api.browseAnime(
              query: any(named: 'query'),
              metaTags: any(named: 'metaTags'),
              airDate: any(named: 'airDate'),
              rating: any(named: 'rating'),
              rank: any(named: 'rank'),
              sort: any(named: 'sort'),
              page: any(named: 'page'),
              perPage: any(named: 'perPage'),
            )).thenThrow(const BangumiApiException('boom'));

        await expectLater(
          source.fetch(
            ref,
            filterValues: <String, Object?>{},
            sortBy: 'match',
            page: 1,
          ),
          throwsA(isA<BangumiApiException>()),
        );
      });
    });
  });
}
