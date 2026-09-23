import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:logging/logging.dart';

import 'app_font_config.dart';
import 'font_binary_parser.dart';
import 'system_font_models.dart';

/// Web stub: the picker is a desktop feature, and a browser cannot read the
/// machine's font files anyway. Kept in the same shape as the io build so the
/// facade compiles on both.
const bool systemFontsAvailable = false;

Future<List<SystemFontFamily>> loadSystemFonts({bool refresh = false}) async =>
    const <SystemFontFamily>[];

Future<bool> activateSystemFont(SystemFontFamily family) async => false;
