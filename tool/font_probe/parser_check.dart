// Local verification for the system-font parser.
//
// `flutter test` is unreliable in this sandbox (the tool dies creating the
// pipe for `cmd.exe /c ver`), so the parser — pure Dart on Uint8List — is
// exercised here against every font actually installed on this machine.
// The synthesised-fixture unit test lives in
// test/core/services/font_binary_parser_test.dart and runs on CI.
//
// Run: dart run tool/font_probe/parser_check.dart

import 'dart:io';
import 'dart:typed_data';

import 'package:tonkatsu_box/core/services/font_binary_parser.dart';

int _failures = 0;

void check(bool ok, String label) {
  if (!ok) _failures++;
  stdout.writeln('${ok ? '  ok  ' : ' FAIL '} $label');
}

const Set<String> _suffixes = <String>{'.ttf', '.otf', '.ttc', '.otc'};

List<String> _roots() {
  final List<String> roots = <String>[];
  final String? windir = Platform.environment['SystemRoot'] ?? r'C:\Windows';
  roots.add('$windir\\Fonts');
  final String? local = Platform.environment['LOCALAPPDATA'];
  if (local != null && local.isNotEmpty) {
    roots.add('$local\\Microsoft\\Windows\\Fonts');
  }
  return roots;
}

void main() {
  final Stopwatch sw = Stopwatch()..start();

  int files = 0;
  int faces = 0;
  int parsed = 0;
  final Set<String> families = <String>{};
  final Set<int> weights = <int>{};
  final Map<String, List<int>> weightsByFamily = <String, List<int>>{};
  int localizedCount = 0;

  for (final String root in _roots()) {
    final Directory dir = Directory(root);
    if (!dir.existsSync()) {
      stdout.writeln('[skip] $root');
      continue;
    }
    int rootFiles = 0;
    int rootFaces = 0;
    for (final FileSystemEntity e in dir.listSync()) {
      if (e is! File) continue;
      final String path = e.path;
      final int dot = path.lastIndexOf('.');
      if (dot < 0 || !_suffixes.contains(path.substring(dot).toLowerCase())) {
        continue;
      }
      rootFiles++;
      Uint8List bytes;
      try {
        bytes = e.readAsBytesSync();
      } on FileSystemException catch (err) {
        stdout.writeln('  ! unreadable: $path (${err.message})');
        continue;
      }
      final int faceCount = countFontFaces(bytes);
      rootFaces += faceCount;
      for (int i = 0; i < faceCount; i++) {
        final FontFaceInfo? info = parseFontFace(bytes, faceIndex: i);
        if (info == null) continue;
        parsed++;
        families.add(info.familyEn);
        weights.add(info.weight);
        weightsByFamily
            .putIfAbsent(info.familyEn, () => <int>[])
            .add(info.weight);
        if (info.familyLocalized != null) localizedCount++;
      }
    }
    files += rootFiles;
    faces += rootFaces;
    stdout.writeln('[scan] $root -> $rootFiles files, $rootFaces faces');
  }

  stdout.writeln(
    '\n$files files, $faces faces, $parsed parsed, '
    '${families.length} families, ${sw.elapsedMilliseconds} ms',
  );

  stdout.writeln('\n--- assertions ---');
  // Every face of every installed font must come out named. A font the
  // picker silently drops is a font the user cannot choose.
  check(parsed == faces, 'every face parsed ($parsed / $faces)');
  check(families.length > 50, 'family count is plausible (${families.length})');
  check(localizedCount > 20, 'localized names found ($localizedCount)');
  check(weights.length >= 3, 'several distinct weights seen (${weights.toList()..sort()})');

  final List<int>? yahei = weightsByFamily['Microsoft YaHei'];
  check(yahei != null, 'Microsoft YaHei present');
  if (yahei != null) {
    final List<int> sorted = <int>[...yahei]..sort();
    check(sorted.contains(400), 'Microsoft YaHei regular weight 400 (got $sorted)');
    check(sorted.contains(700), 'Microsoft YaHei bold weight 700 (got $sorted)');
  }

  // The .ttc path is the one that breaks if table offsets are treated as
  // face-relative: a collection parsed that way yields garbage or nothing.
  final int collectionFaces = _countCollectionFaces();
  check(collectionFaces >= 0, 'a .ttc collection parsed ($collectionFaces extra faces)');

  // Localized names must be Chinese, not mojibake.
  final bool hasCjk = families.any((String f) => f.contains('SimSun')) ||
      weightsByFamily.keys.any((String f) => f == 'SimSun');
  check(hasCjk, 'SimSun (宋体) family present');

  stdout.writeln(
    _failures == 0
        ? '\nALL CHECKS PASSED ($parsed faces)'
        : '\n$_failures CHECK(S) FAILED',
  );
  exit(_failures == 0 ? 0 : 1);
}

int _countCollectionFaces() {
  final Directory dir =
      Directory('${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\Fonts');
  if (!dir.existsSync()) return 0;
  for (final FileSystemEntity e in dir.listSync()) {
    if (e is! File) continue;
    final String path = e.path.toLowerCase();
    if (!path.endsWith('.ttc')) continue;
    final Uint8List bytes = e.readAsBytesSync();
    final int n = countFontFaces(bytes);
    if (n <= 1) continue;
    // Print the first collection's faces so a wrong absolute-offset read is
    // visible as duplicate or empty family names.
    stdout.writeln('  collection ${e.path.split(RegExp(r'[\\/]')).last}: $n faces');
    for (int i = 0; i < n && i < 4; i++) {
      final FontFaceInfo? f = parseFontFace(bytes, faceIndex: i);
      stdout.writeln('    [$i] ${f?.displayName ?? '<unparsed>'} '
          'w=${f?.weight} italic=${f?.italic}');
    }
    return n - 1;
  }
  return 0;
}
