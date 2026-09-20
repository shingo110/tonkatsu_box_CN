import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/movie.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/sources/douban_movie_source.dart';

import '../../../helpers/test_helpers.dart';

final Provider<Ref> _refProvider = Provider<Ref>((Ref ref) => ref);

Map<String, Object?> _namedArgumentsOf(Invocation invocation) =>
    <String, Object?>{
      'query': invocation.namedArguments[const Symbol('query')],
      'page': invocation.namedArguments[const Symbol('page')],
    };

Movie _movie() => Movie.fromDoubanItem(<String, dynamic>{
      'id': '35267208',
      'title': '流浪地球2',
    });

void main() {
  late DoubanMovieSource source;

  setUpAll(registerAllFallbacks);

  setUp(() {
    source = DoubanMovieSource();
  });

  group('DoubanMovieSource', () {
    test('is a signing film source that only searches', () {
      expect(source.id, 'douban_movie');
      expect(source.dataSource, DataSource.douban);
      expect(source.outputMediaType, MediaType.movie);
      expect(source.supportsBrowse, isFalse);
      expect(source.supportsSortDuringSearch, isFalse);
      expect(source.filters, isEmpty);
    });

    test('offers a single relevance sort because the API takes no sort', () {
      expect(source.sortOptions, hasLength(1));
      expect(source.defaultSort.id, 'relevance');
    });

    group('fetch', () {
      late MockDoubanApi api;
      late Ref ref;
      late Map<String, Object?> lastCall;

      setUp(() {
        api = MockDoubanApi();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[doubanApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        ref = container.read(_refProvider);

        when(() => api.searchMovies(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((Invocation invocation) async {
          lastCall = _namedArgumentsOf(invocation);
          return (<Movie>[_movie()], true, 3);
        });
      });

      test('returns the page the API answered', () async {
        final BrowseResult result = await source.fetch(
          ref,
          query: '流浪地球',
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 2,
        );

        expect(result.items, hasLength(1));
        expect(result.mediaType, MediaType.movie);
        expect(result.hasMore, isTrue);
        expect(result.totalPages, 3);
        expect(result.currentPage, 2);
        expect(lastCall['query'], '流浪地球');
        expect(lastCall['page'], 2);
      });

      test('trims the keyword before sending it', () async {
        await source.fetch(
          ref,
          query: '  流浪地球2  ',
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 1,
        );

        expect(lastCall['query'], '流浪地球2');
      });

      test('does not call the API without a keyword', () async {
        final BrowseResult result = await source.fetch(
          ref,
          query: '   ',
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 1,
        );

        expect(result.items, isEmpty);
        expect(result.mediaType, MediaType.movie);
        verifyNever(() => api.searchMovies(
              query: any(named: 'query'),
              page: any(named: 'page'),
            ));
      });

      test('a null query is not a search either', () async {
        final BrowseResult result = await source.fetch(
          ref,
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 1,
        );

        expect(result.items, isEmpty);
        verifyNever(() => api.searchMovies(
              query: any(named: 'query'),
              page: any(named: 'page'),
            ));
      });
    });
  });
}
