/// Plain data for the system-font picker, kept free of `dart:io` so the web
/// build can name the types without pulling in the file system.
library;

import 'dart:convert';

/// One font file on disk.
///
/// A file — not a face — is the unit of registration: `FontLoader` takes a
/// whole binary and the engine renders **face 0** of it, so a `.ttc`
/// collection contributes exactly one selectable entry per file.
final class SystemFontFile {
  const SystemFontFile({
    required this.path,
    required this.weight,
    required this.italic,
  });

  static final RegExp _pathSeparator = RegExp(r'[\\/]');

  final String path;

  /// `OS/2.usWeightClass` of face 0 (100–900).
  final int weight;

  final bool italic;

  String get fileName => path.split(_pathSeparator).last;

  Map<String, Object?> toJson() => <String, Object?>{
    'p': path,
    'w': weight,
    'i': italic,
  };

  static SystemFontFile? fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    final Object? path = json['p'];
    if (path is! String || path.isEmpty) return null;
    final Object? weight = json['w'];
    final Object? italic = json['i'];
    return SystemFontFile(
      path: path,
      weight: weight is int ? weight : 400,
      italic: italic is bool && italic,
    );
  }

  @override
  String toString() => 'SystemFontFile($fileName, weight: $weight)';
}

/// An installed font family and every file that contributes to it.
///
/// Doubles as the persisted selection: the file list is stored alongside the
/// name so a cold start can register the font without re-scanning the disk.
final class SystemFontFamily {
  const SystemFontFamily({
    required this.familyEn,
    required this.localizedName,
    required this.files,
  });

  /// Family name as the platform font manager knows it — also the stable id
  /// written to preferences.
  final String familyEn;

  /// The same family in the system language (微软雅黑), when the font carries
  /// a distinct one.
  final String? localizedName;

  /// Sorted by weight, then upright before italic.
  final List<SystemFontFile> files;

  String get displayName =>
      localizedName == null ? familyEn : '$familyEn（$localizedName）';

  /// Number of files, i.e. how many weights the family can render.
  int get weightCount => files.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'family': familyEn,
    'localized': localizedName,
    'files': <Object?>[for (final SystemFontFile f in files) f.toJson()],
  };

  String encode() => jsonEncode(toJson());

  static SystemFontFamily? fromJson(Object? json) {
    if (json is! Map<Object?, Object?>) return null;
    final Object? family = json['family'];
    if (family is! String || family.isEmpty) return null;
    final Object? localized = json['localized'];
    final Object? files = json['files'];
    if (files is! List<Object?>) return null;
    final List<SystemFontFile> parsed = <SystemFontFile>[
      for (final Object? f in files)
        if (SystemFontFile.fromJson(f) case final SystemFontFile file) file,
    ];
    if (parsed.isEmpty) return null;
    return SystemFontFamily(
      familyEn: family,
      localizedName: localized is String && localized.isNotEmpty
          ? localized
          : null,
      files: parsed,
    );
  }

  /// Decodes a value read from preferences. A corrupt or half-written string
  /// yields `null` — the bundled font — rather than taking the app down.
  static SystemFontFamily? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return fromJson(jsonDecode(raw));
    } on FormatException catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'SystemFontFamily($displayName, $weightCount files)';
}
