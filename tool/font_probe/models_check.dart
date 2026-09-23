// Local verification for the persisted font selection.
//
// Pure Dart on purpose: `flutter test` and `dart analyze` both die in this
// sandbox creating the pipe for a child process, while `dart <file>` runs
// fine. The parts of the feature that touch no Flutter API are verified here
// and in parser_check.dart; the rest is proved on CI.
//
// Run: dart tool/font_probe/models_check.dart

import 'dart:io';

import 'package:tonkatsu_box/core/services/app_font_config.dart';
import 'package:tonkatsu_box/core/services/system_font_models.dart';

int _failures = 0;

void check(bool ok, String label) {
  if (!ok) _failures++;
  stdout.writeln('${ok ? '  ok  ' : ' FAIL '} $label');
}

void main() {
  stdout.writeln('--- defaults ---');
  check(defaultFontFamily == 'Inter', 'default family is the bundled Inter');
  check(
    fontRegistrationKey('Microsoft YaHei') == 'TK:Microsoft YaHei',
    'registration key is namespaced',
  );
  check(
    const AppFontConfig.defaults().isDefault,
    'AppFontConfig.defaults() counts as default',
  );

  stdout.writeln('\n--- round trip ---');
  const SystemFontFamily sample = SystemFontFamily(
    familyEn: 'Microsoft YaHei',
    localizedName: '微软雅黑',
    files: <SystemFontFile>[
      SystemFontFile(
        path: r'C:\Windows\Fonts\msyh.ttc',
        weight: 400,
        italic: false,
      ),
      SystemFontFile(
        path: r'C:\Windows\Fonts\msyhbd.ttc',
        weight: 700,
        italic: false,
      ),
    ],
  );

  final String encoded = sample.encode();
  check(encoded.contains('微软雅黑'), 'CJK survives encoding: $encoded');

  final SystemFontFamily? restored = SystemFontFamily.decode(encoded);
  check(restored != null, 'selection decodes');
  check(
    restored?.familyEn == 'Microsoft YaHei',
    'family name preserved (${restored?.familyEn})',
  );
  check(
    restored?.localizedName == '微软雅黑',
    'localized name preserved (${restored?.localizedName})',
  );
  check(
    restored?.displayName == 'Microsoft YaHei（微软雅黑）',
    'display name composed (${restored?.displayName})',
  );
  check(restored?.weightCount == 2, 'both files preserved');
  check(
    restored?.files.first.weight == 400 && restored?.files.last.weight == 700,
    'weights preserved ${restored?.files.map((SystemFontFile f) => f.weight).toList()}',
  );
  check(
    restored?.files.first.path == r'C:\Windows\Fonts\msyh.ttc',
    'Windows path preserved (backslashes, colon)',
  );
  check(
    restored?.files.first.fileName == 'msyh.ttc',
    'file name derived (${restored?.files.first.fileName})',
  );

  stdout.writeln('\n--- rejections (each must fall back, not throw) ---');
  check(SystemFontFamily.decode(null) == null, 'null');
  check(SystemFontFamily.decode('') == null, 'empty string');
  check(SystemFontFamily.decode('not json at all') == null, 'garbage');
  check(SystemFontFamily.decode('{"family":""}') == null, 'empty family');
  check(
    SystemFontFamily.decode('{"family":"X","files":[]}') == null,
    'no files',
  );
  check(
    SystemFontFamily.decode('{"family":"X"}') == null,
    'files key missing',
  );
  check(
    SystemFontFamily.decode('{"family":"X","files":[{"p":""}]}') == null,
    'file without a path',
  );
  check(
    SystemFontFamily.decode('{"family":"X","files":[{"p":"C:/a.ttf"}]}')
        ?.files
        .first
        .weight ==
        400,
    'missing weight defaults to 400',
  );
  check(
    SystemFontFamily.decode('{"family":"X","files":[{"p":"C:/a.ttf"}]}')
        ?.localizedName ==
        null,
    'missing localized name is null',
  );

  stdout.writeln('\n--- half-broken payloads keep what is usable ---');
  final SystemFontFamily? partial = SystemFontFamily.decode(
    '{"family":"X","files":[{"p":"C:/a.ttf"},{"bogus":1},{"p":"C:/b.ttf"}]}',
  );
  check(partial != null, 'a family survives invalid entries');
  check(partial?.weightCount == 2, 'only valid files kept (${partial?.weightCount})');

  stdout.writeln(
    _failures == 0 ? '\nALL CHECKS PASSED' : '\n$_failures CHECK(S) FAILED',
  );
  exit(_failures == 0 ? 0 : 1);
}
