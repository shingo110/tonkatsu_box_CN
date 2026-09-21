import 'package:core/models/data_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/shared/constants/source_catalog.dart';

void main() {
  group('SourceInfo region', () {
    test('the domestic set is Douban, WeRead, TapTap and Ximalaya', () {
      // Pinned on purpose: adding a provider must be classified by hand, and
      // this set is where that decision becomes visible in review.
      expect(
        kDataSourceCatalog
            .where((SourceInfo info) => info.isDomestic)
            .map((SourceInfo info) => info.source)
            .toSet(),
        <DataSource>{
          DataSource.douban,
          DataSource.weread,
          DataSource.taptap,
          DataSource.ximalaya,
        },
      );
    });

    test('a source outside the catalog counts as overseas', () {
      // Nothing may assume reachability, so the fallback has to be the safe
      // half. Custom items carry the local source and never reach the network.
      expect(isDomesticSource(DataSource.local), isFalse);
      expect(sourceInfoFor(DataSource.local), isNull);
    });

    test('every entry names the bare host its client talks to', () {
      for (final SourceInfo info in kDataSourceCatalog) {
        expect(info.apiHost, isNotEmpty, reason: info.source.name);
        expect(info.apiHost, isNot(contains('/')), reason: info.source.name);
      }
    });

    test('no two providers share a host', () {
      final List<String> hosts =
          kDataSourceCatalog.map((SourceInfo info) => info.apiHost).toList();

      expect(hosts.toSet(), hasLength(hosts.length));
    });
  });
}
