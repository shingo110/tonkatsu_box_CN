import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/shared/theme/app_palette.dart';
import 'package:tonkatsu_box/shared/theme/app_theme_id.dart';

/// WCAG relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
}

/// Guards that hold for *every* theme, so a fourth one inherits them for free.
void main() {
  group('theme registry', () {
    test('every theme maps to its own palette instance', () {
      final Set<AppPalette> palettes = <AppPalette>{
        for (final AppThemeId theme in AppThemeId.values) theme.palette,
      };
      expect(palettes.length, AppThemeId.values.length);
    });

    test('every palette names a wallpaper that is present in the tree', () {
      final List<String> absent = <String>[];
      for (final AppThemeId theme in AppThemeId.values) {
        final String asset = theme.palette.tileAsset;
        if (!File(asset).existsSync()) {
          absent.add('${theme.id} -> $asset');
        }
      }
      expect(
        absent,
        isEmpty,
        reason: 'declared but missing: ${absent.join(', ')}',
      );
    });
  });

  group('contrast floors', () {
    // Regression guard: text colours once resolved against the palette frozen
    // at first access, which produced white-on-white after a theme switch.
    test('text reads on every surface of every theme', () {
      final List<String> failures = <String>[];

      void check(
        AppThemeId theme,
        String what,
        Color foreground,
        Color background,
        double floor,
      ) {
        final double ratio = _contrast(foreground, background);
        if (ratio < floor) {
          failures.add(
            '${theme.id}: $what = ${ratio.toStringAsFixed(2)}, needs $floor',
          );
        }
      }

      for (final AppThemeId theme in AppThemeId.values) {
        final AppPalette p = theme.palette;
        check(
          theme,
          'textPrimary on background',
          p.textPrimary,
          p.background,
          4.5,
        );
        check(theme, 'textPrimary on surface', p.textPrimary, p.surface, 4.5);
        check(
          theme,
          'textPrimary on surfaceLight',
          p.textPrimary,
          p.surfaceLight,
          4.5,
        );
        check(
          theme,
          'textSecondary on background',
          p.textSecondary,
          p.background,
          3.0,
        );
        check(
          theme,
          'textSecondary on surfaceLight',
          p.textSecondary,
          p.surfaceLight,
          3.0,
        );
        check(
          theme,
          'textTertiary on background',
          p.textTertiary,
          p.background,
          2.5,
        );
        check(theme, 'onBrand on brand', p.onBrand, p.brand, 3.0);
        check(theme, 'onBadge on badge', p.onBadge, p.badge, 3.0);
        check(theme, 'onOverlay on scrim', p.onOverlay, p.scrim, 4.5);
      }

      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  });

  group('PS1 palette', () {
    // The shell grey is what the theme is named for.
    test('background is the classic PlayStation grey', () {
      expect(AppPalette.ps1.background, const Color(0xFFADADAD));
    });

    // Only two of the four logo colours ship at their published chroma, and
    // both are fill roles. The other two cannot: on a mid-grey background
    // Goldenrod #F3C300 measures 0.93 and Manganese Green #00AC9F 1.26, so
    // both are darkened wherever they are painted as a glyph instead. See the
    // measured figures on `ps1Palette`.
    test('the logo colours that carry fills stay at published chroma', () {
      expect(AppPalette.ps1.brand, const Color(0xFF2E6DB4)); // Atlantis Blue
      expect(AppPalette.ps1.badge, const Color(0xFFDF0024)); // Spanish Red
    });
  });
}
