// On-device vision model (assets/models/zapwise_vision.tflite) with two outputs:
// a 1280-number embedding for product look-up and material/container probabilities.
// Output tensors are picked by shape, because the converter does not keep output order.
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as m;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'image_prep.dart';

class VisionOutput {
  final Float32List embedding; // L2-normalised
  final List<double> probs;
  const VisionOutput(this.embedding, this.probs);
}

class VisionLabels {
  final List<String> classes;
  final List<String> appKeys;
  final int embeddingDim;
  const VisionLabels(this.classes, this.appKeys, this.embeddingDim);

  factory VisionLabels.fromJson(Map<String, dynamic> j) => VisionLabels(
        [for (final c in j['classes'] as List) c as String],
        [for (final c in j['app_keys'] as List) c as String],
        (j['embedding_dim'] ?? 1280) as int,
      );
}

class VisionModel {
  static const modelAsset = 'assets/models/zapwise_vision.tflite';
  static const labelsAsset = 'assets/models/vision_labels.json';

  final Interpreter _interpreter;
  final VisionLabels labels;
  final int _embIndex;
  final int _clsIndex;
  final int _nOutputs;
  bool _busy = false;

  VisionModel._(this._interpreter, this.labels, this._embIndex, this._clsIndex, this._nOutputs);

  static Future<VisionModel> load() async {
    final options = InterpreterOptions()..threads = 4;
    try {
      if (Platform.isAndroid) options.addDelegate(XNNPackDelegate());
    } catch (_) {
      // delegate not available on this device: plain CPU
    }
    final interpreter = await Interpreter.fromAsset(modelAsset, options: options);
    final labels = VisionLabels.fromJson(jsonDecode(await rootBundle.loadString(labelsAsset)) as Map<String, dynamic>);
    final outs = interpreter.getOutputTensors();
    var emb = -1, cls = -1;
    for (var i = 0; i < outs.length; i++) {
      final last = outs[i].shape.last;
      if (last == labels.embeddingDim) {
        emb = i;
      } else if (last == labels.classes.length) {
        cls = i;
      }
    }
    if (emb < 0 || cls < 0) throw StateError('vision model outputs do not match vision_labels.json');
    return VisionModel._(interpreter, labels, emb, cls, outs.length);
  }

  /// Runs the model on a prepared 224 x 224 x 3 input (values 0..255).
  VisionOutput run(Float32List input) {
    if (_busy) throw StateError('vision model is busy');
    _busy = true;
    try {
      final emb = Float32List(labels.embeddingDim);
      final cls = Float32List(labels.classes.length);
      final outputs = <int, Object>{};
      for (var i = 0; i < _nOutputs; i++) {
        outputs[i] = i == _embIndex ? emb.buffer : (i == _clsIndex ? cls.buffer : Float32List(1).buffer);
      }
      _interpreter.runForMultipleInputs([input.buffer], outputs);
      var n = 0.0;
      for (final v in emb) {
        n += v * v;
      }
      n = m.sqrt(n);
      if (n > 0) {
        for (var i = 0; i < emb.length; i++) {
          emb[i] = emb[i] / n;
        }
      }
      return VisionOutput(emb, [for (final v in cls) v.toDouble()]);
    } finally {
      _busy = false;
    }
  }

  Future<VisionOutput?> runOnPhoto(Uint8List photoBytes) async {
    final input = await prepareModelInput(photoBytes);
    if (input == null) return null;
    return run(input);
  }

  void close() => _interpreter.close();
}
