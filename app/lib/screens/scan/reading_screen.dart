// "Reading the box": runs OCR, barcode and image look-up on the photo, shows what was found,
// then moves on to the confirm screen.
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../flows.dart';
import 'confirm_screen.dart';
import 'product_search_sheet.dart';
import 'package:zapwise/ui/i18n.dart';

class ReadingScreen extends StatefulWidget {
  final String photoPath;
  const ReadingScreen({super.key, required this.photoPath});

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  ScanOutcome? _out;
  Object? _error;
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    final s = AppScope.read(context);
    try {
      final started = DateTime.now();
      final out = await s.service.scanPackage(widget.photoPath);
      if (!mounted) return;
      setState(() => _out = out);
      for (var i = 1; i <= 3; i++) {
        await Future.delayed(const Duration(milliseconds: 380));
        if (!mounted) return;
        setState(() => _shown = i);
      }
      // keep the screen up long enough to read
      final wait = const Duration(milliseconds: 1800) - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future.delayed(wait);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => ConfirmScreen(outcome: out, photoPath: widget.photoPath)));
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final out = _out;
    final rows = <(bool, String)>[];
    if (out != null) {
      final best = out.match.best;
      rows.add((true, out.text.barcodes.isEmpty ? 'Barcode: not found, using the photo' : 'Barcode: ${out.text.barcodes.first}'));
      final firstLine = out.text.text.split('\n').firstWhere((l) => l.trim().length > 3, orElse: () => '');
      rows.add((true, firstLine.isEmpty ? 'Text: couldn\'t read any' : 'Text: ${firstLine.trim().toUpperCase()}'));
      rows.add((true, out.vision == null ? 'Photo match: not available' : 'Photo match: ${best == null ? 'no close product' : '${(best.image * 100).round()}%'}'));
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Zappy(_error == null ? Mood.thinking : Mood.worried, scale: 4),
              const SizedBox(height: 18),
              TText(_error == null ? 'Reading the box' : 'I couldn\'t read that photo', style: ZT.h2, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              if (_error != null) ...[
                const TText('Something went wrong while reading the box. Try another photo, or find the meal by name.', style: ZT.small, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                PixelButton(label: 'Take the photo again', icon: 'camera', onPressed: () => Navigator.of(context).pop()),
                const SizedBox(height: 14),
                ...gapped([
                  SoftButton(label: 'Find it by name', lead: const ZIcon('learn'), onPressed: () async {
                    final p = await showProductSearch(context);
                    if (p != null && context.mounted) openGuide(context, p, replace: true);
                  }),
                  SoftButton(label: 'Skip the scan', sub: 'Pick the container and type the box time', lead: const ZIcon('timer'), onPressed: () => openQuickEstimate(context, replace: true)),
                ]),
                // technical details only in debug builds, for the developer
                if (kDebugMode) Padding(padding: const EdgeInsets.only(top: 12), child: Text('$_error', style: ZT.foot, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis)),
              ] else if (out == null)
                const CircularProgressIndicator(color: ZC.roseDeep)
              else
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: AnimatedOpacity(
                      opacity: i < _shown ? 1 : 0.45,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
                        child: Row(children: [
                          const ZIcon('check', size: 24),
                          const SizedBox(width: 10),
                          Expanded(child: TText(rows[i].$2, style: ZT.small.copyWith(fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                      ),
                    ),
                  ),
            ]),
          ),
        ),
      ),
    );
  }
}
