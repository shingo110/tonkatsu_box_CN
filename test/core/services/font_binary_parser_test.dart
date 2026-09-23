import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonkatsu_box/core/services/font_binary_parser.dart';

/// The parser is the load-bearing part of the system-font picker: it turns an
/// opaque font binary into a family name a picker can show and a `FontLoader`
/// can register. These fixtures are synthesised byte by byte so the suite
/// runs anywhere — no Windows, no fonts installed.

void main() {
  group('name table', () {
    test('reads the Windows en-US family', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Test Sans'),
        ]),
      });

      final FontFaceInfo? info = parseFontFace(font);

      expect(info, isNotNull);
      expect(info!.familyEn, 'Test Sans');
      expect(info.familyLocalized, isNull);
      expect(info.displayName, 'Test Sans');
    });

    test('keeps the localized family alongside the English one', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Test Sans'),
          _Rec.win(_langZhCn, _nameIdFamily, '测试黑体'),
        ]),
      });

      final FontFaceInfo info = parseFontFace(font)!;

      expect(info.familyEn, 'Test Sans');
      expect(info.familyLocalized, '测试黑体');
      expect(info.displayName, 'Test Sans（测试黑体）');
    });

    test('accepts a language-neutral record', () {
      // Windows writes 0x0000 for some families. Ignoring it loses the name.
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langNeutral, _nameIdFamily, 'Neutral Sans'),
        ]),
      });

      expect(parseFontFace(font)!.familyEn, 'Neutral Sans');
    });

    test('prefers the typographic family over the legacy one', () {
      // id 1 groups the Segoe UI set under one legacy name; id 16 is the real
      // family. A picker that shows id 1 would list them all as "Segoe UI".
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Legacy Group'),
          _Rec.win(_langEnUs, _nameIdTypoFamily, 'Real Family'),
        ]),
      });

      expect(parseFontFace(font)!.familyEn, 'Real Family');
    });

    test('drops a localized name identical to the English one', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Same Name'),
          _Rec.win(_langZhCn, _nameIdFamily, 'Same Name'),
        ]),
      });

      final FontFaceInfo info = parseFontFace(font)!;

      expect(info.familyLocalized, isNull);
      expect(info.displayName, 'Same Name');
    });

    test('falls back to a Mac record when Windows has none', () {
      // A face with only a Mac platform record still needs a name: dropping
      // it would hide a perfectly usable font from the picker.
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.mac(_nameIdTypoFamily, 'Mac Face'),
        ]),
      });

      final FontFaceInfo info = parseFontFace(font)!;

      expect(info.familyEn, 'Mac Face');
      expect(info.familyLocalized, isNull);
    });
  });

  group('weight and style', () {
    test('reads OS/2 usWeightClass', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Bold Face'),
        ]),
        'OS/2': _os2(weight: 700),
      });

      expect(parseFontFace(font)!.weight, 700);
    });

    test('falls back to 400 without an OS/2 table', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'No OS2'),
        ]),
      });

      expect(parseFontFace(font)!.weight, 400);
    });

    test('rejects a nonsense weight', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Bad Weight'),
        ]),
        'OS/2': _os2(weight: 0),
      });

      expect(parseFontFace(font)!.weight, 400);
    });

    test('reads italic from OS/2 fsSelection', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Italic Face'),
        ]),
        'OS/2': _os2(weight: 400, italic: true),
      });

      expect(parseFontFace(font)!.italic, isTrue);
    });

    test('falls back to head.macStyle for italic', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Old Italic'),
        ]),
        'head': _head(italic: true),
      });

      expect(parseFontFace(font)!.italic, isTrue);
    });
  });

  group('face selection', () {
    test('counts the faces of a plain font as one', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Single'),
        ]),
      });

      expect(countFontFaces(font), 1);
    });

    test('walks a .ttc and resolves each face independently', () {
      // The table offsets inside a .ttc are absolute from the file start. A
      // parser that adds the face base on top reads whatever sits at that
      // offset in the previous face's data — so the two names below must
      // differ for this test to mean anything.
      final Uint8List ttc = _ttc(<Map<String, Uint8List>>[
        <String, Uint8List>{
          'name': _nameTable(<_Rec>[
            _Rec.win(_langEnUs, _nameIdFamily, 'Collection Regular'),
          ]),
        },
        <String, Uint8List>{
          'name': _nameTable(<_Rec>[
            _Rec.win(_langEnUs, _nameIdFamily, 'Collection Bold'),
          ]),
          'OS/2': _os2(weight: 700),
        },
      ]);

      expect(countFontFaces(ttc), 2);
      expect(parseFontFace(ttc)!.familyEn, 'Collection Regular');
      expect(parseFontFace(ttc)!.weight, 400);
      expect(parseFontFace(ttc, faceIndex: 1)!.familyEn, 'Collection Bold');
      expect(parseFontFace(ttc, faceIndex: 1)!.weight, 700);
    });

    test('returns null for an out-of-range face index', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': _nameTable(<_Rec>[
          _Rec.win(_langEnUs, _nameIdFamily, 'Only One'),
        ]),
      });

      expect(parseFontFace(font, faceIndex: 3), isNull);
      expect(parseFontFace(font, faceIndex: -1), isNull);
    });
  });

  group('malformed input', () {
    test('returns null when the face carries no name table', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'head': _head(),
      });

      expect(parseFontFace(font), isNull);
    });

    test('survives empty and non-font bytes', () {
      expect(parseFontFace(Uint8List(0)), isNull);
      expect(countFontFaces(Uint8List(0)), 1);
      // Image bytes start with 'PNG'-ish signatures and their own "sizes".
      final Uint8List garbage = Uint8List.fromList(<int>[
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
        0xFF, 0xFF, 0xFF, 0xFF, 0x7F, 0x00, 0x00, 0x01,
      ]);
      expect(parseFontFace(garbage), isNull);
    });

    test('ignores a truncated name table instead of throwing', () {
      final Uint8List font = _sfnt(<String, Uint8List>{
        'name': Uint8List.fromList(<int>[0, 0, 0xFF, 0xFF, 0, 6]),
      });

      expect(parseFontFace(font), isNull);
    });
  });
}

// ---------------------------------------------------------------------------
// Fixture builders
// ---------------------------------------------------------------------------

const int _nameIdFamily = 1;
const int _nameIdTypoFamily = 16;
const int _langEnUs = 0x0409;
const int _langZhCn = 0x0804;
const int _langNeutral = 0x0000;

final class _Rec {
  const _Rec({
    required this.platform,
    required this.language,
    required this.nameId,
    required this.value,
  });

  /// Platform 3 (Windows), UTF-16BE.
  _Rec.win(int language, int nameId, String value)
      : this(platform: 3, language: language, nameId: nameId, value: value);

  /// Platform 1 (Mac Roman), single-byte.
  _Rec.mac(int nameId, String value)
      : this(platform: 1, language: 0, nameId: nameId, value: value);

  final int platform;
  final int language;
  final int nameId;
  final String value;
}

Uint8List _encode(String value, int platform) {
  if (platform == 0 || platform == 3) {
    final Uint8List out = Uint8List(value.length * 2);
    for (int i = 0; i < value.length; i++) {
      final int c = value.codeUnitAt(i);
      out[i * 2] = (c >> 8) & 0xFF;
      out[i * 2 + 1] = c & 0xFF;
    }
    return out;
  }
  return Uint8List.fromList(value.codeUnits);
}

Uint8List _nameTable(List<_Rec> recs) {
  final BytesBuilder bb = BytesBuilder();
  final int stringOffset = 6 + 12 * recs.length;
  final ByteData header = ByteData(6)
    ..setUint16(0, 0) // format 0
    ..setUint16(2, recs.length)
    ..setUint16(4, stringOffset);
  bb.add(header.buffer.asUint8List());

  final List<Uint8List> blobs = <Uint8List>[];
  int cursor = 0;
  for (final _Rec r in recs) {
    final Uint8List bytes = _encode(r.value, r.platform);
    final ByteData rec = ByteData(12)
      ..setUint16(0, r.platform)
      ..setUint16(2, 1) // encoding
      ..setUint16(4, r.language)
      ..setUint16(6, r.nameId)
      ..setUint16(8, bytes.length)
      ..setUint16(10, cursor);
    bb.add(rec.buffer.asUint8List());
    blobs.add(bytes);
    cursor += bytes.length;
  }
  for (final Uint8List b in blobs) {
    bb.add(b);
  }
  return bb.toBytes();
}

Uint8List _os2({int weight = 400, bool italic = false}) {
  final ByteData d = ByteData(78);
  d.setUint16(0, 4); // version
  d.setUint16(4, weight);
  d.setUint16(62, italic ? 0x01 : 0x00);
  return d.buffer.asUint8List();
}

Uint8List _head({bool italic = false}) {
  final ByteData d = ByteData(54);
  d.setUint32(0, 0x00010000);
  d.setUint32(12, 0x5F0F3CF5); // magic number
  d.setUint16(44, italic ? 0x02 : 0x00);
  return d.buffer.asUint8List();
}

/// A single-face sfnt with the given tables, laid out back to back.
Uint8List _sfnt(Map<String, Uint8List> tables) {
  final BytesBuilder bb = BytesBuilder();
  final ByteData header = ByteData(12)
    ..setUint32(0, 0x00010000)
    ..setUint16(4, tables.length);
  bb.add(header.buffer.asUint8List());

  int offset = 12 + 16 * tables.length;
  final List<Uint8List> blobs = <Uint8List>[];
  for (final MapEntry<String, Uint8List> e in tables.entries) {
    final ByteData rec = ByteData(16);
    rec.buffer.asUint8List().setRange(0, 4, e.key.codeUnits);
    rec.setUint32(8, offset);
    rec.setUint32(12, e.value.length);
    bb.add(rec.buffer.asUint8List());
    blobs.add(e.value);
    offset += e.value.length;
  }
  for (final Uint8List b in blobs) {
    bb.add(b);
  }
  return bb.toBytes();
}

/// A `.ttc` wrapping [faces], with every table offset absolute from the file
/// start — the layout real collections use.
Uint8List _ttc(List<Map<String, Uint8List>> faces) {
  final int headerSize = 12 + 4 * faces.length;
  final List<int> bases = <int>[];
  int cursor = headerSize;
  for (final Map<String, Uint8List> t in faces) {
    bases.add(cursor);
    cursor += 12 + 16 * t.length;
  }

  int blob = cursor;
  final List<Uint8List> dirs = <Uint8List>[];
  final List<Uint8List> blobs = <Uint8List>[];
  for (final Map<String, Uint8List> tables in faces) {
    final BytesBuilder dir = BytesBuilder();
    final ByteData header = ByteData(12)
      ..setUint32(0, 0x00010000)
      ..setUint16(4, tables.length);
    dir.add(header.buffer.asUint8List());
    for (final MapEntry<String, Uint8List> e in tables.entries) {
      final ByteData rec = ByteData(16);
      rec.buffer.asUint8List().setRange(0, 4, e.key.codeUnits);
      rec.setUint32(8, blob);
      rec.setUint32(12, e.value.length);
      dir.add(rec.buffer.asUint8List());
      blobs.add(e.value);
      blob += e.value.length;
    }
    dirs.add(dir.toBytes());
  }

  final BytesBuilder bb = BytesBuilder();
  final ByteData header = ByteData(12)
    ..setUint32(0, 0x74746366) // 'ttcf'
    ..setUint32(4, 0x00010000)
    ..setUint32(8, faces.length);
  bb.add(header.buffer.asUint8List());
  final ByteData offsets = ByteData(4 * faces.length);
  for (int i = 0; i < bases.length; i++) {
    offsets.setUint32(i * 4, bases[i]);
  }
  bb.add(offsets.buffer.asUint8List());
  for (final Uint8List d in dirs) {
    bb.add(d);
  }
  for (final Uint8List b in blobs) {
    bb.add(b);
  }
  return bb.toBytes();
}
