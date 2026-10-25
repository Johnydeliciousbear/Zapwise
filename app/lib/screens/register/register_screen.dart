// "Help add this product": two photos (back of the box, bottom of the tray) and a few
// numbers turn an unknown package into a product the app can estimate. With an Open Food
// Facts account configured, the entry is also shared there.
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/core.dart';
import '../../sheets/shelf_sheets.dart';
import '../../ui/copy.dart';
import '../../ui/sheets.dart';
import '../../ui/soft.dart';
import '../../ui/sprites.dart';
import '../../ui/theme.dart';
import '../capture_screen.dart';
import '../flows.dart';
import '../scan/product_search_sheet.dart' show ZTextField;
import 'package:zapwise/ui/i18n.dart';

class RegisterScreen extends StatefulWidget {
  final String? frontPhoto;
  final String ocrText; // text read from the front photo
  final String? barcode;
  final VisionOutput? vision;
  const RegisterScreen({super.key, this.frontPhoto, this.ocrText = '', this.barcode, this.vision});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

/// Net weight from label text: "NET WT 10 OZ (283g)" -> 283; "9.5 oz" -> 269.
double? netGramsFromText(String text) {
  final g = RegExp(r'(\d{2,4}(?:\.\d)?)\s*g\b', caseSensitive: false).firstMatch(text);
  if (g != null) return double.tryParse(g.group(1)!);
  final oz = RegExp(r'(\d{1,2}(?:\.\d{1,2})?)\s*oz\b', caseSensitive: false).firstMatch(text);
  if (oz != null) {
    final v = double.tryParse(oz.group(1)!);
    if (v != null) return (v * 28.3495).roundToDouble();
  }
  return null;
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _brand = TextEditingController();
  final _name = TextEditingController();
  final _barcode = TextEditingController();
  final _net = TextEditingController();
  final _fat = TextEditingController();
  final _water = TextEditingController();
  final _minutes = TextEditingController();
  final _watts = TextEditingController();
  final _photos = <String>[];
  ParsedInstructions? _parsed;
  String _backText = '';
  String? _container;
  Storage _storage = Storage.frozen;
  bool _share = true;
  bool _reading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.frontPhoto != null) _photos.add(widget.frontPhoto!);
    _barcode.text = widget.barcode ?? '';
    final net = netGramsFromText(widget.ocrText);
    if (net != null) _net.text = net.round().toString();
  }

  @override
  void dispose() {
    for (final c in [_brand, _name, _barcode, _net, _fat, _water, _minutes, _watts]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _snapBack() async {
    final s = AppScope.read(context);
    final path = await Navigator.of(context).push<String>(CaptureScreen.route(
      title: 'Back of the box',
      hint: 'Get the microwave directions and watts in the frame',
      folder: 'labels',
    ));
    if (path == null || !mounted) return;
    setState(() => _reading = true);
    final read = await s.service.readText(path, barcodes: true);
    final parsed = s.service.parseDirections(read.text);
    if (!mounted) return;
    setState(() {
      _reading = false;
      _photos.add(path);
      _backText = read.text;
      _parsed = parsed;
      if (_barcode.text.isEmpty && read.barcodes.isNotEmpty) _barcode.text = read.barcodes.first;
      if (_net.text.isEmpty) {
        final n = netGramsFromText(read.text);
        if (n != null) _net.text = n.round().toString();
      }
    });
  }

  Future<void> _pickContainer() async {
    final key = await showContainerCheck(context);
    if (key != null && mounted) setState(() => _container = key);
  }

  Recipe? _recipe() {
    final p = _parsed;
    if (p != null && p.hasCookTime) return p.recipe;
    final min = double.tryParse(_minutes.text.trim());
    if (min == null || min <= 0) return null;
    final w = double.tryParse(_watts.text.trim());
    final defaultW = AppScope.read(context).params['default_ref_watt'];
    return Recipe(
      refWatt: w ?? defaultW,
      refWattAssumed: w == null,
      steps: [LabelStep(kind: StepKind.cook, text: 'cook on HIGH', timeS: min * 60)],
      wattTable: const [],
      completeness: w == null ? 'partial' : 'complete',
      doNotMicrowave: 'no',
      ovenOnly: false,
    );
  }

  String _recipeSummary(Recipe r) {
    final parts = <String>[];
    if (r.wattTable.isNotEmpty) {
      parts.add(r.wattTable.map((e) => '${e.watt.round()} W ${timeWords(e.mid)}').join(', '));
    } else {
      parts.add('${r.refWatt.round()} W${r.refWattAssumed ? ' (assumed)' : ''}');
      for (final st in r.steps) {
        if (st.kind == StepKind.cook && st.timeS != null) parts.add(timeWords(st.timeS!));
        if (st.kind == StepKind.action) parts.add(st.text.split(' ').take(3).join(' '));
        if (st.kind == StepKind.stand && st.timeS != null) parts.add('stand ${timeWords(st.timeS!)}');
      }
    }
    return 'Found: ${parts.join(', ')}';
  }

  Future<void> _save() async {
    final s = AppScope.read(context);
    final recipe = _recipe();
    final net = double.tryParse(_net.text.trim());
    if (recipe == null || net == null || _container == null) return;
    setState(() => _saving = true);
    try {
      final p = await s.registerProduct(
        brand: _brand.text.trim(),
        name: _name.text.trim(),
        recipe: recipe,
        containerKey: _container!,
        netG: net,
        addedWaterG: double.tryParse(_water.text.trim()) ?? 0,
        fatGPerPackage: double.tryParse(_fat.text.trim()),
        storage: _storage,
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
        photoPaths: _photos,
        ocrText: [widget.ocrText, _backText].where((t) => t.isNotEmpty).join('\n---\n'),
        vision: widget.vision,
        shareWithOff: _share,
      );
      if (!mounted) return;
      toast(context, 'Added! It\'s marked unverified for now.');
      openGuide(context, p, replace: true, unverified: true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        toast(context, 'Couldn\'t save: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = _recipe();
    final parsedOk = _parsed?.hasCookTime ?? false;
    final ready = _brand.text.trim().isNotEmpty && _name.text.trim().isNotEmpty && recipe != null && _container != null && (double.tryParse(_net.text.trim()) ?? 0) > 0;
    final params = AppScope.of(context).params;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: 'Help add this product', onBack: () => Navigator.of(context).pop()),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: gapped([
              TText('I don\'t have this one yet. Snap two photos and I\'ll add it.',
                  style: ZT.small),
              ZTextField(hint: 'e.g. Healthy Choice', controller: _brand, label: 'Brand', onChanged: (_) => setState(() {})),
              ZTextField(hint: 'e.g. Chicken Teriyaki Bowl', controller: _name, label: 'Product name', onChanged: (_) => setState(() {})),
              SoftButton(
                label: 'Snap the back of the box',
                sub: _reading ? 'Reading…' : (_parsed == null ? 'Where the microwave steps are' : (parsedOk ? _recipeSummary(_parsed!.recipe) : 'Couldn\'t find a time. Type it below.')),
                lead: ZIcon(parsedOk ? 'check' : 'camera'),
                selected: parsedOk,
                onPressed: _reading ? null : _snapBack,
              ),
              if (_parsed?.recipe.ovenOnly == true) const WarnCard(title: 'Oven only', body: 'The box says not to microwave it, so I\'ll save it as oven-only.'),
              if (!parsedOk)
                Row(children: [
                  Expanded(child: ZTextField(hint: 'e.g. 3.5', controller: _minutes, label: 'Microwave minutes', keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 5, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: ZTextField(hint: 'e.g. 1100', controller: _watts, label: 'Watts on the box', keyboardType: TextInputType.number, maxLength: 4, onChanged: (_) => setState(() {}))),
                ]),
              SoftButton(
                label: 'Snap the bottom of the tray',
                sub: _container == null ? 'The side with the number in a triangle' : params.containers[_container]!.labelEn,
                lead: _container == null ? const ZIcon('camera') : PixelFit(containerSprite(_container!), maxWidth: 32, maxHeight: 32),
                selected: _container != null,
                onPressed: _pickContainer,
              ),
              Row(children: [
                Expanded(child: ZTextField(hint: 'e.g. 283', controller: _net, label: 'Net weight (g)', keyboardType: TextInputType.number, maxLength: 5, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 10),
                Expanded(child: ZTextField(hint: 'optional', controller: _fat, label: 'Total fat in the box (g)', keyboardType: const TextInputType.numberWithOptions(decimal: true), maxLength: 5)),
              ]),
              ZTextField(hint: 'Only if the box says to add water', controller: _water, label: 'Added water (g)', keyboardType: TextInputType.number, maxLength: 4),
              TText('Fat per serving × servings per box.', style: ZT.foot),
              TText('Where do you keep it?', style: ZT.small.copyWith(fontWeight: FontWeight.w800)),
              ChoiceRow<Storage>(
                options: const [(Storage.frozen, 'Freezer'), (Storage.chilled, 'Fridge'), (Storage.shelf, 'Pantry')],
                selected: _storage,
                onSelected: (v) => setState(() => _storage = v),
              ),
              ZTextField(hint: 'Barcode digits (optional)', controller: _barcode, label: 'Barcode', keyboardType: TextInputType.number, maxLength: 14),
              GestureDetector(
                onTap: () => setState(() => _share = !_share),
                child: Row(children: [
                  Checkbox(value: _share, activeColor: ZC.roseDeep, onChanged: (v) => setState(() => _share = v ?? false)),
                  Expanded(child: TText('Share with Open Food Facts too (needs the barcode)', style: ZT.small)),
                ]),
              ),
              PixelButton(label: _saving ? 'Adding' : 'Add product', onPressed: ready && !_saving ? _save : null),
            ])),
          ),
        ]),
      ),
    );
  }
}
