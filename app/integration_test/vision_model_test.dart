// Runs on a phone or emulator:  flutter test integration_test/vision_model_test.dart
// Checks that the bundled TFLite model gives the same outputs on the device as in Python
// (ml/train_vision.py). The input is an already prepared 224 x 224 PNG, so image decoding
// differences are excluded.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:zapwise/core/recognition/vision_model.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('vision model output matches the Python reference', (tester) async {
    final model = await VisionModel.load();
    final png = (await rootBundle.load('assets/selftest/reference_224.png')).buffer.asUint8List();
    final ref = jsonDecode(await rootBundle.loadString('assets/selftest/reference_outputs.json')) as Map<String, dynamic>;
    final im = img.decodePng(png)!;
    final input = Float32List(224 * 224 * 3);
    var i = 0;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final p = im.getPixel(x, y);
        input[i++] = p.r.toDouble();
        input[i++] = p.g.toDouble();
        input[i++] = p.b.toDouble();
      }
    }
    final out = model.run(input);
    var best = 0;
    for (var k = 1; k < out.probs.length; k++) {
      if (out.probs[k] > out.probs[best]) best = k;
    }
    expect(best, ref['top_class_index']);
    final head = (ref['embedding_head_normalized'] as List).cast<num>();
    for (var k = 0; k < head.length; k++) {
      expect(out.embedding[k], closeTo(head[k].toDouble(), 2e-3));
    }
    model.close();
  });
}
