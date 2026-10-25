// ML Kit on-device OCR and barcode reading for one photo.
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class TextRead {
  final String text; // lines joined with newlines, in reading order of ML Kit blocks
  final List<String> barcodes;
  const TextRead(this.text, this.barcodes);
}

class TextReader {
  final _text = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcode = BarcodeScanner(formats: [BarcodeFormat.upca, BarcodeFormat.upce, BarcodeFormat.ean13, BarcodeFormat.ean8]);
  Object? lastError; // the last reader failure, for debugging; the scan carries on without that reader

  Future<TextRead> read(String imagePath, {bool barcodes = true}) async {
    final input = InputImage.fromFilePath(imagePath);
    final lines = <String>[];
    try {
      final recognized = await _text.processImage(input);
      for (final block in recognized.blocks) {
        for (final line in block.lines) {
          lines.add(line.text);
        }
      }
    } catch (e) {
      lastError = e;
    }
    final codes = <String>[];
    if (barcodes) {
      try {
        for (final b in await _barcode.processImage(input)) {
          final v = b.rawValue;
          if (v != null && v.isNotEmpty) codes.add(v);
        }
      } catch (e) {
        lastError = e;
      }
    }
    return TextRead(lines.join('\n'), codes);
  }

  Future<void> close() async {
    await _text.close();
    await _barcode.close();
  }
}
