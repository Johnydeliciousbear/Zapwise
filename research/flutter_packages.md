# Flutter on-device recognition: package research (checked 2026-10-14)

Legend:
- [V] verified this session from pub.dev pages, the API reference, or package source on GitHub.
- [I] inferred from verified source code. The behavior follows from the code, but the docs do not state it.
- [U] unverified. Written from memory or general knowledge. Check it before relying on it.

---

## 0. Flutter / Dart SDK (October 2026)

| Item | Value | Status |
|---|---|---|
| Current Flutter stable | 3.47 (announced in the "What's new in Flutter 3.47" post, dated 2026-08-12) | [V] the exact patch number (3.47.x) is [U] |
| Dart shipped with 3.47 | 3.13 | [V] (codewithandrea newsletter, Aug 2026) |
| Previous stable | Flutter 3.44 / Dart 3.12 (Google I/O, May 2026) | [V] |
| Floor set by this dependency set | camera 0.12.1 requires Flutter >= 3.44 and Dart >= 3.12 | [V] camera changelog |
| Changes in 3.47 that affect this app | iOS minimum deployment target raised from 13 to 15. Default Android `flutter.minSdkVersion` = 24 and compile/target SDK = 36. SwiftPM is still opt-in, and CocoaPods is in maintenance mode. Material/Cupertino are moving to the standalone `material_ui`/`cupertino_ui` packages. That move is opt-in, and deprecation of the SDK-bundled versions is scheduled for Nov 2026. | [V] |

```yaml
environment:
  sdk: ^3.12.0          # Dart 3.12+ (Flutter 3.44+). 3.13 is current.
  flutter: ">=3.44.0"
```

Sources:
- https://flutter.dev/blog/whats-new-in-flutter-3-47
- https://codewithandrea.com/newsletter/august-2026
- https://codewithandrea.com/newsletter/may-2026/
- https://pub.dev/packages/camera/changelog

---

## 1. tflite_flutter

- Latest stable: 0.12.1, published 2025-10-28 by tensorflow.org. No newer release exists as of 2026-10-14. [V]
- pubspec: `tflite_flutter: ^0.12.1` (the README usage section still says `^0.10.1`, which is out of date). [V]
- The package itself declares `sdk: '>=3.3.0 <4.0.0'`, `flutter: '>=1.10.0'`, and is an FFI plugin on android/ios/macos/linux/windows. [V]
- 0.12.1 is the release that fixes Android 16 KB page-size support. Android moved from TF Lite 2.12.0 to Google AI Edge LiteRT 1.4.0 (`com.google.ai.edge.litert:litert` and `litert-gpu`, version 1.4.0). Do not use 0.12.0, because its 16 KB claim was wrong. [V]
- iOS is still on `TensorFlowLiteSwift` 2.12.0, plus the `/Metal` and `/CoreML` subspecs, with `static_framework = true` and `s.platform = :ios, '11.0'`. [V] Because Android and iOS run different runtimes, a model that uses newer op versions could load on Android and fail on iOS. Test the model on both platforms. [I]
- `tflite_flutter_helper` is deprecated (the README points to flutter-mediapipe). Do preprocessing with `package:image` instead. [V]

### API signatures [V] (pub.dev API reference and lib/src/*.dart)

```dart
// Interpreter
static Future<Interpreter> fromAsset(String assetName, {InterpreterOptions? options})
factory Interpreter.fromBuffer(Uint8List buffer, {InterpreterOptions? options})
factory Interpreter.fromFile(File modelFile, {InterpreterOptions? options})
factory Interpreter.fromAddress(int address, {bool allocated = false, bool deleted = false})
void run(Object input, Object output)
void runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs)
void runInference(List<Object> inputs)          // public; used by IsolateInterpreter
Tensor getInputTensor(int index);   Tensor getOutputTensor(int index)
List<Tensor> getInputTensors();     List<Tensor> getOutputTensors()
void resizeInputTensor(int tensorIndex, List<int> shape)   // then allocateTensors()
void allocateTensors();  void invoke();  void close()
int get address;  bool get isAllocated;  int get lastNativeInferenceDurationMicroSeconds

// InterpreterOptions
InterpreterOptions()
set threads(int)                       // CPU threads
set useNnApiForAndroid(bool)
set useMetalDelegateForIOS(bool)
void addDelegate(Delegate delegate)
void delete()

// Delegates (classes exported by the library)
GpuDelegateV2 / GpuDelegateOptionsV2     // Android GPU
GpuDelegate   / GpuDelegateOptions       // iOS Metal
XNNPackDelegate / XNNPackDelegateOptions
CoreMlDelegate  / CoreMlDelegateOptions  // iOS
// Delegate constructor parameters (e.g. `options:`) were NOT checked. [U]

// Tensor
String get name;  TensorType get type;  List<int> get shape;
Uint8List get data;  set data(Uint8List bytes);   // byte length must match exactly
QuantizationParams get params;   // field names scale / zeroPoint are [U]
int numBytes();  int numElements();   // methods, not getters
void setTo(Object src);  Object copyTo(Object dst);
// TensorType: float32, int32, uint8, int8, int16, int64, float16, float64, boolean, string, ...

// IsolateInterpreter
static Future<IsolateInterpreter> create({required int address, String debugName = 'TfLiteInterpreterIsolate'})
Future<void> run(Object input, Object output)
Future<void> runForMultipleInputs(List<Object> inputs, Map<int, Object> outputs)
Future<void> close()
IsolateInterpreterState get state;  Stream<IsolateInterpreterState> get stateChanges;  // idle | loading

// ListShape extension on List
List reshape<T>(List<int> shape);  List<int> get shape;  int get computeNumElements;  List<T> flatten<T>();
```

### Asset path convention [V]
`fromAsset` passes `assetName` unchanged to `rootBundle.load(assetName)`. It does NOT add an `assets/` prefix, so pass the full path exactly as declared in pubspec, for example `'assets/models/model.tflite'`. (Versions 0.9.x and older added the prefix themselves, so old tutorials pass `'model.tflite'`. [U])

```yaml
flutter:
  assets:
    - assets/models/      # contains model.tflite and labels.txt
```

### How input and output objects are handled (from the source) [V]
- In `runInference`, each input goes through `tensor.getInputShapeIfDifferent(input)`. If the shape it infers from the Dart object differs from the tensor's shape, the interpreter calls `resizeInputTensor` and re-allocates.
- `getInputShapeIfDifferent` returns null (no resize) only for `Uint8List` and `ByteBuffer`. Any other `List`, including `Float32List`, gets its shape inferred by walking `elementAt(0)` down each level.
  - So a flat `Float32List(150528)` passed straight in is read as shape `[150528]`, and the input tensor is resized to that shape, which breaks a `[1,224,224,3]` model. Pass `float32List.buffer` (a ByteBuffer) or `float32List.reshape([1,224,224,3])` instead. [V for the logic; the exact runtime error message is U]
- `convertObjectToBytes`: a `Uint8List` is copied as raw bytes. A `ByteBuffer` goes through `asUint8List()`. Any other `List` is converted element by element, recursively (slow for 150k elements). For a float32 tensor, each element must be a `num`. For int or uint8 tensors, each element must be an `int` (a `double` throws `ByteConversionError`).
- Because a `Uint8List` is treated as raw bytes, passing one to a float32 input does NOT convert values. Use it only for uint8-quantized inputs, or as the byte view of a Float32List.
- `run()` puts the output at map index 0 only. `runForMultipleInputs` loops over all output tensors with `outputs[i]!`, so a model with more than one output must use `runForMultipleInputs` with every output index present, or it throws.
- Output can be a nested List of the right shape (filled through `convertBytesToObject` + `reshape`) or a `ByteBuffer` (bytes are copied in).

### Code

```dart
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  late final Interpreter _interpreter;
  IsolateInterpreter? _isolate;

  Future<void> load() async {
    final options = InterpreterOptions()..threads = 4;
    // Delegates are optional. Creating one can fail on some devices or emulators,
    // so wrap delegate creation in try/catch and fall back to CPU.
    try {
      if (Platform.isAndroid) {
        options.addDelegate(XNNPackDelegate());       // the official example uses this on Android
        // options.addDelegate(GpuDelegateV2());      // example comment: "doesn't work on emulator"
      } else if (Platform.isIOS) {
        options.addDelegate(GpuDelegate());           // Metal
      }
    } catch (_) {/* keep CPU */}
    _interpreter = await Interpreter.fromAsset('assets/models/model.tflite', options: options);

    final inT = _interpreter.getInputTensor(0);
    final outT = _interpreter.getOutputTensor(0);
    // inT.shape -> [1, 224, 224, 3], inT.type -> TensorType.float32 (or uint8 for quantized)
    // outT.shape -> [1, N]
    _isolate = await IsolateInterpreter.create(address: _interpreter.address);
  }

  /// Float32 model, input normalized to [0,1]. Use (v - 127.5) / 127.5 if the model expects [-1,1].
  Float32List preprocess(img.Image src, {int size = 224}) {
    final resized = img.copyResize(src, width: size, height: size,
        interpolation: img.Interpolation.linear);
    final out = Float32List(size * size * 3);
    var i = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final p = resized.getPixel(x, y);   // Pixel; r/g/b are num, 0..255 for 8-bit images
        out[i++] = p.r / 255.0;
        out[i++] = p.g / 255.0;
        out[i++] = p.b / 255.0;
      }
    }
    return out;
  }

  /// Synchronous (blocks the calling isolate).
  Float32List runSync(Float32List input, int numClasses) {
    final output = Float32List(numClasses);
    _interpreter.run(input.buffer, output.buffer);   // ByteBuffer in and out: no resize, fast copy
    return output;
  }

  /// Off the UI isolate. Concurrent calls are DROPPED (see gotchas).
  Future<Float32List> runAsync(Float32List input, int numClasses) async {
    final output = Float32List(numClasses);
    await _isolate!.run(input.buffer, output.buffer);
    return output;
  }

  Future<void> dispose() async {
    await _isolate?.close();
    _interpreter.close();
  }
}

// Equivalent nested-List forms (slower, element-wise conversion):
// final input  = input.reshape([1, 224, 224, 3]);           // ListShape extension
// final output = [List<double>.filled(numClasses, 0.0)];    // shape [1, N]
// _interpreter.run(input, output);
//
// Quantized uint8 model (as in the official mobilenet_quant example):
// final output = [List<int>.filled(numClasses, 0)];
// Input: a Uint8List of raw RGB bytes (length 224*224*3) is passed through as-is.
//
// Multiple inputs/outputs:
// _interpreter.runForMultipleInputs([in0.buffer, in1.buffer], {0: out0.buffer, 1: out1.buffer});
```

### IsolateInterpreter behavior [V] (lib/src/isolate_interpreter.dart)
- The background isolate rebuilds the interpreter with `Interpreter.fromAddress(address)` and calls only `runInference(inputs)`. Outputs are copied into your objects on the calling isolate afterwards, with `getOutputTensors()` and `copyTo(outputs[i]!)`. Passing a `ByteBuffer` or a List as output therefore works.
- `if (state == IsolateInterpreterState.loading) return;`: a call made while another inference is still running returns at once, without running and without an error, and your output buffer stays zeros. Serialize the calls (await each one, or keep a "busy" flag) and check for an all-zero result.
- The official mobilenet example uses its own `Isolate` and `Interpreter.fromAddress` instead of IsolateInterpreter. Doing preprocessing and inference together in one `Isolate.run` is also fine.

### Android setup
- Native libraries come in through Gradle (LiteRT 1.4.0). You do not add `.so` files by hand. [V]
- minSdk: the plugin's `build.gradle` says `minSdkVersion 19`, but the README says "requires a device with a minimum API level of 26". The README note conflicts with the gradle file. Set `minSdk = 26` to be safe (camera needs at least 24 anyway). [V conflict; what actually works at API 24-25 is U]
- `compileSdkVersion 36`, AGP 8.6.1 (from the 0.12.0 changelog). Flutter 3.47 defaults to compile/target 36. [V]
- `aaptOptions { noCompress 'tflite' }` / `androidResources.noCompress`: NOT needed. The plugin's build.gradle has no such setting, and `fromAsset` reads the asset into memory through `rootBundle.load` and then calls `fromBuffer`. Nothing memory-maps the asset from the APK. (The old `tflite` plugin did, which is where this advice comes from.) [I]
- 16 KB page size: Google Play requires 16 KB page support for apps targeting Android 15+. [U policy detail] 0.12.1 is the version with 16 KB-aligned LiteRT libs. [V]
- The GPU delegate does not work on emulators (comment in the official example). [V]
- If release builds fail in R8 with missing `org.tensorflow.lite.gpu.*` classes, add `-dontwarn`/`-keep` rules for `org.tensorflow.lite.**`. [U, commonly reported]

### iOS setup
- CocoaPods only (podspec). `pod install` pulls TensorFlowLiteSwift 2.12.0, Metal, and CoreML automatically. [V] The repo was not checked for SwiftPM support [U]. Keep CocoaPods in any case, because ML Kit needs it.
- The TFLite simulator "may not work", so test on a physical device. [V]
- Release IPA: `flutter build ipa` can fail with `Failed to lookup symbol` because Xcode strips the symbols. In Xcode, open Runner, Build Settings, and change Strip Style from "All Symbols" to "Non-Global Symbols". [V]
- The deployment target is set by ML Kit (15.5), not by tflite. See section 4.

Sources:
- https://pub.dev/packages/tflite_flutter
- https://pub.dev/packages/tflite_flutter/changelog
- https://pub.dev/documentation/tflite_flutter/latest/tflite_flutter/
- https://pub.dev/documentation/tflite_flutter/latest/tflite_flutter/Interpreter-class.html
- https://pub.dev/documentation/tflite_flutter/latest/tflite_flutter/InterpreterOptions-class.html
- https://github.com/tensorflow/flutter-tflite (README)
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/lib/src/interpreter.dart
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/lib/src/isolate_interpreter.dart
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/lib/src/tensor.dart
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/lib/src/util/byte_conversion_utils.dart
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/android/build.gradle
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/ios/tflite_flutter.podspec
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/example/image_classification_mobilenet/lib/helper/image_classification_helper.dart
- https://raw.githubusercontent.com/tensorflow/flutter-tflite/main/example/image_classification_mobilenet/lib/helper/isolate_inference.dart

---

## 2. image (pure Dart)

- Latest stable: 4.12.0, published 2026-10-11. pubspec: `image: ^4.12.0`. Its only dependency is `archive ^4.5.0`. [V]
- Relevant changelog entries [V]:
  - 4.12.0: security hardening and a `maxPixels` limit on every decoder. `JpegDecoder.defaultMaxPixels` is deprecated in favor of `Decoder.defaultMaxPixels`. Encoders now throw on empty images.
  - 4.11.0: adds `scale` to `decodeJpg` (1/2/4/8 decode). `copyResize` now applies the EXIF orientation while resizing. `bakeOrientation` uses less memory.
  - 4.10.2: `decodeJpg(maxPixels:)`, default limit 2^28 pixels.
  - 4.5.3: the default background color changed from black to white.

### Signatures [V]

```dart
Image? decodeImage(Uint8List data, {int? frame})                    // tries every decoder, slower
Image? decodeJpg(Uint8List bytes, {int? maxPixels, int scale = 1})  // scale: 1, 2, 4, 8
Image copyResize(Image src, {int? width, int? height, bool? maintainAspect,
    Color? backgroundColor, Interpolation interpolation = Interpolation.nearest})
Image copyCrop(Image src, {required int x, required int y, required int width,
    required int height, num radius = 0, bool antialias = true})
Image bakeOrientation(Image image)   // returns a NEW image and sets exif.imageIfd.orientation = null
enum Interpolation { nearest, linear, cubic, average }

// Image
Pixel getPixel(int x, int y, [Pixel? pixel]);   // also getPixelSafe, getPixelClamped
Uint8List getBytes({ChannelOrder? order, num? alpha});
int get width; int get height; int get numChannels; Format get format; ExifData exif;
// Image is iterable: for (final p in image) { p.x, p.y, p.r ... }

// Pixel (r/g/b/a are inherited from Color)
num r, g, b, a;  num rNormalized, gNormalized, bNormalized;  int get x; int get y;
num get maxChannelValue;  num get luminance;
```

### EXIF orientation
- `JpegDecoder.decode` does not rotate pixels. It returns `jpeg.getImage()` and has no orientation code. [V] The orientation tag is kept in `image.exif`. [I]
- `bakeOrientation` rotates or flips the pixels to match the tag and clears the tag. [V]
- Since 4.11.0, `copyResize` also applies the EXIF orientation. `copyCrop` is not documented to do so. Bake first, then crop, then resize, so that crop coordinates refer to the upright image and nothing gets rotated twice. [V for the changelog entry, I for the ordering advice]

### Code

```dart
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Run off the UI isolate: decoding a 12 MP JPEG in pure Dart takes a long time.
Future<img.Image?> loadUpright(Uint8List jpegBytes, {int target = 224}) {
  return Isolate.run(() {
    // scale: 4 decodes at 1/4 size (for example 4032x3024 -> 1008x756), which is much faster
    // and still large enough for 224x224 input. Use scale: 1 for OCR crops.
    final decoded = img.decodeJpg(jpegBytes, scale: 4); // or img.decodeImage(bytes) for unknown formats
    if (decoded == null) return null;
    final upright = img.bakeOrientation(decoded);

    // center square crop
    final side = upright.width < upright.height ? upright.width : upright.height;
    final cropped = img.copyCrop(upright,
        x: (upright.width - side) ~/ 2,
        y: (upright.height - side) ~/ 2,
        width: side,
        height: side);

    return img.copyResize(cropped,
        width: target, height: target, interpolation: img.Interpolation.linear);
  });
}

// Pixel read:
// final p = image.getPixel(x, y);  final r = p.r.toInt();  // num -> int
// p.rNormalized gives 0..1 whatever the bit depth.
// Faster bulk access: image.getBytes(order: img.ChannelOrder.rgb)  // ChannelOrder.rgb name is [U]
```

- The default interpolation is `nearest` (low quality). Pass `Interpolation.linear` (or `average` for strong downscaling) to match training-time preprocessing. [V]
- Command API (verified README lines): `img.Command()..decodeImageFile(path)..copyResize(width: 64)..writeToFile(...)` with `await cmd.executeThread()`. Whether Command also has `decodeJpg`/`bakeOrientation` methods was not checked [U]. `Isolate.run` with the plain functions is the simpler route.

Sources:
- https://pub.dev/packages/image
- https://pub.dev/packages/image/changelog
- https://pub.dev/documentation/image/latest/image/copyResize.html
- https://pub.dev/documentation/image/latest/image/copyCrop.html
- https://pub.dev/documentation/image/latest/image/bakeOrientation.html
- https://pub.dev/documentation/image/latest/image/decodeImage.html
- https://pub.dev/documentation/image/latest/image/decodeJpg.html
- https://pub.dev/documentation/image/latest/image/Interpolation.html
- https://pub.dev/documentation/image/latest/image/Image-class.html
- https://pub.dev/documentation/image/latest/image/Pixel-class.html
- https://raw.githubusercontent.com/brendan-duncan/image/main/lib/src/formats/jpeg_decoder.dart

---

## 3. camera

- Latest stable: 0.12.1, published 2026-09-03. pubspec: `camera: ^0.12.1`. [V]
- Requires Flutter 3.44 / Dart 3.12 (from the 0.12.1 changelog). If you must stay on an older Flutter, 0.12.0+2 needs Flutter 3.38 / Dart 3.10. [V]
- Platforms: Android SDK 24+, iOS 13.0+, Web (through camera_web). [V]
- Since 0.11.0 the default Android implementation is `camera_android_camerax` (CameraX). `camera_android` (Camera2) is still available if you opt in. [V]
- 0.12.1 adds `setJpegImageQuality` (signature not checked [U]). 0.12.0 adds video stabilization. [V]

### Signatures [V]

```dart
Future<List<CameraDescription>> availableCameras()   // return type [U], used as in the README
CameraController(CameraDescription description, ResolutionPreset resolutionPreset,
    {bool enableAudio = true, int? fps, int? videoBitrate, int? audioBitrate,
     ImageFormatGroup? imageFormatGroup})
Future<void> initialize()
Future<XFile> takePicture()
Future<void> dispose()
Future<void> setFlashMode(FlashMode mode)
Future<void> setFocusMode(FocusMode mode)
Future<void> lockCaptureOrientation([DeviceOrientation? orientation])
Future<void> startImageStream(onLatestImageAvailable onAvailable)
CameraValue value   // ValueNotifier<CameraValue>; value.isInitialized
enum ResolutionPreset { low, medium, high, veryHigh, ultraHigh, max }
// low = 352x288 on iOS, ~240p on Android/Web; medium ~480p; high ~720p; veryHigh ~1080p;
// ultraHigh ~2160p; max = highest available. "exact values are not guaranteed".
```

### Code

```dart
import 'package:camera/camera.dart';

class CaptureService {
  CameraController? _controller;

  Future<void> init() async {
    final cameras = await availableCameras();   // call after WidgetsFlutterBinding.ensureInitialized()
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,   // CameraLensDirection [U, long-standing API]
      orElse: () => cameras.first,
    );
    final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
    try {
      await c.initialize();
    } on CameraException catch (e) {
      if (e.code == 'CameraAccessDenied') {/* show settings prompt */}  // code from README [V]
      // Other codes such as 'CameraAccessDeniedWithoutPrompt' and 'CameraAccessRestricted' (iOS) [U]
      rethrow;
    }
    _controller = c;
  }

  Future<XFile> capture() async {
    final c = _controller!;
    if (!c.value.isInitialized || c.value.isTakingPicture) {   // isTakingPicture [U]
      throw StateError('camera not ready');
    }
    return c.takePicture();   // JPEG in a temp/cache location; use file.path or await file.readAsBytes()
  }

  Future<void> dispose() async => _controller?.dispose();
}
```

- Lifecycle (README [V]): the plugin does not handle app lifecycle. In `didChangeAppLifecycleState`, return early if the controller is null or not initialized, call `dispose()` on `inactive`, and create and initialize a new controller on `resumed`.
- Resolution choice (recommendation, not from the docs): use `high` (~720p) for 224x224 classification only, and `veryHigh` (~1080p) when the same photo also goes to OCR or barcode scanning. Avoid `max`, which gives 12 MP+ files that are slow to decode in Dart.
- `takePicture()` writes to a temporary or cache directory. To keep the photo, copy it with `await xfile.saveTo(path)` into `getApplicationDocumentsDirectory()`. [U for the exact temp location; `XFile.saveTo` is from cross_file, U]
- The JPEG can carry an EXIF orientation tag instead of rotated pixels. Run `img.bakeOrientation` before your own TFLite preprocessing. ML Kit's `InputImage.fromFilePath` handles the orientation natively. [I/U]

### Platform setup
- iOS `ios/Runner/Info.plist` [V]:
```xml
<key>NSCameraUsageDescription</key>
<string>Used to photograph food containers for identification.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Not used for audio recording; required by the camera plugin.</string>
```
  With `enableAudio: false` the microphone prompt never appears, but keep the key, because App Store review checks for purpose strings of linked APIs. [U]
- Android: minSdk 24+. [V] The README gives no manifest step. The CAMERA permission comes in through manifest merge from the plugin, and the runtime request happens during `initialize()`. [U/I] You do not need `permission_handler` for the camera alone.

Sources:
- https://pub.dev/packages/camera
- https://pub.dev/packages/camera/changelog
- https://pub.dev/packages/camera/example
- https://pub.dev/documentation/camera/latest/camera/CameraController-class.html
- https://pub.dev/documentation/camera/latest/camera/ResolutionPreset.html

---

## 4. google_mlkit_text_recognition / google_mlkit_barcode_scanning

| Package | Latest | Published | pubspec |
|---|---|---|---|
| google_mlkit_text_recognition | 0.17.1 | 2026-08-17 | `google_mlkit_text_recognition: ^0.17.1` |
| google_mlkit_barcode_scanning | 0.16.1 | 2026-08-17 | `google_mlkit_barcode_scanning: ^0.16.1` |

- Publisher: flutter-ml.dev. Not affiliated with Google. Android and iOS only. [V]
- Text recognition depends on `google_mlkit_commons ^0.13.0`. [V] Both packages were released the same day, so they should resolve to the same commons version [I]. Do not mix older versions of one with newer versions of the other.

### Signatures [V]

```dart
// google_mlkit_commons 0.13.0 (re-exported by both packages)
factory InputImage.fromFilePath(String path)
factory InputImage.fromFile(File file)
factory InputImage.fromBytes({required Uint8List bytes, required InputImageMetadata metadata})
factory InputImage.fromBitmap({required Uint8List bitmap, required int width, required int height, int rotation = 0})

// Text
TextRecognizer({TextRecognitionScript script = TextRecognitionScript.latin})
Future<RecognizedText> processImage(InputImage inputImage)
Future<void> close()
// RecognizedText: text, blocks. TextBlock: text, boundingBox, cornerPoints, recognizedLanguages, lines.
// TextLine: same getters plus elements. TextElement: same getters.
// Other TextRecognitionScript values (chinese, devanagiri, japanese, korean) are [U] for exact spelling.

// Barcode
BarcodeScanner({List<BarcodeFormat> formats})   // named `formats` [V]; default value [U]
Future<List<Barcode>> processImage(InputImage inputImage)
Future<void> close()
enum BarcodeFormat { all, unknown, code128, code39, code93, codabar, dataMatrix,
                     ean13, ean8, itf, qrCode, upca, upce, pdf417, aztec }
// Barcode (all final): BarcodeType type; BarcodeFormat format; String? rawValue;
// String? displayValue; Uint8List? rawBytes; Rect boundingBox;
// List<Point<int>> cornerPoints; BarcodeValue? value  (cast by type, e.g. BarcodeUrl, BarcodeWifi)
```

### Code

```dart
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class MlKitService {
  final _text = TextRecognizer(script: TextRecognitionScript.latin);
  final _barcode = BarcodeScanner(formats: [
    BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upca,
    BarcodeFormat.upce, BarcodeFormat.qrCode,
  ]);

  Future<List<String>> readLines(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final RecognizedText result = await _text.processImage(input);
    return [
      for (final block in result.blocks)
        for (final line in block.lines) line.text,
    ];
  }

  Future<List<String>> readBarcodes(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final List<Barcode> codes = await _barcode.processImage(input);
    return [for (final b in codes) if (b.rawValue != null) b.rawValue!];
  }

  Future<void> dispose() async {
    await _text.close();
    await _barcode.close();
  }
}
```

### Platform setup [V unless marked]
- Android: minSdkVersion 21, targetSdkVersion 35, compileSdkVersion 35 (README minimums). The Flutter 3.47 defaults (24/36) satisfy them.
- iOS: minimum deployment target 15.5, Xcode 15.3+, Swift 5. ML Kit has no 32-bit support, so exclude armv7. This is stricter than Flutter 3.47's own minimum of iOS 15. Podfile shape, rebuilt from the README description (the setting names are V, the exact Ruby text is U):

```ruby
platform :ios, '15.5'
$iOSVersion = '15.5'

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=*]"] = "armv7"
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
  end
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      if Gem::Version.new($iOSVersion) > Gem::Version.new(config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'])
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = $iOSVersion
      end
    end
  end
end
```
  Also set the Runner target's iOS Deployment Target to 15.5 in Xcode. [U, standard practice]
- Non-Latin scripts need extra native dependencies: GoogleMLKit pods `~> 9.0.0` on iOS and `com.google.mlkit:text-recognition-<script>:16.0.1` on Android. Latin needs nothing extra.
- ML Kit iOS ships as CocoaPods. Keep CocoaPods enabled. Do not make the project SwiftPM-only. [I]

Sources:
- https://pub.dev/packages/google_mlkit_text_recognition
- https://pub.dev/packages/google_mlkit_barcode_scanning
- https://pub.dev/documentation/google_mlkit_commons/latest/google_mlkit_commons/InputImage-class.html
- https://pub.dev/documentation/google_mlkit_text_recognition/latest/google_mlkit_text_recognition/TextRecognizer-class.html
- https://pub.dev/documentation/google_mlkit_barcode_scanning/latest/google_mlkit_barcode_scanning/Barcode-class.html
- https://pub.dev/documentation/google_mlkit_barcode_scanning/latest/google_mlkit_barcode_scanning/BarcodeFormat.html

---

## 5. Storage: sqflite, path_provider, shared_preferences

| Package | Latest | Published | Platforms | pubspec |
|---|---|---|---|---|
| sqflite | 2.4.4+2 | 2026-10-13 | Android, iOS, macOS (Linux/Windows through sqflite_common_ffi; web is experimental through sqflite_common_ffi_web) | `sqflite: ^2.4.4` |
| path_provider | 2.1.6 | 2026-06-15 | Android 24+, iOS 13+, macOS 10.15+, Linux, Windows 10+ | `path_provider: ^2.1.6` |
| shared_preferences | 2.5.6 | 2026-10-05 | Android 24+, iOS 13+, macOS 10.15+, Linux, Web, Windows | `shared_preferences: ^2.5.6` |
| path (used for `join`) | latest not checked | | pure Dart | `path: ^1.9.0` [U] |

All four of these are [V], except the `path` version.

### Code

```dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

Future<Database> openAppDb() async {
  final dir = await getDatabasesPath();                      // [V]
  return openDatabase(
    p.join(dir, 'zapwise.db'),
    version: 1,                                              // [V]
    onCreate: (Database db, int version) async {             // [V] callback shape
      await db.execute('''
        CREATE TABLE scans(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          label TEXT NOT NULL,
          confidence REAL NOT NULL,
          image_path TEXT,
          created_at INTEGER NOT NULL
        )''');
    },
    // onUpgrade: (db, oldVersion, newVersion) async { ... }   // [U] name/shape, long-standing API
  );
}

Future<int> insertScan(Database db, Map<String, Object?> row) =>
    db.insert('scans', row, conflictAlgorithm: ConflictAlgorithm.replace); // conflictAlgorithm [U], long-standing

Future<List<Map<String, Object?>>> recentScans(Database db, String label) =>
    db.query('scans',
        where: 'label = ?', whereArgs: [label],                  // [V]
        orderBy: 'created_at DESC', limit: 50);                  // orderBy/limit [U], long-standing

Future<String> photoDir() async =>
    (await getApplicationDocumentsDirectory()).path;             // [V] function exists on Android and iOS

// shared_preferences: new async API (legacy SharedPreferences.getInstance() "will be deprecated") [V]
final prefs = SharedPreferencesAsync();
Future<void> saveUnit(String u) => prefs.setString('unit', u);
Future<String?> loadUnit() => prefs.getString('unit');
// Or cached: await SharedPreferencesWithCache.create(
//   cacheOptions: const SharedPreferencesWithCacheOptions(allowList: {'unit'}));
```

- shared_preferences may write to disk asynchronously, so do not use it for critical data. [V] Use sqflite for scan history and shared_preferences for settings only.
- Neither sqflite nor path_provider needs any native setup on Android or iOS. [V for platform support, I for "no setup"]

Sources:
- https://pub.dev/packages/sqflite
- https://pub.dev/packages/path_provider
- https://pub.dev/packages/shared_preferences

---

## 6. Combined pubspec and native config

```yaml
environment:
  sdk: ^3.12.0
  flutter: ">=3.44.0"

dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.12.1
  image: ^4.12.0
  camera: ^0.12.1
  google_mlkit_text_recognition: ^0.17.1
  google_mlkit_barcode_scanning: ^0.16.1
  sqflite: ^2.4.4
  path_provider: ^2.1.6
  path: ^1.9.0            # [U] version; may be pinned by the Flutter SDK, adjust if pub complains
  shared_preferences: ^2.5.6

flutter:
  assets:
    - assets/models/
```

Android `android/app/build.gradle.kts`:
```kotlin
android {
    compileSdk = 36            // Flutter 3.47 default (flutter.compileSdkVersion)
    defaultConfig {
        minSdk = 26            // tflite_flutter README (API 26+); camera 24, ML Kit 21
        targetSdk = 36
    }
    // no aaptOptions / androidResources.noCompress needed for tflite_flutter
}
```

iOS: Podfile `platform :ios, '15.5'` plus the armv7 exclusion post_install (section 4), Runner deployment target 15.5, the Info.plist camera and microphone strings, Strip Style "Non-Global Symbols" for release archives, and testing on a real device.
