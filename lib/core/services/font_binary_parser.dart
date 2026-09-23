import 'dart:typed_data';

/// Identity of one font face, decoded straight from the font binary.
///
/// Neither the file name nor the directory tells the truth about a font:
/// `C:\Windows\Fonts\msyh.ttc` is 微软雅黑 / Microsoft YaHei, and a `.ttc`
/// collection holds several faces under one name. The only reliable source is
/// the `name` table inside the file, which is what this parser reads.
///
/// Pure Dart on [Uint8List] on purpose: it is the part a system-font picker
/// can unit-test without a Windows box, or any font on the machine.
final class FontFaceInfo {
  const FontFaceInfo({
    required this.familyEn,
    required this.familyLocalized,
    required this.weight,
    required this.italic,
  });

  /// Family name as the platform font manager knows it (the Windows `en-US`
  /// or language-neutral record, e.g. `Microsoft YaHei`). This is also what
  /// the engine's system-font lookup matches against.
  final String familyEn;

  /// The same family in the system's own language (the Windows `zh-CN`
  /// record, e.g. 微软雅黑). `null` when the font carries none, or when it is
  /// identical to [familyEn].
  final String? familyLocalized;

  /// `OS/2.usWeightClass` (100–900). 400 when the table is absent.
  final int weight;

  final bool italic;

  /// Label for a picker: `Microsoft YaHei（微软雅黑）`.
  String get displayName =>
      familyLocalized == null ? familyEn : '$familyEn（$familyLocalized）';

  @override
  String toString() =>
      'FontFaceInfo($familyEn, weight: $weight, italic: $italic)';
}

/// Every entry in a `name` table is 6 x uint16, packed tight — no alignment
/// padding between records. Reading it as 16-byte-aligned structs (the shape
/// the fields suggest) walks off the end and decodes garbage.
const int _nameRecordSize = 12;

const int _platUnicode = 0;
const int _platMac = 1;
const int _platWindows = 3;

const int _langWinEnUs = 0x0409;
const int _langWinZhCn = 0x0804;

/// Windows writes a language-neutral record for some families; it carries a
/// perfectly good English name and is skipped at the reader's peril.
const int _langNeutral = 0x0000;

const int _nameIdFamily = 1;

/// `name` id 16 — the "typographic" family. Preferred over id 1 where present
/// (id 1 carries legacy grouping for families like the Segoe UI set).
const int _nameIdTypoFamily = 16;

const int _ttcTag =
    0x74746366; // 'ttcf'

const int _maxFaces = 4096;
const int _maxTables = 512;
const int _maxNameRecords = 4096;

/// Number of faces in [bytes] — 1 for a plain `.ttf`/`.otf`, many for a
/// `.ttc`/`.otc` collection.
int countFontFaces(Uint8List bytes) => _sfntOffsets(bytes).length;

/// Decodes the identity of the face at [faceIndex] (0-based).
///
/// Returns `null` when [bytes] is not a shape this parser understands, when
/// [faceIndex] is out of range, or when the face has no readable family name.
FontFaceInfo? parseFontFace(Uint8List bytes, {int faceIndex = 0}) {
  final List<int> bases = _sfntOffsets(bytes);
  if (faceIndex < 0 || faceIndex >= bases.length) return null;
  return _faceFrom(bytes, bases[faceIndex]);
}

/// Table-directory offsets, one per face.
///
/// Inside a `.ttc` every table offset is **absolute from the file start**, not
/// relative to the face's directory — adding the face base on top of them
/// reads unrelated bytes.
List<int> _sfntOffsets(Uint8List d) {
  if (d.length >= 12) {
    final ByteData bd = ByteData.sublistView(d);
    final int tag = bd.getUint32(0);
    if (tag == _ttcTag) {
      final int count = bd.getUint32(8);
      if (count <= 0 || count > _maxFaces || 12 + count * 4 > d.length) {
        return const <int>[];
      }
      return <int>[for (int i = 0; i < count; i++) bd.getUint32(12 + i * 4)];
    }
  }
  return <int>[0];
}

/// `tag` → `[offset, length]` for one face.
Map<String, List<int>> _tables(Uint8List d, int base) {
  final Map<String, List<int>> out = <String, List<int>>{};
  if (base + 12 > d.length) return out;
  final ByteData bd = ByteData.sublistView(d);
  final int numTables = bd.getUint16(base + 4);
  if (numTables <= 0 || numTables > _maxTables) return out;
  int off = base + 12;
  for (int i = 0; i < numTables; i++) {
    if (off + 16 > d.length) break;
    final String tag = String.fromCharCodes(d.sublist(off, off + 4));
    out[tag] = <int>[bd.getUint32(off + 8), bd.getUint32(off + 12)];
    off += 16;
  }
  return out;
}

/// Platform 0 (Unicode) and 3 (Windows) store UTF-16BE; platform 1 (Mac
/// Roman) is single-byte.
String _decode(Uint8List raw, int platformId) {
  if (platformId == _platUnicode || platformId == _platWindows) {
    final StringBuffer sb = StringBuffer();
    for (int i = 0; i + 1 < raw.length; i += 2) {
      sb.writeCharCode((raw[i] << 8) | raw[i + 1]);
    }
    return sb.toString();
  }
  return String.fromCharCodes(raw);
}

final class _NameRecord {
  const _NameRecord({
    required this.platformId,
    required this.languageId,
    required this.nameId,
    required this.value,
  });

  final int platformId;
  final int languageId;
  final int nameId;
  final String value;
}

List<_NameRecord> _nameRecords(Uint8List d, int nameOffset, int length) {
  if (nameOffset + 6 > d.length || nameOffset + length > d.length) {
    return const <_NameRecord>[];
  }
  final ByteData bd = ByteData.sublistView(d);
  final int format = bd.getUint16(nameOffset);
  final int count = bd.getUint16(nameOffset + 2);
  final int stringOffset = bd.getUint16(nameOffset + 4);
  // Format 1 appends language-tag records after the name records, but
  // `stringOffset` already points past them, so `storage` is unaffected.
  if ((format != 0 && format != 1) ||
      count > _maxNameRecords ||
      count <= 0) {
    return const <_NameRecord>[];
  }
  final int storage = nameOffset + stringOffset;
  final List<_NameRecord> out = <_NameRecord>[];
  for (int i = 0; i < count; i++) {
    final int rec = nameOffset + 6 + _nameRecordSize * i;
    if (rec + _nameRecordSize > d.length) break;
    final int platformId = bd.getUint16(rec);
    final int languageId = bd.getUint16(rec + 4);
    final int nameId = bd.getUint16(rec + 6);
    final int len = bd.getUint16(rec + 8);
    final int off = bd.getUint16(rec + 10);
    final int start = storage + off;
    if (len == 0 || start + len > d.length) continue;
    out.add(
      _NameRecord(
        platformId: platformId,
        languageId: languageId,
        nameId: nameId,
        value: _decode(d.sublist(start, start + len), platformId),
      ),
    );
  }
  return out;
}

/// `OS/2.usWeightClass` — the declared weight, 100–900.
int _weight(Uint8List d, Map<String, List<int>> tables) {
  final List<int>? os2 = tables['OS/2'];
  if (os2 == null || os2[0] + 6 > d.length) return 400;
  final ByteData bd = ByteData.sublistView(d);
  final int value = bd.getUint16(os2[0] + 4);
  return value >= 100 && value <= 900 ? value : 400;
}

/// Italic lives in two places; either one is enough. `head.macStyle` bit 1 is
/// the older signal, `OS/2.fsSelection` bit 0 the newer.
bool _italic(Uint8List d, Map<String, List<int>> tables) {
  final ByteData bd = ByteData.sublistView(d);
  final List<int>? os2 = tables['OS/2'];
  if (os2 != null && os2[0] + 64 <= d.length) {
    if (bd.getUint16(os2[0] + 62) & 0x01 != 0) return true;
  }
  final List<int>? head = tables['head'];
  if (head != null && head[0] + 46 <= d.length) {
    if (bd.getUint16(head[0] + 44) & 0x02 != 0) return true;
  }
  return false;
}

FontFaceInfo? _faceFrom(Uint8List d, int base) {
  final Map<String, List<int>> tables = _tables(d, base);
  final List<int>? name = tables['name'];
  if (name == null) return null;

  String? familyEn;
  String? familyZh;
  String? familyFallback;
  for (final _NameRecord r in _nameRecords(d, name[0], name[1])) {
    final String value = r.value.trim();
    if (value.isEmpty) continue;
    if (r.nameId != _nameIdFamily && r.nameId != _nameIdTypoFamily) continue;
    // Typographic family (16) beats legacy family (1) wherever both appear:
    // id 1 groups sets like the Segoe UI family under one legacy name.
    final bool preferred = r.nameId == _nameIdTypoFamily;
    if (r.platformId == _platWindows &&
        (r.languageId == _langWinEnUs || r.languageId == _langNeutral)) {
      if (familyEn == null || preferred) familyEn = value;
    } else if (r.platformId == _platWindows && r.languageId == _langWinZhCn) {
      if (familyZh == null || preferred) familyZh = value;
    } else if (r.platformId == _platUnicode || r.platformId == _platMac) {
      // These carry no language we can trust, so they only stand in for a
      // missing Windows record — dropping the font entirely would be worse.
      if (familyFallback == null || preferred) familyFallback = value;
    }
  }
  final String? primary = familyEn ?? familyFallback;
  if (primary == null) return null;
  return FontFaceInfo(
    familyEn: primary,
    familyLocalized: familyZh == primary ? null : familyZh,
    weight: _weight(d, tables),
    italic: _italic(d, tables),
  );
}
