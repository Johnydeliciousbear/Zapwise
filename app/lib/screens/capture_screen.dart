// Full-screen camera with the viewfinder corners from the prototype. Returns the saved
// photo path with Navigator.pop, or null when closed.
//   final path = await Navigator.push<String>(context, CaptureScreen.route(title: 'Scan the box', hint: '...'));
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

class CaptureScreen extends StatefulWidget {
  final String title;
  final String hint;
  final String folder; // where the photo is kept: products, labels, containers, appliances
  final WidgetBuilder? footer; // extra actions under the shutter (e.g. search by name)

  const CaptureScreen({super.key, required this.title, required this.hint, this.folder = 'photos', this.footer});

  static Route<String> route({required String title, required String hint, String folder = 'photos', WidgetBuilder? footer}) =>
      MaterialPageRoute<String>(builder: (_) => CaptureScreen(title: title, hint: hint, folder: folder, footer: footer));

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _c;
  String? _problem;
  bool _busy = false;
  bool _released = false; // camera given back while the app was in the background

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.dispose();
    super.dispose();
  }

  // The camera plugin does not follow the app lifecycle itself (camera README).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = _c;
      if (c == null || !c.value.isInitialized) return;
      _c = null;
      _released = true;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _released) {
      // _c is null here, so only restart a camera this screen gave back itself
      _released = false;
      _start();
    }
  }

  Future<void> _start() async {
    CameraController? c;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _problem = 'No camera found on this phone.');
        return;
      }
      final back = cams.firstWhere((d) => d.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _c = c;
        _problem = null;
      });
    } on CameraException catch (e) {
      await _release(c);
      if (!mounted) return;
      setState(() => _problem = e.code.startsWith('CameraAccessDenied')
          ? 'The camera is off for ZapWise. Turn it on in Settings.'
          : 'The camera didn\'t start (${e.code}).');
    } catch (e) {
      await _release(c);
      if (!mounted) return;
      setState(() => _problem = 'The camera didn\'t start.');
    }
  }

  /// Frees a controller whose start failed (it may hold the camera open).
  static Future<void> _release(CameraController? c) async {
    try {
      await c?.dispose();
    } catch (_) {}
  }

  Future<void> _shoot() async {
    final c = _c;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture || _busy) return;
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory(p.join(dir.path, widget.folder));
      await folder.create(recursive: true);
      final dest = p.join(folder.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
      await shot.saveTo(dest);
      if (mounted) Navigator.of(context).pop(dest);
    } catch (e) {
      if (mounted) setState(() => _problem = 'That photo didn\'t work. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TopBar(title: widget.title, onBack: () => Navigator.of(context).pop()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  height: 360,
                  color: ZC.viewfinder,
                  child: Stack(fit: StackFit.expand, children: [
                    if (c != null && c.value.isInitialized) _Preview(c) else _Placeholder(problem: _problem),
                    const _Corners(),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: TText(widget.hint, textAlign: TextAlign.center, style: ZT.small.copyWith(color: ZC.paper)),
                    ),
                    if (_busy) const ColoredBox(color: Color(0x55000000), child: Center(child: CircularProgressIndicator(color: ZC.paper))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Semantics(
                button: true,
                label: 'Take photo',
                child: GestureDetector(
                  onTap: c == null ? null : _shoot,
                  child: Opacity(
                    opacity: c == null ? 0.5 : 1,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: ZC.straw,
                        shape: BoxShape.circle,
                        border: Border.all(color: ZC.cocoa, width: 4),
                        boxShadow: const [BoxShadow(color: ZC.cocoa, offset: Offset(0, 5))],
                      ),
                      child: const Center(child: ZIcon('camera')),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.footer != null) Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 24), child: widget.footer!(context)),
          ]),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final CameraController c;
  const _Preview(this.c);

  @override
  Widget build(BuildContext context) {
    final size = c.value.previewSize; // reported in landscape (width > height)
    if (size == null) return CameraPreview(c);
    return FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: size.height, height: size.width, child: CameraPreview(c)));
  }
}

class _Placeholder extends StatelessWidget {
  final String? problem;
  const _Placeholder({this.problem});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: problem == null
              ? const CircularProgressIndicator(color: ZC.paper)
              : TText(problem!, textAlign: TextAlign.center, style: ZT.body.copyWith(color: ZC.paper)),
        ),
      );
}

class _Corners extends StatelessWidget {
  const _Corners();

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(color: ZC.paper, width: 4);
    return const Stack(children: [
      Positioned(top: 22, left: 22, child: _Corner(Border(top: side, left: side))),
      Positioned(top: 22, right: 22, child: _Corner(Border(top: side, right: side))),
      Positioned(bottom: 48, left: 22, child: _Corner(Border(bottom: side, left: side))),
      Positioned(bottom: 48, right: 22, child: _Corner(Border(bottom: side, right: side))),
    ]);
  }
}

class _Corner extends StatelessWidget {
  final Border border;
  const _Corner(this.border);

  @override
  Widget build(BuildContext context) => Container(width: 34, height: 34, decoration: BoxDecoration(border: border));
}
