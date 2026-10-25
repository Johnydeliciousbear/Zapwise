// Photo -> 224 x 224 x 3 float input for the vision model.
// Same steps as ml/common.py: upright (EXIF), centre square crop, box-average resize, RGB 0..255.
// Difference: large JPEGs are decoded here at 1/2-1/8 scale for speed, Python decodes at full size.
// Both then average down to 224 px, so values differ slightly; check one real photo on a phone.
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int kModelSize = 224;

/// Picks the JPEG decode scale (1, 2, 4 or 8) so the short side stays at least 2 x 224.
int decodeScaleFor(int width, int height, {int target = kModelSize * 2}) {
  final shortSide = width < height ? width : height;
  var s = 1;
  while (s < 8 && shortSide ~/ (s * 2) >= target) {
    s *= 2;
  }
  return s;
}

Float32List imageToInput(img.Image src) {
  final upright = img.bakeOrientation(src);
  final side = upright.width < upright.height ? upright.width : upright.height;
  final cropped = img.copyCrop(upright, x: (upright.width - side) ~/ 2, y: (upright.height - side) ~/ 2, width: side, height: side);
  final small = img.copyResize(cropped, width: kModelSize, height: kModelSize, interpolation: img.Interpolation.average);
  final out = Float32List(kModelSize * kModelSize * 3);
  var i = 0;
  for (var y = 0; y < kModelSize; y++) {
    for (var x = 0; x < kModelSize; x++) {
      final p = small.getPixel(x, y);
      // normalised channel x 255 keeps 0..255 for 8-bit and 16-bit images alike
      out[i++] = (p.rNormalized * 255.0).toDouble();
      out[i++] = (p.gNormalized * 255.0).toDouble();
      out[i++] = (p.bNormalized * 255.0).toDouble();
    }
  }
  return out;
}

/// Decodes a JPEG (or other format) and prepares the model input off the UI isolate.
/// The image header is read first so large photos decode at a reduced scale.
Future<Float32List?> prepareModelInput(Uint8List bytes) => Isolate.run(() {
      img.Image? decoded;
      final info = img.JpegDecoder().startDecode(bytes);
      if (info != null) {
        decoded = img.decodeJpg(bytes, scale: decodeScaleFor(info.width, info.height));
      }
      decoded ??= img.decodeImage(bytes);
      if (decoded == null) return null;
      return imageToInput(decoded);
    });
