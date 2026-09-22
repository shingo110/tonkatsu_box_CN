import 'package:flutter/material.dart';

import '../../../core/import/sources/name_list/game_name_list_import_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/widgets/sub_screen_title_bar.dart';
import '../content/game_name_list_import_content.dart';

/// Thin [Scaffold]/title-bar wrapper around [GameNameListImportContent].
class GameNameListImportScreen extends StatelessWidget {
  const GameNameListImportScreen({super.key, this.initialQueries});

  /// Forwarded to the content, so a caller that already holds the rows — the
  /// PlayStation importer, after reading the library — lands directly on the
  /// review step.
  final List<GameNameQuery>? initialQueries;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isWide = width >= 800;

    return Column(
      children: <Widget>[
        SubScreenTitleBar(title: S.of(context).settingsGameListImport),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 600 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? AppSpacing.lg : AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child:
                    GameNameListImportContent(initialQueries: initialQueries),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
