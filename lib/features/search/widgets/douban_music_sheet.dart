import 'package:core/models/audio_item.dart';
import 'package:core/models/audio_track.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/douban_api.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/audio_track_row.dart';
import 'item_details_sheet.dart';

/// Douban album detail sheet: record info plus a preview of the track list.
/// No editions strip — a Douban subject is one release rather than a group
/// with many editions behind it, the way a MusicBrainz release-group is.
class DoubanMusicSheet extends ConsumerStatefulWidget {
  const DoubanMusicSheet({
    required this.album,
    required this.onAddToCollection,
    super.key,
  });

  final AudioItem album;
  final VoidCallback onAddToCollection;

  /// A user-built compilation can run to hundreds of entries; a preview says
  /// what the record holds without paying to lay all of them out.
  static const int previewTracks = 50;

  @override
  ConsumerState<DoubanMusicSheet> createState() => _DoubanMusicSheetState();
}

class _DoubanMusicSheetState extends ConsumerState<DoubanMusicSheet> {
  List<AudioTrack>? _tracks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // One call answers both halves — the album record and its `songs`.
      final (AudioItem?, List<AudioTrack>) fetched = await ref
          .read(doubanApiProvider)
          .getMusicWithTracks(widget.album.nativeId);
      if (!mounted) return;
      final List<AudioTrack> tracks = fetched.$2;
      setState(
        () => _tracks = tracks.length > DoubanMusicSheet.previewTracks
            ? tracks.sublist(0, DoubanMusicSheet.previewTracks)
            : tracks,
      );
    } on Object {
      if (!mounted) return;
      setState(() => _tracks = const <AudioTrack>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ItemDetailsSheet.album(
      widget.album,
      onAddToCollection: widget.onAddToCollection,
      editionsSection: _buildTracks(context),
    );
  }

  Widget _buildTracks(BuildContext context) {
    final S l = S.of(context);
    final List<AudioTrack>? tracks = _tracks;
    if (tracks == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (tracks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          l.musicTrackerNoTracks,
          style: AppTypography.caption.copyWith(color: AppColors.textTertiary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.md),
          child: Text(l.musicSheetTracks, style: AppTypography.h3),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final AudioTrack track in tracks)
          AudioTrackRow(
            key: ValueKey<int>(track.position),
            track: track,
          ),
      ],
    );
  }
}
