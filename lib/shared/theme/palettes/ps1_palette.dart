import 'package:flutter/material.dart';

import '../app_assets.dart';
import '../app_palette.dart';

/// PS1 retro grey — the 1994 console shell with its four-colour logo.
///
/// Base is the classic PlayStation grey (#ADADAD); the card surfaces are the
/// lighter measured shell tones so panels read as raised. The accents come
/// from the four-colour logo mark:
///
///   * Spanish Red     #DF0024
///   * Goldenrod       #F3C300
///   * Manganese Green #00AC9F
///   * Atlantis Blue   #2E6DB4
///
/// Those four are drawn at their published chroma where the palette uses them
/// as *fills* ([brand], [badge]), because a fill carries white or black text
/// and clears its contrast bar that way. Where a token is painted as a thin
/// glyph instead — every [gameAccent]-style media accent, the status dots and
/// the rating ramp — the published value cannot clear anything on a mid-grey
/// background (#DF0024 is 2.25 against it, #F3C300 only 0.93), so those run a
/// darker relative of the same hue. The published figure and its measured
/// contrast are noted on each such token so the step down stays auditable.
///
/// Every text pair here was measured, not eyeballed: textPrimary reads 7.43 on
/// the background and 9.34 on a card, textSecondary 4.69, onBrand 5.30.
const AppPalette ps1Palette = AppPalette(
  brightness: Brightness.light,
  // Classic PS grey — the shell colour the whole theme is named for.
  background: Color(0xFFADADAD),
  // Measured lighter shell greys: cards float above the background.
  surface: Color(0xFFC5C1C0),
  surfaceLight: Color(0xFFB8B4B3),
  surfaceBorder: Color(0xFF8E8A89),
  // Near-black print, the way the shell's silkscreen reads.
  textPrimary: Color(0xFF1E1E1E),
  textSecondary: Color(0xFF3F3F3F),
  textTertiary: Color(0xFF565656),
  // Atlantis Blue, published value: a fill, so white on it clears 5.30.
  brand: Color(0xFF2E6DB4),
  onBrand: Color(0xFFFFFFFF),
  // Manganese Green, darkened from #00AC9F (1.26 on grey) to 2.33.
  gameAccent: Color(0xFF007A70),
  // Spanish Red, darkened from #DF0024 (2.25 on grey) to 2.80.
  movieAccent: Color(0xFFC4001F),
  // Goldenrod, darkened from #F3C300 (0.93 on grey) to 2.47.
  tvShowAccent: Color(0xFF8A6100),
  animationAccent: Color(0xFF6A2F93),
  visualNovelAccent: Color(0xFF1F4E85),
  mangaAccent: Color(0xFF0F6E9E),
  animeAccent: Color(0xFFAD1150),
  bookAccent: Color(0xFF6E5236),
  audioAccent: Color(0xFF8E2570),
  customAccent: Color(0xFF3F5A66),
  success: Color(0xFF007A70),
  warning: Color(0xFF8A6100),
  error: Color(0xFFC4001F),
  favorite: Color(0xFFC4001F),
  statusInProgress: Color(0xFF2E6DB4),
  statusPlanned: Color(0xFF6A2F93),
  statusReplaying: Color(0xFF0F6E9E),
  ratingStar: Color(0xFF8A6100),
  ratingHigh: Color(0xFF007A70),
  ratingMedium: Color(0xFF8A6100),
  ratingLow: Color(0xFFC4001F),
  ratingGold: Color(0xFF7A6200),
  scrim: Color(0xFF000000),
  onOverlay: Color(0xFFFFFFFF),
  barrier: Color(0x73000000),
  shadow: Color(0xFF000000),
  rowFade: Color(0xFFA4A4A4),
  // Spanish Red at published chroma: a filled counter badge, white reads 5.04.
  badge: Color(0xFFDF0024),
  onBadge: Color(0xFFFFFFFF),
  // Same glyph mask as the other themes, tinted to a recessed shell grey.
  tileAsset: AppAssets.backgroundTilePs1,
  tileOpacity: 0.07,
);
