import 'package:core/models/data_source.dart';
import 'package:core/models/media_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tonkatsu_box/features/search/models/search_source.dart';
import 'package:tonkatsu_box/features/search/providers/browse_provider.dart';
import 'package:tonkatsu_box/features/search/sources/search_sources.dart';
import 'package:tonkatsu_box/features/settings/providers/settings_provider.dart';
import 'package:tonkatsu_box/shared/constants/source_catalog.dart';

/// A tab must open on what this network can reach: wherever a domestic
/// provider exists, the overseas ones start switched off. Comics and games
/// have no domestic provider at all, so switching anything off there would
/// only produce a blank tab — an unreachable chip the user can see beats
/// nothing to see at all. Audio is the mixed case: its album half has a
/// domestic provider while its podcast half never will.
void main() {
  Future<ProviderContainer> containerFor(
    String mediaType, {
    Map<String, Object> extraPrefs = const <String, Object>{},
  }) async {
    SharedPreferences.setMockInitialValues(
      <String, Object>{
        BrowseSettingsKeys.mediaType: mediaType,
        ...extraPrefs,
      },
    );
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Set<String> activeIds(ProviderContainer container) => container
      .read(browseProvider)
      .activeSources
      .map((SearchSource s) => s.id)
      .toSet();

  test('books open on the two domestic providers', () async {
    final ProviderContainer container = await containerFor('book');

    expect(activeIds(container), <String>{'douban', 'weread'});
  });

  test('films open on Douban, the only domestic provider', () async {
    final ProviderContainer container = await containerFor('movie');

    expect(activeIds(container), <String>{'douban_movie'});
  });

  test('anime opens on Douban, the only domestic provider', () async {
    final ProviderContainer container = await containerFor('anime');

    expect(activeIds(container), <String>{'douban_anime'});
    expect(
      container.read(browseProvider).disabledSourceIds,
      <String>{'anilist_anime', 'bangumi_anime', 'kitsu_anime'},
    );
  });

  test('manga has no domestic provider, so nothing is switched off', () async {
    final ProviderContainer container = await containerFor('manga');

    // Hiding them would leave the tab with nothing to show at all.
    expect(container.read(browseProvider).disabledSourceIds, isEmpty);
  });

  test('audio opens on Douban for albums and keeps Podcast Index on', () async {
    // A configured Podcast Index key, so the keyless rule is not what the
    // assertion below is measuring — the region rule is.
    final ProviderContainer container = await containerFor(
      'audio',
      extraPrefs: <String, Object>{
        SettingsKeys.podcastIndexApiKey: 'key',
        SettingsKeys.podcastIndexApiSecret: 'secret',
      },
    );

    // MusicBrainz is what the domestic album catalogue stands in for, so it
    // starts off. Podcast Index is the only podcast provider there is and has
    // no domestic substitute, so it stays on — region has nothing to say about
    // a corner of the type that has no alternative route.
    expect(activeIds(container), <String>{'douban_music', 'podcastindex'});
    expect(
      container.read(browseProvider).disabledSourceIds,
      <String>{'musicbrainz'},
    );
  });

  test('every source a tab switches off is one that is hosted abroad',
      () async {
    final ProviderContainer container = await containerFor('book');
    final Set<String> disabled =
        container.read(browseProvider).disabledSourceIds;

    expect(disabled, isNotEmpty);
    for (final String id in disabled) {
      final DataSource source = getSearchSourceById(id).dataSource;

      expect(isDomesticSource(source), isFalse, reason: id);
    }
  });

  test('switching media type re-applies the rule', () async {
    final ProviderContainer container = await containerFor('manga');
    final BrowseNotifier notifier = container.read(browseProvider.notifier);

    notifier.setMediaType(MediaType.book);

    expect(activeIds(container), <String>{'douban', 'weread'});
  });
}
