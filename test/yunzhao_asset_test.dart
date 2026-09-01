import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled YunZhao portrait is complete and decodes', () async {
    final data = await rootBundle.load('assets/images/yunzhao_hero_v2.png');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    // A truncated PNG can still have a valid header and nonzero file size.
    const pngEnd = <int>[0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130];
    expect(bytes.length, greaterThan(pngEnd.length));
    expect(bytes.sublist(bytes.length - pngEnd.length), orderedEquals(pngEnd));

    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  });
}
