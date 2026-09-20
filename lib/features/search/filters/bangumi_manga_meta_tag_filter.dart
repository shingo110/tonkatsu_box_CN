import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Bangumi's curated meta tags for the book subject type. They describe
/// origin, serialisation, audience and adaptation source — a different axis
/// set from the anime tab's, which is why the two sources do not share a list.
///
/// 漫画 itself is absent on purpose: the API client pins it on every request,
/// since a `type: [1]` search without it returns novels and picture books. The
/// list is ANDed, so these narrow within comics rather than widening past them.
const List<String> _bangumiMangaMetaTags = <String>[
  '日本',
  '韩国',
  '中国',
  '香港',
  '台湾',
  '连载中',
  '已完结',
  '少年',
  '少女',
  '一般向',
  '原创',
  '小说改',
  '影视改',
];

/// Bangumi `meta_tags` filter, manga tab.
class BangumiMangaMetaTagFilter extends SearchFilter {
  @override
  String get key => 'metaTags';

  @override
  bool get multiSelect => true;

  @override
  String placeholder(S l) => l.browseFilterCategory;

  @override
  FilterOption get allOption => const FilterOption(
        id: 'any',
        label: 'All',
        value: null,
      );

  @override
  Future<List<FilterOption>> options(WidgetRef ref, S l) async {
    return <FilterOption>[
      for (final String tag in _bangumiMangaMetaTags)
        FilterOption(id: tag, label: tag, value: tag),
    ];
  }
}
