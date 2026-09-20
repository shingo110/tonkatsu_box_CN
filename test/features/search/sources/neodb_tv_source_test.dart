import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/neodb_api.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/sources/neodb_tv_source.dart';

import '../../../helpers/test_helpers.dart';

final Provider<Ref> _refProvider = Provider<Ref>((Ref ref) => ref);

/// `verify(...).captured` flattens named arguments in an undocumented order,
/// and `Symbol` exposes no `name`, so the stub looks arguments up by symbol.
Map<String, Object?> _namedArgumentsOf(Invocation invocation) =>
    <String, Object?>{
      'query': invocation.namedArguments[const Symbol('query')],
      'page': invocation.namedArguments[const Symbol('page')],
    };

void main() {
  late NeoDBTvSource source;

  setUp(() {
    source = NeoDBTvSource();
  });

  group('NeoDBTvSource', () {
    test('is a keyless TV source that only searches', () {
      expect(source.id, 'neodb_tv');
      expect(source.dataSource, DataSource.neodb);
      expect(source.outputMediaType, MediaType.tvShow);
      expect(source.supportsBrowse, isFalse);
      expect(source.supportsSortDuringSearch, isFalse);
      expect(source.filters, isEmpty);
    });

    test('offers a single relevance sort because the API takes no sort', () {
      expect(source.sortOptions, hasLength(1));
      expect(source.defaultSort.id, 'relevance');
    });

    group('fetch', () {
      late MockNeoDBApi api;
      late Ref ref;
      late Map<String, Object?> lastCall;
      int calls = 0;

      setUp(() {
        calls = 0;
        api = MockNeoDBApi();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[neodbApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        ref = container.read(_refProvider);
        when(() => api.searchTvShows(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((Invocation invocation) async {
          calls++;
          lastCall = _namedArgumentsOf(invocation);
          return (
            <TvShow>[const TvShow(tmdbId: 1, title: '甄嬛传 第 1 季')],
            true,
            4,
          );
        });
      });

      Future<BrowseResult> run(
        String? query, {
        int page = 2,
      }) =>
          source.fetch(
            ref,
            query: query,
            filterValues: <String, Object?>{},
            sortBy: '',
            page: page,
          );

      test('hands the trimmed keyword and page to the API', () async {
        final BrowseResult result = await run('  甄嬛传  ');

        expect(lastCall['query'], '甄嬛传');
        expect(lastCall['page'], 2);
        expect(calls, 1);
        expect(result.items, hasLength(1));
        expect(result.mediaType, MediaType.tvShow);
        expect(result.hasMore, isTrue);
        expect(result.totalPages, 4);
        expect(result.currentPage, 2);
      });

      test('answers nothing and calls out for a one-character query', () async {
        final BrowseResult result = await run('甄');

        expect(result.items, isEmpty);
        expect(result.hasMore, isFalse);
        expect(result.totalPages, 1);
        expect(calls, 0);
      });

      test('answers nothing for a null query instead of asking for a browse',
          () async {
        final BrowseResult result = await run(null);

        expect(result.items, isEmpty);
        expect(calls, 0);
      });

      test('answers nothing for a blank keyword', () async {
        final BrowseResult result = await run('   ');

        expect(result.items, isEmpty);
        expect(calls, 0);
      });

      test('still asks when the keyword is exactly two characters', () async {
        await run('甄嬛');

        expect(calls, 1);
      });

      test('propagates the last page as hasMore false', () async {
        when(() => api.searchTvShows(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((_) async => (<TvShow>[], false, 4));

        final BrowseResult result = await run('甄嬛传', page: 4);

        expect(result.hasMore, isFalse);
        expect(result.currentPage, 4);
      });
    });
  });
}
