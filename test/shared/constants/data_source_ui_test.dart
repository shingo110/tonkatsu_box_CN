import 'dart:io';

import 'package:core/models/data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/shared/constants/data_source_ui.dart';

/// The domestic sources that arrive without upstream artwork, so each one has
/// to be given a mark of its own (see `tool/brand_icons`).
const List<DataSource> _domestic = <DataSource>[
  DataSource.taptap,
  DataSource.bangumi,
  DataSource.neodb,
  DataSource.weread,
  DataSource.douban,
  DataSource.ximalaya,
];

void main() {
  group('DataSourceUi.iconAsset', () {
    test('every domestic source carries a brand mark', () {
      for (final DataSource source in _domestic) {
        expect(
          source.iconAsset,
          isNotNull,
          reason: '${source.name} would fall back to a lettered monogram',
        );
      }
    });

    test('every declared asset is present in the tree', () {
      final List<String> absent = <String>[];
      for (final DataSource source in DataSource.values) {
        final String? asset = source.iconAsset;
        if (asset == null) continue;
        if (!File(asset).existsSync()) {
          absent.add('${source.name} -> $asset');
        }
      }
      expect(
        absent,
        isEmpty,
        reason: 'declared but missing: ${absent.join(', ')}',
      );
    });

    test('the sources left without a mark are the upstream ones', () {
      final Set<DataSource> bare = <DataSource>{
        for (final DataSource source in DataSource.values)
          if (source.iconAsset == null) source,
      };
      expect(bare, <DataSource>{DataSource.vgMaps, DataSource.local});
    });
  });
}
