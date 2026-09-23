import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_font_config.dart';
import '../../../core/services/system_font_models.dart';
import '../../../core/services/system_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/extensions/snackbar_extension.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_spacing.dart';
import '../../../shared/theme/app_typography.dart';
import '../providers/font_provider.dart';

/// Picks the UI font from the families installed on this machine.
///
/// Choosing one registers its files with the engine and switches the app over.
/// Since the [MaterialApp] key follows the font, that remounts the tree
/// through the splash — the same trip a theme switch makes.
///
/// Every row is rendered in its own font, so the list previews itself. That
/// preview is free: the engine resolves an installed family by name, with no
/// registration and no bytes in our heap. The font actually applied goes the
/// other way — through registered bytes under a private key — which is what
/// makes the outcome independent of how the platform names its fonts.
class FontSettingsScreen extends ConsumerStatefulWidget {
  const FontSettingsScreen({super.key});

  @override
  ConsumerState<FontSettingsScreen> createState() => _FontSettingsScreenState();
}

class _FontSettingsScreenState extends ConsumerState<FontSettingsScreen> {
  final Future<List<SystemFontFamily>> _fonts = loadSystemFonts();
  final TextEditingController _search = TextEditingController();

  String _query = '';

  /// Family currently being registered, so its row can show a spinner.
  String? _applying;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// [family] of `null` means the bundled default.
  Future<void> _select(SystemFontFamily? family) async {
    setState(() => _applying = family?.familyEn ?? defaultFontFamily);
    final FontNotifier notifier = ref.read(fontProvider.notifier);
    bool ok = true;
    if (family == null) {
      await notifier.reset();
    } else {
      ok = await notifier.select(family);
    }
    if (!mounted) return;
    setState(() => _applying = null);
    if (!ok) {
      context.showSnack(S.of(context).settingsFontApplyFailed);
    }
  }

  List<SystemFontFamily> _filter(List<SystemFontFamily> all) {
    if (_query.isEmpty) return all;
    return <SystemFontFamily>[
      for (final SystemFontFamily family in all)
        if (family.familyEn.toLowerCase().contains(_query) ||
            (family.localizedName?.toLowerCase().contains(_query) ?? false))
          family,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final S l = S.of(context);
    if (!kSystemFontsAvailable) {
      return Scaffold(
        appBar: AppBar(title: Text(l.settingsFont)),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            l.settingsFontUnavailable,
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final AppFontConfig current = ref.watch(fontProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsFont)),
      body: FutureBuilder<List<SystemFontFamily>>(
        future: _fonts,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<SystemFontFamily>> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  Text(l.settingsFontLoading, style: AppTypography.bodySmall),
                ],
              ),
            );
          }
          final List<SystemFontFamily> families = _filter(
            snapshot.data ?? const <SystemFontFamily>[],
          );
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  l.settingsFontHint,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: l.settingsFontSearch,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (String value) =>
                      setState(() => _query = value.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  // Row 0 is the bundled default; the rest are the machine's
                  // families, already sorted by name.
                  itemCount: families.length + 1,
                  separatorBuilder: (BuildContext context, int index) =>
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColors.surfaceBorder,
                        indent: AppSpacing.md,
                      ),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == 0) {
                      return _row(
                        label: l.settingsFontDefault,
                        subtitle: null,
                        previewFamily: null,
                        selected: current.isDefault,
                        busy: _applying == defaultFontFamily,
                        onTap: () => _select(null),
                      );
                    }
                    final SystemFontFamily family = families[index - 1];
                    return _row(
                      label: family.displayName,
                      subtitle: l.settingsFontWeightCount(family.weightCount),
                      previewFamily: family.familyEn,
                      selected:
                          current.family ==
                          fontRegistrationKey(family.familyEn),
                      busy: _applying == family.familyEn,
                      onTap: () => _select(family),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row({
    required String label,
    required String? subtitle,
    required String? previewFamily,
    required bool selected,
    required bool busy,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: busy ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // Its own font, so the row shows what it offers.
                      fontFamily: previewFamily,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTypography.caption),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (selected)
              Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
