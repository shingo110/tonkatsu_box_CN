import 'package:core/models/tv_episode.dart';
import 'package:core/models/tv_season.dart';
import 'package:core/models/tv_show.dart';

import '../douban_api.dart';
import 'tv_episode_source.dart';

/// [TvEpisodeSource] backed by Douban.
///
/// Only [getShow] does any work: it lets the cache warmer replace a thin
/// search row with the full record, which is where the synopsis lives. Douban
/// files a series as one subject with no season split and exposes no episode
/// list, so seasons and episodes stay empty rather than being invented.
///
/// Leaving this unregistered is worse than a missing feature — the resolver
/// falls back to TMDB, which then spends a Douban id on an unrelated show and
/// writes that record into the cache.
class DoubanEpisodeSource implements TvEpisodeSource {
  DoubanEpisodeSource(this._api);

  final DoubanApi _api;

  @override
  Future<TvShow?> getShow(int showId) => _api.getTvShow('$showId');

  @override
  Future<List<TvSeason>> getSeasons(int showId) =>
      Future<List<TvSeason>>.value(const <TvSeason>[]);

  @override
  Future<List<TvEpisode>> getSeasonEpisodes(int showId, int seasonNumber) =>
      Future<List<TvEpisode>>.value(const <TvEpisode>[]);
}
