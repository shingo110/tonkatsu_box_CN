// Throwaway probe: can we load a Windows font file at runtime and actually
// render with it? Covers the two risks of the "pick a system font" feature:
//   1. FontLoader from raw bytes -> a custom family name takes effect.
//   2. .ttc collections (msyh.ttc etc.) load at all.
//
// Run on a real Windows machine:
//   flutter test tool/font_probe/font_loading_probe_test.dart
// CI's `flutter test` only walks test/, so this file is never collected there.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

/// Renders [text] with [family] and returns the pixel width of the first line.
Future<double> _layoutWidth(String text, String family, double size) async {
  final ui.ParagraphBuilder builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family, fontSize: size))
        ..pushStyle(ui.TextStyle(fontFamily: family, fontSize: size))
        ..addText(text);
  final ui.Paragraph p = builder.build()..layout(const ui.ParagraphConstraints(width: 2000));
  return p.maxIntrinsicWidth;
}

/// Renders [text] to a bitmap and counts non-transparent pixels.
Future<int> _inkedPixels(String text, String family, double size) async {
  final ui.ParagraphBuilder builder =
      ui.ParagraphBuilder(ui.ParagraphStyle(fontFamily: family, fontSize: size))
        ..pushStyle(ui.TextStyle(color: const Color(0xFF000000), fontFamily: family, fontSize: size))
        ..addText(text);
  final ui.Paragraph p = builder.build()..layout(const ui.ParagraphConstraints(width: 1200));

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  canvas.drawParagraph(p, Offset.zero);
  final ui.Image image = await recorder.endRecording().toImage(1200, 200);
  final ByteData? bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (bytes == null) {
    return -1;
  }
  int inked = 0;
  for (int i = 3; i < bytes.lengthInBytes; i += 4) {
    if (bytes.getUint8(i) > 8) {
      inked++;
    }
  }
  return inked;
}

Future<void> _register(String family, File file) async {
  final Uint8List bytes = await file.readAsBytes();
  final ByteData data = bytes.buffer.asByteData();
  final FontLoader loader = FontLoader(family);
  loader.addFont(Future<ByteData>.value(data));
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String latin = 'AVWawoy';
  const String cjk = '微软雅黑';

  test('runtime font loading from Windows font files', () async {
    const String arial = r'C:\Windows\Fonts\arial.ttf';
    const String yaheiTtc = r'C:\Windows\Fonts\msyh.ttc';

    expect(File(arial).existsSync(), isTrue, reason: 'arial.ttf missing');
    expect(File(yaheiTtc).existsSync(), isTrue, reason: 'msyh.ttc missing');

    // Baseline: an unregistered family falls back to the test default font.
    final double fallbackW = await _layoutWidth(latin, 'NoSuchFamilyZZZ', 32);

    await _register('ProbeArial', File(arial));
    await _register('ProbeYaHei', File(yaheiTtc));

    final double arialW = await _layoutWidth(latin, 'ProbeArial', 32);
    final double yaheiW = await _layoutWidth(latin, 'ProbeYaHei', 32);

    // ignore: avoid_print
    print('latin width  fallback=$fallbackW arial=$arialW yahei=$yaheiW');
    expect(arialW, isNot(equals(fallbackW)),
        reason: 'registered family produced the fallback width -> load did not take effect');

    // Same family name loaded twice must be stable (no accumulation/failure).
    await _register('ProbeArial', File(arial));
    expect(await _layoutWidth(latin, 'ProbeArial', 32), equals(arialW));

    final int fallbackCjkInk = await _inkedPixels(cjk, 'NoSuchFamilyZZZ', 32);
    final int yaheiCjkInk = await _inkedPixels(cjk, 'ProbeYaHei', 32);
    // ignore: avoid_print
    print('cjk ink      fallback=$fallbackCjkInk yaheiTtc=$yaheiCjkInk');

    expect(yaheiCjkInk, greaterThan(0),
        reason: '.ttc glyphs did not reach the rasterizer');
    expect(yaheiCjkInk, isNot(equals(fallbackCjkInk)),
        reason: 'ttc render matches the fallback -> .ttc likely ignored');
  });
}
