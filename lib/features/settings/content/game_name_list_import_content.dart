import 'package:core/models/collection.dart';
import 'package:core/models/item_status.dart';
import 'package:core/models/media_type.dart';
import 'package:core/models/platform.dart' as model;
import 'package:core/models/universal_import_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_service.dart';
import '../../../core/import/import_progress.dart';
import '../../../core/import/sources/name_list/game_name_list_import_service.dart';
import '../../../core/import/sources/name_list/game_title_matcher.dart';
import '../../../core/import/sources/name_list/name_list_parser.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/collection_picker_field.dart';
import '../../collections/providers/canvas_provider.dart';
import '../../collections/providers/collection_covers_provider.dart';
import '../../collections/providers/collections_provider.dart';
import '../../collections/widgets/status_chip_row.dart';
import '../../home/providers/all_items_provider.dart';
import '../../search/models/search_source.dart';
import '../../search/utils/filter_ui.dart';
import '../../search/widgets/filter_dropdown.dart';
import '../../wishlist/providers/wishlist_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/import_result_screen.dart';
import '../widgets/settings_group.dart';

/// IGDB's own id for the PlayStation 5, used only to preselect the platform.
const int _kPlayStation5PlatformId = 167;

/// Which half of the flow the screen is showing.
enum _Stage { input, review }

/// Flow: paste a list of game names → match against both game catalogues →
/// review and correct every match → import.
///
/// The review step is the point of the whole screen: name matching is
/// inherently lossy, so nothing is written until the user has seen what each
/// line resolved to and had the chance to skip or replace it.
class GameNameListImportContent extends ConsumerStatefulWidget {
  const GameNameListImportContent({super.key});

  @override
  ConsumerState<GameNameListImportContent> createState() =>
      _GameNameListImportContentState();
}

class _GameNameListImportContentState
    extends ConsumerState<GameNameListImportContent> {
  final TextEditingController _controller = TextEditingController();

  _Stage _stage = _Stage.input;
  List<String> _parsed = const <String>[];
  GameNameMatchSession? _session;

  ItemStatus _status = ItemStatus.notStarted;
  int? _platformId;
  String? _platformName;
  bool _useNewCollection = true;
  int? _selectedCollectionId;

  List<model.Platform> _platforms = <model.Platform>[];
  bool _platformsLoaded = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reparse);
    _loadPlatforms();
  }

  @override
  void dispose() {
    _controller.removeListener(_reparse);
    _controller.dispose();
    super.dispose();
  }

  void _reparse() {
    final List<String> parsed = NameListParser.parse(_controller.text);
    if (parsed.length == _parsed.length) return;
    setState(() => _parsed = parsed);
  }

  void _loadPlatforms() {
    final DatabaseService db = ref.read(databaseServiceProvider);
    db.gameDao.getAllPlatforms().then((List<model.Platform> platforms) {
      if (!mounted) return;
      platforms.sort(
        (model.Platform a, model.Platform b) => a.name.compareTo(b.name),
      );
      final model.Platform? ps5 = platforms
          .where((model.Platform p) => p.id == _kPlayStation5PlatformId)
          .firstOrNull;
      setState(() {
        _platforms = platforms;
        _platformsLoaded = true;
        // A PlayStation library is overwhelmingly a PS5 one, so the platform
        // picker starts there instead of empty.
        if (ps5 != null && _platformId == null) {
          _platformId = ps5.id;
          _platformName = _platformLabel(ps5);
        }
      });
    });
  }

  bool get _igdbConnected =>
      ref.read(settingsNotifierProvider).connectionStatus ==
      ConnectionStatus.connected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (!_igdbConnected) ...<Widget>[
          _buildIgdbWarning(S.of(context)),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_stage == _Stage.input)
          ..._buildInputStage(context)
        else
          ..._buildReviewStage(context),
      ],
    );
  }

  Widget _buildIgdbWarning(S l) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.statusDropped.withAlpha(25),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.statusDropped.withAlpha(77)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber, color: AppColors.statusDropped),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l.gameListImportIgdbMissing,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Stage one: paste -----------------------------------------------------

  List<Widget> _buildInputStage(BuildContext context) {
    final S l = S.of(context);
    return <Widget>[
      SettingsGroup(
        title: l.gameListImportTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              l.gameListImportDescription,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _controller,
              minLines: 6,
              maxLines: 14,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l.gameListImportFieldHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _parsed.isEmpty ? Icons.info_outline : Icons.check_circle,
                  size: 18,
                  color: _parsed.isEmpty
                      ? AppColors.textTertiary
                      : AppColors.statusCompleted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    _parsed.isEmpty
                        ? l.gameListImportParsedEmpty
                        : l.gameListImportParsed(_parsed.length),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      _buildOptionsSection(context),
    ];
  }

  Widget _buildOptionsSection(BuildContext context) {
    final AsyncValue<List<Collection>> collectionsAsync =
        ref.watch(collectionsProvider);
    final S l = S.of(context);

    return SettingsGroup(
      title: l.importOptions,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l.gameListImportStatusLabel,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              StatusChipRow(
                status: _status,
                mediaType: MediaType.game,
                onChanged: (ItemStatus status) =>
                    setState(() => _status = status),
              ),
            ],
          ),
        ),
        _buildPlatformSelector(l),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            l.importTargetCollection,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        RadioGroup<bool>(
          groupValue: _useNewCollection,
          onChanged: (bool? value) {
            if (value == null) return;
            setState(() {
              _useNewCollection = value;
              if (value) _selectedCollectionId = null;
            });
          },
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text(l.importCreateNew),
                leading: const Radio<bool>(value: true),
                dense: true,
                onTap: () => setState(() {
                  _useNewCollection = true;
                  _selectedCollectionId = null;
                }),
              ),
              ListTile(
                title: Text(l.importUseExistingCollection),
                leading: const Radio<bool>(value: false),
                dense: true,
                onTap: () => setState(() => _useNewCollection = false),
              ),
            ],
          ),
        ),
        if (!_useNewCollection)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: collectionsAsync.when(
              data: (List<Collection> collections) {
                if (collections.isEmpty) {
                  return Text(
                    l.importNoCollections,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                }
                final bool selectedExists = _selectedCollectionId != null &&
                    collections.any(
                      (Collection c) => c.id == _selectedCollectionId,
                    );
                return CollectionPickerField(
                  value: selectedExists ? _selectedCollectionId : null,
                  hint: l.importSelectCollection,
                  title: l.importSelectCollection,
                  onChanged: (int? id) =>
                      setState(() => _selectedCollectionId = id),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (Object e, StackTrace s) => Text(
                l.importErrorLoadingCollections,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.statusDropped,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton.icon(
            onPressed: _parsed.isEmpty ? null : _startMatching,
            icon: const Icon(Icons.search),
            label: Text(l.gameListImportStart),
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformSelector(S l) {
    final bool hasValue = _platformId != null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      dense: true,
      title: Text(l.platform, style: AppTypography.body),
      subtitle: Text(
        l.gameListImportPlatformHint,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              hasValue ? _platformName ?? '' : l.igdbImportPlatformSelect,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: AppTypography.body.copyWith(
                color: hasValue ? AppColors.brand : AppColors.textTertiary,
                fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
        ],
      ),
      onTap: _platformsLoaded ? _pickPlatform : null,
    );
  }

  static String _platformLabel(model.Platform p) => p.abbreviation != null
      ? '${p.name} (${p.abbreviation})'
      : p.name;

  Future<void> _pickPlatform() async {
    final S l = S.of(context);
    final List<FilterOption> options = <FilterOption>[
      for (final model.Platform p in _platforms)
        FilterOption(
          id: p.id.toString(),
          label: _platformLabel(p),
          value: p.id,
        ),
    ];

    final Object? result = await showDialog<Object>(
      context: context,
      builder: (BuildContext context) => SearchableFilterDialog(
        title: l.platform,
        options: options,
        isLoading: false,
        currentValue: _platformId,
        allLabel: l.igdbImportPlatformSelect,
        showAllOption: true,
      ),
    );
    if (result == null || result == kFilterResetSentinel || !mounted) return;

    if (result is int) {
      setState(() {
        _platformId = result;
        _platformName = options
            .firstWhere((FilterOption o) => o.value == result)
            .label;
      });
    }
  }

  // --- Stage two: review ----------------------------------------------------

  List<Widget> _buildReviewStage(BuildContext context) {
    final S l = S.of(context);
    final GameNameMatchSession session = _session!;
    final int unmatched = session.unmatchedCount;

    return <Widget>[
      SettingsGroup(
        title: l.gameListImportReviewTitle,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  l.gameListImportSummary(
                    session.selectedCount,
                    session.rows.length,
                  ),
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (unmatched > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l.gameListImportUnmatchedNote(unmatched),
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      SettingsGroup(
        title: l.gameListImportMatched,
        children: <Widget>[
          for (int i = 0; i < session.rows.length; i++)
            _buildReviewRow(l, i, session.rows[i]),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _backToInput,
                icon: const Icon(Icons.arrow_back),
                label: Text(l.gameListImportBackToInput),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: _startImport,
                icon: const Icon(Icons.download),
                label: Text(l.gameListImportConfirm(session.selectedCount)),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildReviewRow(S l, int index, GameNameMatchRow row) {
    final GameNameCandidate? picked = row.selected;
    final bool matched = picked != null;
    final String title = matched ? picked.game.name : row.original;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      dense: true,
      leading: _buildQualityDot(row, matched),
      title: Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(
          color: matched ? AppColors.textPrimary : AppColors.textTertiary,
        ),
      ),
      subtitle: Text(
        _subtitleFor(l, row, picked),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      trailing: matched
          ? Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary)
          : _buildRetryHint(l, index),
      onTap: () => _pickCandidate(index, row),
    );
  }

  Widget _buildQualityDot(GameNameMatchRow row, bool matched) {
    if (row.searchFailed) {
      return Icon(
        Icons.cloud_off,
        size: 18,
        color: AppColors.statusDropped,
      );
    }
    if (!matched) {
      return Icon(Icons.remove_circle_outline, size: 18,
          color: AppColors.textTertiary);
    }
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(left: 4, right: 4),
      decoration: BoxDecoration(
        color: _qualityColor(row.quality),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildRetryHint(S l, int index) {
    return TextButton(
      onPressed: () => _pickCandidate(index, _session!.rows[index]),
      child: Text(l.gameListImportReview),
    );
  }

  String _subtitleFor(S l, GameNameMatchRow row, GameNameCandidate? picked) {
    if (row.searchFailed) return l.gameListImportSearchFailed;
    if (picked == null) return l.gameListImportNotFound;
    final String quality = _qualityLabel(l, row.quality);
    final String source = picked.source.label;
    // The original line is only worth repeating when it differs from what was
    // matched — otherwise it just doubles every row.
    if (picked.game.name == row.original) {
      return '$source · $quality';
    }
    return '${row.original} · $source · $quality';
  }

  static Color _qualityColor(MatchQuality quality) => switch (quality) {
        MatchQuality.exact || MatchQuality.strong => AppColors.statusCompleted,
        MatchQuality.fair => AppColors.brand,
        MatchQuality.weak => AppColors.textTertiary,
        MatchQuality.none => AppColors.statusDropped,
      };

  static String _qualityLabel(S l, MatchQuality quality) => switch (quality) {
        MatchQuality.exact => l.gameListImportQualityExact,
        MatchQuality.strong => l.gameListImportQualityStrong,
        MatchQuality.fair => l.gameListImportQualityFair,
        MatchQuality.weak => l.gameListImportQualityWeak,
        MatchQuality.none => l.gameListImportQualityNone,
      };

  /// Candidate picker for one row: every option both catalogues returned, plus
  /// an explicit "do not import".
  Future<void> _pickCandidate(int index, GameNameMatchRow row) async {
    final S l = S.of(context);
    final List<int> values = <int>[
      for (int i = 0; i < row.candidates.length; i++) i,
      -1,
    ];

    final int? picked = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(row.original),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: RadioGroup<int>(
              groupValue: row.selectedIndex,
              onChanged: (int? value) => Navigator.of(context).pop(value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (row.candidates.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        row.searchFailed
                            ? l.gameListImportSearchFailed
                            : l.gameListImportNoCandidates,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  for (final int value in values)
                    _buildCandidateTile(l, row, value),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
        ],
      ),
    );

    if (picked == null || !mounted) return;
    setState(() => row.selectedIndex = picked);
  }

  Widget _buildCandidateTile(S l, GameNameMatchRow row, int value) {
    if (value < 0) {
      return ListTile(
        dense: true,
        leading: const Radio<int>(value: -1),
        title: Text(l.gameListImportSkip),
        onTap: () => Navigator.of(context).pop(-1),
      );
    }

    final GameNameCandidate candidate = row.candidates[value];
    return ListTile(
      dense: true,
      leading: Radio<int>(value: value),
      title: Text(candidate.game.name),
      subtitle: Text(
        '${candidate.source.label} · '
        '${_qualityLabel(l, candidate.quality)}',
        style: AppTypography.bodySmall.copyWith(
          color: AppColors.textTertiary,
        ),
      ),
      onTap: () => Navigator.of(context).pop(value),
    );
  }

  void _backToInput() {
    setState(() {
      _stage = _Stage.input;
      _session = null;
    });
  }

  // --- Running the two phases ----------------------------------------------

  Future<void> _startMatching() async {
    final GameNameListImportService service =
        ref.read(gameNameListImportServiceProvider);
    final List<String> names = _parsed;
    if (names.isEmpty) return;

    final ValueNotifier<ImportProgress?> progressNotifier =
        ValueNotifier<ImportProgress?>(null);

    final Future<GameNameMatchSession> matchFuture = service.match(
      names,
      platformId: _platformId,
      onProgress: (ImportProgress progress) {
        progressNotifier.value = progress;
      },
    );

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _MatchProgressDialog(
        progressNotifier: progressNotifier,
        matchFuture: matchFuture,
      ),
    );

    progressNotifier.dispose();

    GameNameMatchSession session;
    try {
      session = await matchFuture;
    } on Exception catch (e) {
      if (mounted) {
        context.showErrorSnack('${S.of(context).gameListImportStart}: $e');
      }
      return;
    }
    if (!mounted) return;

    setState(() {
      _session = session;
      _stage = _Stage.review;
    });
  }

  Future<void> _startImport() async {
    final GameNameMatchSession? session = _session;
    if (session == null) return;

    final GameNameListImportService service =
        ref.read(gameNameListImportServiceProvider);
    final S l = S.of(context);
    final String authorName = ref.read(settingsNotifierProvider).authorName;

    final ValueNotifier<ImportProgress?> progressNotifier =
        ValueNotifier<ImportProgress?>(null);
    UniversalImportResult? importResult;

    final Future<UniversalImportResult> importFuture = service.import(
      GameNameListImportOptions(
        rows: session.rows,
        author: authorName,
        platformId: _platformId,
        status: _status,
        wishlistReason: l.gameListImportReasonNotFound,
        collectionId: _useNewCollection ? null : _selectedCollectionId,
      ),
      onProgress: (ImportProgress progress) {
        progressNotifier.value = progress;
      },
    ).then((UniversalImportResult result) {
      importResult = result;
      return result;
    });

    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => _ImportProgressDialog(
        progressNotifier: progressNotifier,
        importFuture: importFuture,
      ),
    );

    progressNotifier.dispose();

    if (importResult == null || !mounted) return;

    final UniversalImportResult result = importResult!;
    if (result.success) {
      ref.invalidate(collectionsProvider);
      final int? cid = result.effectiveCollectionId;
      if (cid != null) {
        ref.invalidate(collectionStatsProvider(cid));
        ref.invalidate(collectionCoversProvider(cid));
        ref.invalidate(collectionItemsNotifierProvider(cid));
        ref.invalidate(canvasNotifierProvider(cid));
      }
      ref.invalidate(allItemsNotifierProvider);
      ref.invalidate(wishlistProvider);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              ImportResultScreen(result: result),
        ),
      );
    } else if (result.fatalError != null) {
      context.showErrorSnack(result.fatalError!, detail: result.fatalDetail);
    }
  }
}

class _MatchProgressDialog extends StatelessWidget {
  const _MatchProgressDialog({
    required this.progressNotifier,
    required this.matchFuture,
  });

  final ValueNotifier<ImportProgress?> progressNotifier;
  final Future<GameNameMatchSession> matchFuture;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l.gameListImportMatching),
      content: ValueListenableBuilder<ImportProgress?>(
        valueListenable: progressNotifier,
        builder:
            (BuildContext context, ImportProgress? progress, Widget? child) {
          if (progress == null) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ProgressBody(progress: progress);
        },
      ),
      actions: <Widget>[
        FutureBuilder<GameNameMatchSession>(
          future: matchFuture,
          builder: (BuildContext context,
              AsyncSnapshot<GameNameMatchSession> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            return FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.done),
            );
          },
        ),
      ],
    );
  }
}

class _ImportProgressDialog extends StatelessWidget {
  const _ImportProgressDialog({
    required this.progressNotifier,
    required this.importFuture,
  });

  final ValueNotifier<ImportProgress?> progressNotifier;
  final Future<UniversalImportResult> importFuture;

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l.importing),
      content: ValueListenableBuilder<ImportProgress?>(
        valueListenable: progressNotifier,
        builder:
            (BuildContext context, ImportProgress? progress, Widget? child) {
          if (progress == null) {
            return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _ProgressBody(progress: progress);
        },
      ),
      actions: <Widget>[
        FutureBuilder<UniversalImportResult>(
          future: importFuture,
          builder: (BuildContext context,
              AsyncSnapshot<UniversalImportResult> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            return FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l.done),
            );
          },
        ),
      ],
    );
  }
}

/// Shared body of both progress dialogs so the two cannot drift.
class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          progress.stage.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (progress.message != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            progress.message!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        const SizedBox(height: 16),
        LinearProgressIndicator(
          value: progress.total > 0 ? progress.progress : null,
        ),
        if (progress.total > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '${progress.current} / ${progress.total}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
