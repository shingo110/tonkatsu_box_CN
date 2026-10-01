import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../app_palette.dart';

/// Eva azure — the Eva Design System shade card, read off the card itself.
///
/// The supplied card (`eva-design-color-shades`) is five hues x nine steps.
/// Its values were **sampled, not recalled**: five columns x eight rows were
/// located by scanning the pixels, each cell read as the median of a centre
/// patch (a single-pixel read returns #87BA13 where the card prints #87BA12 —
/// JPEG ringing). The sampled 500 row lands within 1/255 of every hex the card
/// prints: #3366FF, #87BA12, #00B6FF, #FFA100, #FF3236.
///
/// The card is cropped: the 800 row is clipped and 900 is absent, so nothing
/// above 800 is used and no value was extrapolated.
///
/// Where each token comes from:
///
///   * **Skeleton = the Primary column.** [background] is Primary 100,
///     [surfaceBorder] Primary 200, and the text ramp walks 800 -> 700.
///   * [textTertiary] cannot come off that ramp — Primary 400 measures 2.34 on
///     Primary 100, under the 2.5 floor — so the weakest tier is the same hue
///     de-saturated to #6C7A9C (3.35).
///   * **The other four columns carry the semantic roles, each at the darkest
///     step that still reads.** At 500 the mid values are unusable as glyphs
///     on a pale ground: Success #87BA12 measures 1.81, Info #00B6FF 1.80,
///     Warning #FFA100 1.58. Those run 600/700/800 instead. The 500 row
///     survives only where the colour is a *fill* under white text —
///     [brand] Primary 4.68 and [badge] Danger 3.64.
///   * **Three hues the card does not carry are mixed from two card colours**
///     rather than invented, so every token still descends from the card:
///     [animationAccent] violet = Primary 600 + Danger 700, [audioAccent]
///     magenta = Danger 500 + Primary 600, [customAccent] teal =
///     Info 600 + Success 700.
///
/// Measured, not eyeballed: textPrimary 9.53 on the background and 12.21 on a
/// card, textSecondary 7.12, textTertiary 3.35, textPrimary on surfaceLight
/// 10.84, onBrand 4.68, onBadge 3.64. Every glyph accent clears 2.81 — the
/// three preceding themes sit between 2.33 and 3.4.
const AppPalette evaPalette = AppPalette(
  brightness: Brightness.light,
  // Primary 100 — the pale end of the card's own column.
  background: Color(0xFFD6E4FF),
  // Plain white so panels float; surfaceLight is the midpoint back to 100.
  surface: Color(0xFFFFFFFF),
  surfaceLight: Color(0xFFEAF2FF),
  surfaceBorder: Color(0xFFADC8FF), // Primary 200
  // Primary 800 / 700 — a near-black indigo, the card's own dark end.
  textPrimary: Color(0xFF102693),
  textSecondary: Color(0xFF1A39B6),
  // Primary 400 measures 2.34 here (under the 2.5 floor), so this tier is the
  // same hue de-saturated: 3.35.
  textTertiary: Color(0xFF6C7A9C),
  // Primary 500 exactly as the card prints it: a fill, so white clears 4.68.
  brand: Color(0xFF3366FF),
  onBrand: Color(0xFFFFFFFF),
  // Primary 600 — darkened from 500 (3.66) to 5.16 for glyph duty.
  gameAccent: Color(0xFF254EDA),
  // Danger 700 — 500 measures 2.85 on the pale ground.
  movieAccent: Color(0xFFB71A39),
  // Success 700 — 500 measures 1.81 on the pale ground.
  tvShowAccent: Color(0xFF588409),
  // mix(Primary 600, Danger 700) — the card has no violet.
  animationAccent: Color(0xFF6E348A),
  visualNovelAccent: Color(0xFF102693), // Primary 800
  // Info 600 — 500 measures 1.80 on the pale ground.
  mangaAccent: Color(0xFF008DDC),
  // Danger 500 at the card's chroma; it already carries the badge.
  animeAccent: Color(0xFFFF3236),
  // Warning 800 — 500 measures 1.58 on the pale ground.
  bookAccent: Color(0xFF944C00),
  // mix(Danger 500, Primary 600) — the card has no magenta.
  audioAccent: Color(0xFF924088),
  // mix(Info 600, Success 700) — the card has no teal.
  customAccent: Color(0xFF2C8872),
  success: Color(0xFF588409), // Success 700
  warning: Color(0xFFB86600), // Warning 700
  error: Color(0xFFDB2438), // Danger 600
  favorite: Color(0xFFDB2438),
  statusInProgress: Color(0xFF254EDA), // Primary 600
  statusPlanned: Color(0xFF6E348A), // the violet above
  statusReplaying: Color(0xFF006AB6), // Info 700
  ratingStar: Color(0xFFB86600), // Warning 700
  ratingHigh: Color(0xFF588409), // Success 700
  ratingMedium: Color(0xFFDB8200), // Warning 600
  ratingLow: Color(0xFFB71A39), // Danger 700
  ratingGold: Color(0xFF944C00), // Warning 800
  scrim: Color(0xFF000000),
  onOverlay: Color(0xFFFFFFFF),
  barrier: Color(0x73000000),
  shadow: Color(0xFF000000),
  rowFade: Color(0xFFC2D6FF), // midway, background -> surfaceBorder
  // Danger 500 as printed: a filled counter badge, white reads 3.64.
  badge: Color(0xFFFF3236),
  onBadge: Color(0xFFFFFFFF),
  // Same glyph mask as the other themes, tinted to the card's Primary 500.
  tileAsset: AppAssets.backgroundTileEva,
  tileOpacity: 0.06,
);
