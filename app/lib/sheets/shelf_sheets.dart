// The container shelf: see your containers, add one (photo or picture choice), pick one to
// heat in, and check an unknown tray from a photo of its bottom.
import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/core.dart';
import '../screens/capture_screen.dart';
import '../screens/scan/product_search_sheet.dart' show ZTextField;
import '../ui/copy.dart';
import '../ui/sheets.dart';
import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

/// Containers a user can put on the shelf, in the order the picture grid shows them.
// paper plates and moulded-fibre boxes were added after the store photos (2026-10): people heat food on them
const kAddable = ['glass', 'ceramic', 'pp_container', 'takeout_tub', 'pet_clamshell', 'eps_foam', 'ps_rigid', 'cpet_tray', 'paperboard_tray', 'paper_cup', 'metal', 'melamine'];

String shortLabel(String key) => switch (key) {
      'cpet_tray' => 'Black oven tray (#1)',
      'pp_container' => 'Microwave-safe plastic (#5)',
      'pet_board_tray' => 'Coated paper tray',
      'paperboard_tray' => 'Paper plate or fiber box',
      'paper_cup' => 'Paper cup or bowl',
      'steam_bag' => 'Steam bag',
      'pouch' => 'Microwave pouch',
      'takeout_tub' => 'Take-out tub',
      'pet_clamshell' => 'Clear clamshell (#1)',
      'eps_foam' => 'Foam box or cup',
      'ps_rigid' => 'Clear hard plastic (#6)',
      'metal' => 'Metal or foil',
      'glass' => 'Glass dish',
      'ceramic' => 'Plate or bowl',
      'melamine' => 'Melamine or bamboo dish',
      'stove_pot' => 'Pot',
      'popcorn_bag' => 'Popcorn bag',
      'susceptor_sleeve' => 'Crisping sleeve',
      _ => key,
    };

/// What a container means for heating, in one or two sentences.
String safetyText(ContainerType c) {
  return switch (c.status) {
    ContainerStatus.inert => c.key == 'glass'
        ? 'No plastic touches your food. Rest any plastic lid loosely on top.'
        : (c.reasonEn.isNotEmpty ? c.reasonEn : 'No plastic touches your food.'),
    ContainerStatus.ok => 'Safe to microwave, but some chemicals can still seep into hot, oily food.',
    ContainerStatus.measured => c.reasonEn.isNotEmpty ? c.reasonEn : 'Based on lab tests.',
    ContainerStatus.block => 'Don\'t heat food in this. ${c.reasonEn}',
    ContainerStatus.info || ContainerStatus.noData => c.reasonEn.isNotEmpty ? c.reasonEn : 'No data on this container yet.',
  };
}

// ------------------------------------------------------------------ shelf
Future<void> showShelfSheet(BuildContext context) => showZapSheet<void>(context, (ctx) {
      final s = AppScope.of(ctx);
      return SheetBody(title: 'Your shelf', children: [
        if (s.shelf.isEmpty) TText('Nothing here yet. Add the containers you heat food in.', style: ZT.smallMuted),
        for (final it in s.shelf) _ShelfRow(item: it, onRemove: () => s.removeFromShelf(it.id)),
        PixelButton(label: 'Add a container', icon: 'camera', onPressed: () => showAddContainerSheet(ctx)),
      ]);
    });

class _ShelfRow extends StatelessWidget with LineRow {
  final ShelfItem item;
  final VoidCallback onRemove;
  const _ShelfRow({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).params.containers[item.containerKey]!;
    final (chip, band) = shelfChip(c);
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 10, 0, 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: ZC.line))),
      child: Row(children: [
        ZThumb(containerSprite(item.containerKey), size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TText(item.name, style: ZT.button.copyWith(fontSize: 15)),
            const SizedBox(height: 4),
            BandChip(band, text: chip, outline: false),
          ]),
        ),
        IconButton(onPressed: onRemove, tooltip: 'Remove from shelf', icon: const Icon(Icons.close_rounded, color: ZC.cocoa2)),
      ]),
    );
  }
}

// ------------------------------------------------------------------ add a container
/// Returns the container key that was put on the shelf, or null.
Future<String?> showAddContainerSheet(BuildContext context) =>
    showZapSheet<String>(context, (ctx) => const _ContainerPicker(mode: _PickMode.add));

/// Unknown tray in the heating guide: returns the confirmed container key, or null.
Future<String?> showContainerCheck(BuildContext context, {String? first}) =>
    showZapSheet<String>(context, (ctx) => _ContainerPicker(mode: _PickMode.check, first: first));

enum _PickMode { add, check }

class _ContainerPicker extends StatefulWidget {
  final _PickMode mode;
  final String? first;
  const _ContainerPicker({required this.mode, this.first});

  @override
  State<_ContainerPicker> createState() => _ContainerPickerState();
}

class _ContainerPickerState extends State<_ContainerPicker> {
  String? _pick;
  List<String>? _ask; // picture question after a photo
  String? _photo;
  String? _note;
  bool _busy = false;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _snap() async {
    final s = AppScope.read(context);
    final path = await Navigator.of(context).push<String>(CaptureScreen.route(
      title: widget.mode == _PickMode.check ? 'Snap the tray bottom' : 'Snap the container',
      hint: 'Get the number in the triangle and words like "microwave safe" in the frame',
      folder: 'containers',
    ));
    if (path == null || !mounted) return;
    setState(() {
      _busy = true;
      _photo = path;
    });
    ContainerDecision? d;
    try {
      d = await s.service.identifyContainerPhoto(path);
    } catch (_) {
      d = null;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (d == null) {
        _ask = kAddable;
        _note = 'I couldn\'t read that photo. Which one looks like yours?';
      } else if (d.containerKey != null) {
        _pick = d.containerKey;
        _note = d.cues.resinCode != null ? 'Found #${d.cues.resinCode} on it.' : 'Recognized from the photo.';
      } else {
        _ask = d.askAmong.isEmpty ? kAddable : d.askAmong;
        _note = d.cues.isEmpty ? 'Which one looks like yours?' : 'Narrowed it down. Which one is yours?';
      }
      if (d != null && d.labelSaysDoNotMicrowave) _note = '${_note ?? ''} The label says don\'t microwave it.';
      if (d != null && d.labelSaysLidOff) _note = '${_note ?? ''} The label says to take the lid off first.';
    });
  }

  Future<void> _confirm() async {
    final key = _pick;
    if (key == null) return;
    final s = AppScope.read(context);
    if (widget.mode == _PickMode.add) {
      final name = _name.text.trim();
      await s.addToShelf(key, name: name.isEmpty ? shortLabel(key) : name, photoPath: _photo);
      if (!mounted) return;
      toast(context, '${shortLabel(key)} is on your shelf');
    }
    if (mounted) Navigator.of(context).pop(key);
  }

  Widget _grid(List<String> keys) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        children: [
          for (final k in keys)
            Semantics(
              button: true,
              label: shortLabel(k),
              excludeSemantics: true,
              onTap: () => setState(() {
                _pick = k;
                _ask = null;
              }),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _pick = k;
                  _ask = null;
                }),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    PixelFit(containerSprite(k), maxWidth: 72, maxHeight: 48),
                    const SizedBox(height: 6),
                    TText(shortLabel(k), style: ZT.small.copyWith(fontSize: 12.5, fontWeight: FontWeight.w800), textAlign: TextAlign.center, maxLines: 2),
                  ]),
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final params = AppScope.of(context).params;
    final title = widget.mode == _PickMode.check ? 'Check the tray' : 'Add a container';
    final pick = _pick;
    if (pick != null) {
      final c = params.containers[pick]!;
      final (chip, band) = shelfChip(c);
      return SheetBody(title: title, children: [
        Row(children: [
          PixelFit(containerSprite(pick), maxWidth: 84, maxHeight: 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TText(c.labelEn, style: ZT.h3),
              if (_note != null) TText(_note!, style: ZT.smallMuted),
              const SizedBox(height: 4),
              TText(safetyText(c), style: ZT.small),
              const SizedBox(height: 6),
              BandChip(band, text: chip),
            ]),
          ),
        ]),
        if (widget.mode == _PickMode.add) ZTextField(hint: 'Nickname, like Mom\'s glass box (optional)', controller: _name, label: 'Name', maxLength: 30),
        PixelButton(label: widget.mode == _PickMode.add ? 'Add to my shelf' : 'That\'s the one', onPressed: _confirm),
        Center(child: ZLink('Pick a different one', onTap: () => setState(() => _pick = null))),
      ]);
    }
    return SheetBody(title: title, children: [
      if (_ask == null) ...[
        TText(
            widget.mode == _PickMode.check
                ? 'Flip the tray and snap the bottom. The number in the triangle tells trays apart. Color doesn\'t.'
                : 'Snap it from the side. If there\'s a number in a triangle on the bottom, snap that too.',
            style: ZT.small),
        SoftButton(label: _busy ? 'Reading the photo…' : 'Snap it', lead: const ZIcon('camera'), onPressed: _busy ? null : _snap),
        TText('Or pick it from the list', style: ZT.smallMuted),
        _grid(widget.mode == _PickMode.check
            ? <String>{if (widget.first != null) widget.first!, 'cpet_tray', 'pp_container', 'pet_board_tray', 'paperboard_tray', 'paper_cup'}.toList()
            : kAddable),
      ] else ...[
        TText(_note ?? 'Which one looks like yours?', style: ZT.small),
        _grid(_ask!),
        Center(child: ZLink('Retake photo', onTap: () => setState(() => _ask = null))),
      ],
    ]);
  }
}

// ------------------------------------------------------------------ choose one to heat in
/// Returns the container key of a shelf item that is fine to heat in, or null.
Future<String?> chooseShelfContainer(BuildContext context) => showZapSheet<String>(context, (ctx) => const _ChooseBody());

class _ChooseBody extends StatefulWidget {
  const _ChooseBody();

  @override
  State<_ChooseBody> createState() => _ChooseBodyState();
}

class _ChooseBodyState extends State<_ChooseBody> {
  ContainerType? _blocked;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final b = _blocked;
    if (b != null) {
      return SheetBody(title: 'Use my own dish', children: [
        WarnCard(title: 'Not this one', body: '${b.reasonEn.isEmpty ? 'It isn\'t made for heat.' : b.reasonEn} Pick another one or a plate.'),
        SoftButton(label: 'Pick another', lead: const ZIcon('swap'), onPressed: () => setState(() => _blocked = null)),
      ]);
    }
    return SheetBody(title: 'Use my own dish', children: [
      if (s.shelf.isEmpty) ...[
        TText('Your shelf is empty. Add a container first.', style: ZT.smallMuted),
        PixelButton(label: 'Add a container', icon: 'camera', onPressed: () => showAddContainerSheet(context)),
      ],
      for (final it in s.shelf)
        SoftButton(
          label: it.name,
          sub: it.name == shortLabel(it.containerKey) ? null : shortLabel(it.containerKey),
          lead: SizedBox(width: 48, height: 40, child: Center(child: PixelFit(containerSprite(it.containerKey), maxWidth: 48, maxHeight: 40))),
          onPressed: () {
            final c = s.params.containers[it.containerKey]!;
            if (c.status == ContainerStatus.block) {
              setState(() => _blocked = c);
            } else {
              Navigator.of(context).pop(it.containerKey);
            }
          },
        ),
    ]);
  }
}
