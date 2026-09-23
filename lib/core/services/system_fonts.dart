import 'app_font_config.dart';
import 'system_font_models.dart';

// A conditional import, not `kIsWeb`: only this keeps dart:io out of the web
// compile — the same pattern platform_features uses.
import 'system_fonts_io.dart'
    if (dart.library.js_interop) 'system_fonts_web.dart'
    as impl;

/// Whether this build can enumerate and load the machine's own fonts.
///
/// Windows only for now: its font directories are the ones the scanner has
/// actually been verified against. Listing directories nobody has run it on
/// would hand users a picker that shows nothing.
bool get kSystemFontsAvailable => impl.systemFontsAvailable;

/// Every installed family, grouped by family name and sorted for display.
///
/// The first call reads and parses every font file on the machine (a few
/// hundred files); the result is cached, so the picker reopens instantly.
/// Pass [refresh] to re-read after the user installed a font.
Future<List<SystemFontFamily>> loadSystemFonts({bool refresh = false}) =>
    impl.loadSystemFonts(refresh: refresh);

/// Registers every file of [family] with the engine and switches the app to
/// it. Returns false when nothing usable could be registered — a missing or
/// unreadable file — in which case the caller should stay on the default.
Future<bool> activateSystemFont(SystemFontFamily family) =>
    impl.activateSystemFont(family);

/// Puts the app back on the bundled font. The previously registered bytes
/// stay with the engine (there is no unregister API), but nothing references
/// them any more.
void useDefaultFont() => AppFontConfig.current = const AppFontConfig.defaults();
