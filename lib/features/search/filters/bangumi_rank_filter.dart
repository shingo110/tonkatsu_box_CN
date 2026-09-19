import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import '../../../l10n/app_localizations.dart';
import '../models/search_source.dart';

/// Ranking floors offered by the filter. 1000 is roughly the cut where a title
/// stops being "widely seen"; below 100 the field is too thin to browse.
const List<int> _bangumiRankFloors = <int>[100, 300, 500, 1000];

/// Bangumi community-ranking filter (`filter.rank`). A relative axis: unlike
/// the score it says "well-regarded among everything on the site".
class BangumiRankFilter extends SearchFilter {
  @override
  String get key => 'maxRank';

  @override
  String placeholder(S l) => l.browseFilterMaxRank;

  @override
  FilterOption get allOption => const FilterOption(
        id: 'any',
        label: 'All',
        value: null,
      );

  @override
  Future<List<FilterOption>> options(WidgetRef ref, S l) async {
    return <FilterOption>[
      for (final int rank in _bangumiRankFloors)
        FilterOption(id: '$rank', label: 'Top $rank', value: rank),
    ];
  }
}
