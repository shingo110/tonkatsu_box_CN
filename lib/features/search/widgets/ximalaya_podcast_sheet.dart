import 'package:core/models/audio_item.dart';
import 'package:flutter/material.dart';

import 'item_details_sheet.dart';

/// Ximalaya show detail sheet: the record on its own, with no episode preview.
///
/// The episode list sits behind a signed-in web token (`getTracksList` answers
/// `webtk缺失`), so there is nothing to fetch and the search row is the whole
/// record. The strip stays empty rather than showing a loader that never
/// resolves.
class XimalayaPodcastSheet extends StatelessWidget {
  const XimalayaPodcastSheet({
    required this.podcast,
    required this.onAddToCollection,
    super.key,
  });

  final AudioItem podcast;
  final VoidCallback onAddToCollection;

  @override
  Widget build(BuildContext context) {
    return ItemDetailsSheet.podcast(
      podcast,
      onAddToCollection: onAddToCollection,
    );
  }
}
