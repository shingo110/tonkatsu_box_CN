import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/tv_show.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/sources/douban_tv_source.dart';

import '../../../helpers/test_helpers.dart';

final Provider<Ref> _refProvider = Provider<Ref>((Ref ref) => ref);

Map<String, Object?> _namedArgumentsOf(Invocation invocation) =>
    <String, Object?>{
      'query': invocation.namedArguments[const Symbol('query')],
      'page': invocation.namedArguments[const Symbol('page')],
    };

TvShow _show() => TvShow.fromDoubanItem(<String, dynamic>{
      'id': '35465232',
      'title': '狂飙',
    });

void main() {
  late DoubanTvSource source;

  setUpAll(registerAllFallbacks);

  setUp(() {
    source = DoubanTvSource();
  });

  group('DoubanTvSource', () {
    test('is a signing series source that only searches', () {
      expect(source.id, 'douban_tv');
      expect(source.dataSource, DataSource.douban);
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

        when(() => api.searchTvShows(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((Invocation invocation) async {
          lastCall = _namedArgumentsOf(invocation);
          return (<TvShow>[_show()], false, 1);
        });
      });

      test('returns the page the API answered', () async {
        final BrowseResult result = await source.fetch(
          ref,
          query: '狂飙',
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 1,
        );

        expect(result.items, hasLength(1));
        expect(result.mediaType, MediaType.tvShow);
        expect(result.hasMore, isFalse);
        expect(result.totalPages, 1);
        expect(result.currentPage, 1);
        expect(lastCall['query'], '狂飙');
      });

      test('does not call the API without a keyword', () async {
        final BrowseResult result = await source.fetch(
          ref,
          query: '',
          filterValues: const <String, Object?>{},
          sortBy: 'relevance',
          page: 1,
        );

        expect(result.items, isEmpty);
        expect(result.mediaType, MediaType.tvShow);
        verifyNever(() => api.searchTvShows(
              query: any(named: 'query'),
              page: any(named: 'page'),
            ));
      });
    });
  });
}
