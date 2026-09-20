import 'package:core/models/book.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tonkatsu_box/core/api/douban_api.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/sources/douban_book_source.dart';

import '../../../helpers/test_helpers.dart';

final Provider<Ref> _refProvider = Provider<Ref>((Ref ref) => ref);

Map<String, Object?> _namedArgumentsOf(Invocation invocation) =>
    <String, Object?>{
      'query': invocation.namedArguments[const Symbol('query')],
      'page': invocation.namedArguments[const Symbol('page')],
    };

void main() {
  late DoubanBookSource source;

  setUpAll(registerAllFallbacks);

  setUp(() {
    source = DoubanBookSource();
  });

  group('DoubanBookSource', () {
    test('is a signing book source that only searches', () {
      expect(source.id, 'douban');
      expect(source.dataSource, DataSource.douban);
      expect(source.outputMediaType, MediaType.book);
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
      int searches = 0;
      int isbnLookups = 0;

      setUp(() {
        searches = 0;
        isbnLookups = 0;
        api = MockDoubanApi();
        final ProviderContainer container = ProviderContainer(
          overrides: <Override>[doubanApiProvider.overrideWithValue(api)],
        );
        addTearDown(container.dispose);
        ref = container.read(_refProvider);

        when(() => api.searchBooks(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((Invocation invocation) async {
          searches++;
          lastCall = _namedArgumentsOf(invocation);
          return (<Book>[createTestBook()], true, 14);
        });
        when(() => api.getBookByIsbn(any())).thenAnswer((_) async {
          isbnLookups++;
          return createTestBook();
        });
      });

      Future<BrowseResult> run(String? query, {int page = 2}) => source.fetch(
            ref,
            query: query,
            filterValues: <String, Object?>{},
            sortBy: '',
            page: page,
          );

      test('hands the trimmed keyword and page to the API', () async {
        final BrowseResult result = await run('  三体  ');

        expect(lastCall['query'], '三体');
        expect(lastCall['page'], 2);
        expect(searches, 1);
        expect(result.items, hasLength(1));
        expect(result.mediaType, MediaType.book);
        expect(result.hasMore, isTrue);
        expect(result.totalPages, 14);
        expect(result.currentPage, 2);
      });

      test('routes an ISBN to the by-ISBN endpoint instead of a search',
          () async {
        final BrowseResult result = await run('978-7-5366-9293-0');

        expect(isbnLookups, 1);
        expect(searches, 0);
        expect(result.items, hasLength(1));
        expect(result.currentPage, 1);
      });

      test('recognises a bare ISBN-13 too', () async {
        await run('9787536692930');

        expect(isbnLookups, 1);
        expect(searches, 0);
      });

      test('treats a 10-digit title-like query as an ISBN-10', () async {
        await run('7536692935');

        expect(isbnLookups, 1);
      });

      test('answers nothing when the ISBN is unknown', () async {
        when(() => api.getBookByIsbn(any())).thenAnswer((_) async => null);

        final BrowseResult result = await run('9787536692930');

        expect(result.items, isEmpty);
        expect(result.hasMore, isFalse);
      });

      test('answers nothing for a null query instead of browsing', () async {
        final BrowseResult result = await run(null);

        expect(result.items, isEmpty);
        expect(searches, 0);
        expect(isbnLookups, 0);
      });

      test('answers nothing for a blank keyword', () async {
        final BrowseResult result = await run('   ');

        expect(result.items, isEmpty);
        expect(searches, 0);
      });

      test('propagates the last page as hasMore false', () async {
        when(() => api.searchBooks(
              query: any(named: 'query'),
              page: any(named: 'page'),
            )).thenAnswer((_) async => (<Book>[], false, 14));

        final BrowseResult result = await run('三体');

        expect(result.hasMore, isFalse);
      });
    });
  });
}
