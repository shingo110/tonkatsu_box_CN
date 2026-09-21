import 'package:core/models/collection.dart';
import 'package:core/models/collection_item.dart';
import 'package:core/models/data_source.dart';
import 'package:core/models/game.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/item_status_logic.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/universal_import_result.dart';
import 'package:core/models/wishlist_tag.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../../data/repositories/collection_repository.dart';
import '../../../../data/repositories/wishlist_repository.dart';
import '../../../api/api_error_extract.dart';
import '../../../api/igdb_api.dart';
import '../../../api/taptap_api.dart';
import '../../../database/database_service.dart';
import '../../import_columns.dart';
import '../../import_progress.dart';
import '../../import_source.dart';
import '../../import_writer.dart';
import 'game_title_matcher.dart';

final Provider<GameNameListImportService> gameNameListImportServiceProvider =
    Provider<GameNameListImportService>((Ref ref) {
  return GameNameListImportService(
    igdbApi: ref.watch(igdbApiProvider),
    tapTapApi: ref.watch(tapTapApiProvider),
    database: ref.watch(databaseServiceProvider),
    repository: ref.watch(collectionRepositoryProvider),
    wishlistRepository: ref.watch(wishlistRepositoryProvider),
  );
});

/// One catalogue row offered for a pasted name, carrying its own confidence.
class GameNameCandidate {
  const GameNameCandidate({
    required this.game,
    required this.source,
    required this.score,
  });

  final Game game;

  /// Catalogue this row came from — decided at match time because the write
  /// side needs it to stamp `collection_items.source`.
  final DataSource source;

  /// 0-100, see [GameTitleMatcher.score].
  final int score;

  MatchQuality get quality => GameTitleMatcher.qualityOf(score);
}

/// One pasted name, its catalogued candidates and the user's pick.
///
/// [selectedIndex] is mutable on purpose: the preview screen rewrites it as the
/// user accepts a different candidate, or skips the row entirely.
class GameNameMatchRow {
  GameNameMatchRow({
    required this.original,
    required this.candidates,
    required this.selectedIndex,
    this.searchFailed = false,
  });

  /// The name as the user's list spelled it, before any normalization.
  final String original;

  /// Ranked best-first; empty when no catalogue knew the title.
  final List<GameNameCandidate> candidates;

  /// Index into [candidates], or `-1` for "do not import this row".
  int selectedIndex;

  /// True when a lookup threw, as opposed to finding nothing — the two read
  /// very differently in a preview list.
  final bool searchFailed;

  bool get isSelected =>
      selectedIndex >= 0 && selectedIndex < candidates.length;

  GameNameCandidate? get selected =>
      isSelected ? candidates[selectedIndex] : null;

  MatchQuality get quality => selected?.quality ?? MatchQuality.none;
}

/// Outcome of the matching pass: one row per input name, in input order.
class GameNameMatchSession {
  const GameNameMatchSession({required this.rows});

  final List<GameNameMatchRow> rows;

  int get selectedCount =>
      rows.where((GameNameMatchRow r) => r.isSelected).length;

  int get unmatchedCount => rows.length - selectedCount;
}

class GameNameListImportOptions extends ImportOptions {
  const GameNameListImportOptions({
    required this.rows,
    required this.author,
    this.platformId,
    this.status = ItemStatus.notStarted,
    this.wishlistReason,
    super.collectionId,
  });

  /// The preview rows as the user left them; unselected ones become wishlist
  /// entries rather than being silently dropped.
  final List<GameNameMatchRow> rows;

  final String author;

  /// Stamped on every item. Optional on purpose: a library listing carries no
  /// per-game platform, and a machine that never synced IGDB has no platform
  /// table to pick from — leaving it null still imports, the rows just read as
  /// an unknown platform.
  final int? platformId;

  /// Applied to every matched game — a library list carries no status either.
  final ItemStatus status;

  final String? wishlistReason;
}

/// Imports a plain list of game names: the "paste your PlayStation library"
/// path, which needs no account, no OAuth and no network beyond the two
/// catalogues the app already ships with.
///
/// Two phases by design. [match] queries both catalogues and returns what it
/// found **without touching the database**, so the user can correct mismatches
/// and skip rows first; [import] writes only what survived that review.
class GameNameListImportService implements ImportSource {
  GameNameListImportService({
    required IgdbApi igdbApi,
    required TapTapApi tapTapApi,
    required DatabaseService database,
    required CollectionRepository repository,
    required WishlistRepository wishlistRepository,
  })  : _igdbApi = igdbApi,
        _tapTapApi = tapTapApi,
        _db = database,
        _writer = ImportWriter(
          collections: repository,
          wishlist: wishlistRepository,
        );

  static final Logger _log = Logger('GameNameListImportService');

  /// Every row is a game, so one label covers the collection name and the
  /// wishlist tag.
  static const String sourceLabel = 'Game List';

  final IgdbApi _igdbApi;
  final TapTapApi _tapTapApi;
  final DatabaseService _db;
  final ImportWriter _writer;

  @override
  String get displayName => sourceLabel;

  /// Phase one: look every name up, write nothing.
  Future<GameNameMatchSession> match(
    List<String> names, {
    int? platformId,
    ImportProgressCallback? onProgress,
  }) async {
    final int total = names.length;
    final Map<int, List<GameNameCandidate>> found =
        <int, List<GameNameCandidate>>{};
    final Set<int> failedSearch = <int>{};

    // A Chinese title only exists in the Chinese catalogue and a Latin one
    // almost never does, so splitting first keeps the request count near one
    // per name instead of asking both catalogues about everything.
    final List<int> latin = <int>[];
    final List<int> han = <int>[];
    for (int i = 0; i < total; i++) {
      (GameTitleMatcher.hasHan(names[i]) ? han : latin).add(i);
    }

    // Counted per *name* and never twice, so `done` cannot overshoot `total`:
    // the progress bar is fed straight into LinearProgressIndicator.
    int done = 0;
    void report(String? message) {
      onProgress?.call(ImportProgress(
        stage: ImportStage.fetchingGames,
        current: done,
        total: total,
        message: message,
      ));
    }

    report(null);

    if (latin.isNotEmpty) {
      await _collectFromIgdb(
        names,
        latin,
        found,
        failedSearch,
        platformId: platformId,
        onBatch: (int processed) {
          done += processed;
          report('Matching with IGDB...');
        },
      );
    }

    if (han.isNotEmpty) {
      await _collectFromTapTap(
        names,
        han,
        found,
        failedSearch,
        platformId: platformId,
        onEach: () {
          done++;
          report('Matching with TapTap...');
        },
        merge: false,
      );
    }

    // A Latin title IGDB does not carry — mainland indie releases, mobile
    // ports — often has a TapTap row, so retry the ones that came back empty
    // or unconvincing. Those names are already counted, hence no progress
    // callback here; only the message moves.
    final List<int> latinFallback = <int>[
      for (final int position in latin)
        if (_needsFallback(found[position])) position,
    ];
    if (latinFallback.isNotEmpty) {
      report('Checking TapTap for the rest...');
      await _collectFromTapTap(
        names,
        latinFallback,
        found,
        failedSearch,
        platformId: platformId,
        onEach: null,
        merge: true,
      );
    }

    final List<GameNameMatchRow> rows = <GameNameMatchRow>[];
    for (int i = 0; i < total; i++) {
      final List<GameNameCandidate> candidates =
          found[i] ?? const <GameNameCandidate>[];
      rows.add(GameNameMatchRow(
        original: names[i],
        candidates: candidates,
        selectedIndex: _preselect(candidates),
        searchFailed: failedSearch.contains(i),
      ));
    }

    _log.info('Name list matched ${rows.where((GameNameMatchRow r) => r.isSelected).length}'
        ' of $total names');
    return GameNameMatchSession(rows: rows);
  }

  /// Phase two: write the reviewed selection, wishlist everything left over.
  @override
  Future<UniversalImportResult> import(
    covariant GameNameListImportOptions options, {
    ImportProgressCallback? onProgress,
  }) async {
    try {
      final List<GameNameMatchRow> rows = options.rows;
      if (rows.isEmpty) {
        return UniversalImportResult.failure(
          sourceName: displayName,
          error: 'No names to import',
        );
      }

      final List<GameNameCandidate> chosen = <GameNameCandidate>[];
      final List<String> leftover = <String>[];
      for (final GameNameMatchRow row in rows) {
        final GameNameCandidate? picked = row.selected;
        if (picked == null) {
          leftover.add(row.original);
        } else {
          chosen.add(picked);
        }
      }

      onProgress?.call(const ImportProgress(
        stage: ImportStage.cachingMedia,
        current: 0,
        total: 1,
        message: 'Caching game data...',
      ));

      await _upsertGames(chosen);

      onProgress?.call(const ImportProgress(
        stage: ImportStage.cachingMedia,
        current: 1,
        total: 1,
      ));

      // Created only after matching succeeded, so a failed run leaves no empty
      // collection behind.
      final Collection? collection = await _writer.resolveCollection(
        collectionId: options.collectionId,
        newCollectionName: displayName,
        author: options.author,
      );
      if (collection == null) {
        return UniversalImportResult.failure(
          sourceName: displayName,
          error: 'Collection not found',
        );
      }

      final ImportWriteResult write = await _writer.writeItems(
        collectionId: collection.id,
        candidates: <ImportCandidate>[
          for (final GameNameCandidate candidate in chosen)
            _candidate(candidate, options),
        ],
        onItem: (int processed, int total, int imported, int updated,
            String? label) {
          onProgress?.call(ImportProgress(
            stage: ImportStage.addingItems,
            current: processed,
            total: total,
            currentItem: label,
            imported: imported,
            updated: updated,
            wishlisted: leftover.length,
          ));
        },
      );

      final Map<MediaType, int> wishlistedByType = await _writer.writeWishlist(
        entries: <WishlistCandidate>[
          for (final String name in leftover)
            WishlistCandidate(
              text: name,
              mediaType: MediaType.game,
              note: options.wishlistReason,
            ),
        ],
        tag: buildImportTag(displayName),
      );

      onProgress?.call(ImportProgress(
        stage: ImportStage.completed,
        current: 1,
        total: 1,
        imported: write.importedByType[MediaType.game] ?? 0,
        updated: write.updatedByType[MediaType.game] ?? 0,
        wishlisted: wishlistedByType[MediaType.game] ?? 0,
      ));

      return UniversalImportResult(
        sourceName: displayName,
        success: true,
        collection: collection,
        importedByType: write.importedByType,
        updatedByType: write.updatedByType,
        wishlistedByType: wishlistedByType,
        skipped: write.skipped,
      );
    } on Exception catch (e) {
      final ApiError err = extractApiError(e);
      return UniversalImportResult.failure(
        sourceName: displayName,
        error: 'Import failed: ${err.message}',
        detail: err.detail,
      );
    }
  }

  /// Batched by the API's own multi-query ceiling.
  Future<void> _collectFromIgdb(
    List<String> names,
    List<int> positions,
    Map<int, List<GameNameCandidate>> into,
    Set<int> failedSearch, {
    required int? platformId,
    required void Function(int processed) onBatch,
  }) async {
    const int batchSize = IgdbApi.maxMultiQueryBatch;

    for (int start = 0; start < positions.length; start += batchSize) {
      final int end = start + batchSize > positions.length
          ? positions.length
          : start + batchSize;
      final List<int> batch = positions.sublist(start, end);

      try {
        // No platform filter: IGDB's coverage is incomplete for remasters and
        // a hard `platforms = (167)` silently loses the title. The platform
        // only breaks score ties, in _sortCandidates.
        final Map<int, List<Game>> results =
            await _igdbApi.multiSearchGamesByName(
          <({String name, int? platformId})>[
            for (final int position in batch)
              (name: names[position], platformId: null),
          ],
        );

        for (int i = 0; i < batch.length; i++) {
          final List<Game> games = results[i] ?? const <Game>[];
          if (games.isEmpty) continue;
          _merge(
            positions: into,
            position: batch[i],
            incoming: _rank(
              names[batch[i]],
              games,
              DataSource.igdb,
              platformId,
            ),
            platformId: platformId,
          );
        }
      } on Exception catch (e) {
        _log.warning('IGDB batch match failed: $e');
        failedSearch.addAll(batch);
      }

      onBatch(batch.length);
    }
  }

  /// One request per name; the shared host limiter paces them.
  Future<void> _collectFromTapTap(
    List<String> names,
    List<int> positions,
    Map<int, List<GameNameCandidate>> into,
    Set<int> failedSearch, {
    required int? platformId,
    required void Function()? onEach,
    required bool merge,
  }) async {
    for (final int position in positions) {
      try {
        final List<Game> games =
            (await _tapTapApi.searchGames(query: names[position], page: 1)).$1;
        if (games.isNotEmpty) {
          final List<GameNameCandidate> ranked =
              _rank(names[position], games, DataSource.taptap, platformId);
          if (merge) {
            _merge(
              positions: into,
              position: position,
              incoming: ranked,
              platformId: platformId,
            );
          } else {
            into[position] = ranked;
          }
        }
      } on Exception catch (e) {
        _log.warning('TapTap match failed for "${names[position]}": $e');
        failedSearch.add(position);
      }
      onEach?.call();
    }
  }

  /// Appends [incoming] to whatever the position already holds, dropping rows
  /// the other catalogue already supplied, then re-ranks the union.
  static void _merge({
    required Map<int, List<GameNameCandidate>> positions,
    required int position,
    required List<GameNameCandidate> incoming,
    required int? platformId,
  }) {
    final List<GameNameCandidate> existing =
        positions[position] ?? <GameNameCandidate>[];
    final Set<String> seen = <String>{
      for (final GameNameCandidate candidate in existing)
        '${candidate.source.name}:${candidate.game.id}',
    };
    for (final GameNameCandidate candidate in incoming) {
      if (seen.add('${candidate.source.name}:${candidate.game.id}')) {
        existing.add(candidate);
      }
    }
    _sortCandidates(existing, platformId);
    positions[position] = existing;
  }

  static List<GameNameCandidate> _rank(
    String query,
    List<Game> games,
    DataSource source,
    int? platformId,
  ) {
    final List<GameNameCandidate> ranked = <GameNameCandidate>[
      for (final Game game in games)
        GameNameCandidate(
          game: game,
          source: source,
          score: GameTitleMatcher.score(query, game.name),
        ),
    ];
    _sortCandidates(ranked, platformId);
    return ranked;
  }

  /// Confidence first, then the target platform, then id — the last one only
  /// to keep the order deterministic, since `List.sort` is not stable.
  static void _sortCandidates(
    List<GameNameCandidate> candidates,
    int? platformId,
  ) {
    candidates.sort((GameNameCandidate a, GameNameCandidate b) {
      final int byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      if (platformId != null) {
        final bool onPlatformA =
            a.game.platformIds?.contains(platformId) ?? false;
        final bool onPlatformB =
            b.game.platformIds?.contains(platformId) ?? false;
        if (onPlatformA != onPlatformB) return onPlatformB ? 1 : -1;
      }
      return a.game.id.compareTo(b.game.id);
    });
  }

  /// Nothing came back, or nothing convincing enough to show as the answer.
  static bool _needsFallback(List<GameNameCandidate>? candidates) {
    if (candidates == null || candidates.isEmpty) return true;
    return candidates.first.score < GameTitleMatcher.confidentScore;
  }

  /// Candidates arrive ranked, so a confident head is the default pick; a weak
  /// head preselects nothing and lands in the wishlist unless the user chooses.
  static int _preselect(List<GameNameCandidate> candidates) {
    if (candidates.isEmpty) return -1;
    return candidates.first.score >= GameTitleMatcher.confidentScore ? 0 : -1;
  }

  Future<void> _upsertGames(List<GameNameCandidate> chosen) async {
    if (chosen.isEmpty) return;
    final Map<String, Game> byKey = <String, Game>{
      for (final GameNameCandidate candidate in chosen)
        '${candidate.source.name}:${candidate.game.id}': candidate.game,
    };
    await _db.gameDao.upsertGames(byKey.values.toList());
  }

  ImportCandidate _candidate(
    GameNameCandidate candidate,
    GameNameListImportOptions options,
  ) {
    return ImportCandidate(
      mediaType: MediaType.game,
      externalId: candidate.game.id,
      platformId: options.platformId,
      // Must mirror insertRow's `source` column, or a re-import cannot find
      // the row it wrote (see ImportCandidate.source).
      source: candidate.source,
      label: candidate.game.name,
      insertRow: _insertRow(candidate, options),
      changedFields: (CollectionItem existing) =>
          _changedFields(options, existing),
    );
  }

  Map<String, dynamic> _insertRow(
    GameNameCandidate candidate,
    GameNameListImportOptions options,
  ) {
    final Map<String, dynamic> row = <String, dynamic>{
      'media_type': MediaType.game.value,
      'external_id': candidate.game.id,
      'platform_id': options.platformId,
      'source': candidate.source.name,
      'status': options.status.value,
    };

    if (options.status != ItemStatus.notStarted) {
      final StatusDatesUpdate dates = computeDatesForStatus(
        newStatus: options.status,
        currentStartedAt: null,
        currentCompletedAt: null,
        now: DateTime.now(),
      );
      row['started_at'] = epochSeconds(dates.startedAt);
      row['completed_at'] = epochSeconds(dates.completedAt);
      row['last_activity_at'] = epochSeconds(dates.lastActivityAt);
    }

    return row;
  }

  /// Same merge rule as every other importer: an unset status leaves an
  /// existing item alone, a chosen one only ever moves it upward.
  Map<String, dynamic> _changedFields(
    GameNameListImportOptions options,
    CollectionItem existing,
  ) {
    if (options.status == ItemStatus.notStarted) {
      return const <String, dynamic>{};
    }
    final ItemStatus? merged = mergeExternalStatus(
      currentStatus: existing.status,
      externalStatus: options.status,
    );
    if (merged == null) return const <String, dynamic>{};
    return statusDateColumns(merged, existing);
  }
}
