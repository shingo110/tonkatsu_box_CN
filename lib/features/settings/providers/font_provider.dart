import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/app_font_config.dart';
import '../../../core/services/system_font_models.dart';
import '../../../core/services/system_fonts.dart';
import 'settings_provider.dart';

/// The app-wide font selection.
///
/// Deliberately kept out of [SettingsNotifier]: a system font is machine-local
/// — it names files that exist on this disk and stays out of the exported
/// config — so it does not belong beside API keys and display toggles.
///
/// The initial value is [AppFontConfig.current] because `main()` has already
/// registered the saved font before the first frame.
final NotifierProvider<FontNotifier, AppFontConfig> fontProvider =
    NotifierProvider<FontNotifier, AppFontConfig>(FontNotifier.new);

class FontNotifier extends Notifier<AppFontConfig> {
  late SharedPreferences _prefs;

  @override
  AppFontConfig build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    return AppFontConfig.current;
  }

  /// Registers [family] with the engine and switches the app to it.
  ///
  /// Returns false when the font could not be loaded — a missing or corrupt
  /// file — leaving both the state and the engine untouched.
  Future<bool> select(SystemFontFamily family) async {
    // Re-selecting the current font must not remount the tree for nothing.
    if (state.family == fontRegistrationKey(family.familyEn)) return true;
    if (!await activateSystemFont(family)) return false;
    await _prefs.setString(SettingsKeys.fontFamily, family.encode());
    await _skipPickerOnRemount();
    state = AppFontConfig.current;
    return true;
  }

  /// Back to the bundled font.
  Future<void> reset() async {
    if (state.isDefault) return;
    useDefaultFont();
    await _prefs.remove(SettingsKeys.fontFamily);
    await _skipPickerOnRemount();
    state = AppFontConfig.current;
  }

  /// The [MaterialApp] key follows the font, so a switch remounts the tree
  /// through the splash; that must not replay the profile picker.
  Future<void> _skipPickerOnRemount() =>
      _prefs.setBool(SettingsKeys.skipPickerOnce, true);
}
