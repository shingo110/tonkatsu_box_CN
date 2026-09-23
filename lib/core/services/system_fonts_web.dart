import 'system_font_models.dart';

/// Web stub: the picker is a desktop feature, and a browser cannot read the
/// machine's font files anyway. Kept in the same shape as the io build so the
/// facade compiles on both.
const bool systemFontsAvailable = false;

Future<List<SystemFontFamily>> loadSystemFonts({bool refresh = false}) async =>
    const <SystemFontFamily>[];

Future<bool> activateSystemFont(SystemFontFamily family) async => false;
