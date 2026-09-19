import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Bangumi's curated meta tags for the anime subject type. They mix format,
/// origin and adaptation source — Bangumi's own idea of a category axis; the
/// free-form tag cloud is not exposed for filtering without an account.
const List<String> _bangumiMetaTags = <String>[
  'TV',
  'WEB',
  'OVA',
  '剧场版',
  '原创',
  '漫画改',
  '小说改',
  '游戏改',
  '动画改',
  '日本',
  '中国',
  '欧美',
];

/// Bangumi `meta_tags` filter. Sent as one `meta_tags[]` array, which Bangumi
/// ANDs together.
class BangumiMetaTagFilter extends SearchFilter {
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
      for (final String tag in _bangumiMetaTags)
        FilterOption(id: tag, label: tag, value: tag),
    ];
  }
}
