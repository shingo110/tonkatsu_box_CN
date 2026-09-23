import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show ByteData, FontLoader;
import 'package:logging/logging.dart';

import 'app_font_config.dart';
import 'font_binary_parser.dart';
import 'system_font_models.dart';

final Logger _log = Logger('SystemFonts');

/// Windows is the only platform this scanner has been verified against. macOS
/// and Linux keep their fonts in other directories, and a picker that lists
/// nothing is worse than no picker, so they stay closed until tested.
bool get systemFontsAvailable => Platform.isWindows;

const Set<String> _suffixes = <String>{'.ttf', '.otf', '.ttc', '.otc'};

List<SystemFontFamily>? _cache;

/// Registration keys already handed to the engine. Registering the same key
/// twice would stack duplicate typefaces under it, so the second activation
/// of a family only re-points the app at it.
final Set<String> _registered = <String>{};

List<String> _fontRoots() {
  final String windir = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  final String? localAppData = Platform.environment['LOCALAPPDATA'];
  return <String>[
    '$windir\\Fonts',
    // Per-user fonts (Windows 10 1809+). These are not optional: on the dev
    // machine they held 601 of 779 faces, so skipping the directory would
    // hide most of what the user installed themselves.
    if (localAppData != null && localAppData.isNotEmpty)
      '$localAppData\\Microsoft\\Windows\\Fonts',
  ];
}

Future<List<SystemFontFamily>> loadSystemFonts({bool refresh = false}) async {
  final List<SystemFontFamily>? cached = _cache;
  if (cached != null && !refresh) {
    return cached;
  }
  List<SystemFontFamily> scanned;
  try {
    scanned = await Isolate.run(_scanSync);
  } on Object catch (err) {
    // An environment that refuses to spawn isolates still gets a picker.
    _log.warning('Font scan isolate failed, scanning inline: $err');
    scanned = _scanSync();
  }
  return _cache = scanned;
}

/// Reads a font file, or `null` when another process holds it open.
///
/// Kept out of the scan loop so one locked file can be skipped without
/// aborting the scan — and so the loop never assigns a `final` inside a `try`.
Uint8List? _readFontBytes(File file) {
  try {
    return file.readAsBytesSync();
  } on FileSystemException catch (err) {
    _log.fine('Skipping unreadable font ${file.path}: ${err.message}');
    return null;
  }
}

/// Reads and parses every font file on the machine. Runs off the UI thread —
/// it touches a few hundred files for roughly a second.
List<SystemFontFamily> _scanSync() {
  final Map<String, List<SystemFontFile>> byFamily =
      <String, List<SystemFontFile>>{};
  final Map<String, String?> localized = <String, String?>{};

  for (final String root in _fontRoots()) {
    final Directory dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) continue;
      final String path = entity.path;
      final int dot = path.lastIndexOf('.');
      if (dot < 0 || !_suffixes.contains(path.substring(dot).toLowerCase())) {
        continue;
      }
      final Uint8List? bytes = _readFontBytes(entity);
      if (bytes == null) continue;
      // Face 0 only. `FontLoader` hands the whole binary to the engine, which
      // renders face 0 of it, so a collection contributes exactly one entry
      // per file — listing its other faces would offer fonts we cannot load.
      final FontFaceInfo? info = parseFontFace(bytes);
      if (info == null) continue;
      byFamily
          .putIfAbsent(info.familyEn, () => <SystemFontFile>[])
          .add(
            SystemFontFile(
              path: path,
              weight: info.weight,
              italic: info.italic,
            ),
          );
      localized[info.familyEn] ??= info.familyLocalized;
    }
  }

  return <SystemFontFamily>[
    for (final MapEntry<String, List<SystemFontFile>> entry in byFamily.entries)
      SystemFontFamily(
        familyEn: entry.key,
        localizedName: localized[entry.key],
        files: entry.value
          ..sort((SystemFontFile a, SystemFontFile b) {
            if (a.weight != b.weight) return a.weight.compareTo(b.weight);
            // Upright before italic at the same weight.
            return (a.italic ? 1 : 0).compareTo(b.italic ? 1 : 0);
          }),
      ),
  ]..sort(
      (SystemFontFamily a, SystemFontFamily b) =>
          a.familyEn.toLowerCase().compareTo(b.familyEn.toLowerCase()),
    );
}

Future<bool> activateSystemFont(SystemFontFamily family) async {
  // Without a file there is nothing to register, and marking the key as
  // registered would leave the app pointing at a family that does not exist.
  if (family.files.isEmpty) return false;

  final String key = fontRegistrationKey(family.familyEn);
  if (!_registered.contains(key)) {
    try {
      final FontLoader loader = FontLoader(key);
      for (final SystemFontFile file in family.files) {
        loader.addFont(
          File(file.path)
              .readAsBytes()
              .then((Uint8List bytes) => ByteData.sublistView(bytes)),
        );
      }
      await loader.load();
      _registered.add(key);
    } on Object catch (err, stack) {
      _log.warning('Failed to register font ${family.familyEn}', err, stack);
      return false;
    }
  }

  AppFontConfig.current = AppFontConfig(
    family: key,
    displayName: family.displayName,
  );
  return true;
}
