// Entry points for the main flow: scan -> reading -> confirm -> heating guide -> result.
import 'package:flutter/material.dart';

import '../core/core.dart';
import '../ui/soft.dart';
import '../ui/sprites.dart';
import 'capture_screen.dart';
import 'guide/guide_screen.dart';
import 'register/register_screen.dart';
import 'scan/product_search_sheet.dart';
import 'scan/quick_estimate_screen.dart';
import 'scan/reading_screen.dart';

/// Navigator of the whole app, for actions that outlive the screen that started them
/// (for example celebrating a quest after the result screen has closed).
final rootNavKey = GlobalKey<NavigatorState>();

Future<void> startScan(BuildContext context) async {
  final nav = Navigator.of(context);
  final path = await nav.push<String>(CaptureScreen.route(
    title: 'Scan the box',
    hint: 'Fit the front of the box in the frame',
    folder: 'scans',
    footer: (ctx) => const _ScanFooter(),
  ));
  if (path == null) return;
  nav.push(MaterialPageRoute<void>(builder: (_) => ReadingScreen(photoPath: path)));
}

void openGuide(BuildContext context, Product product, {bool replace = false, bool unverified = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => GuideScreen(product: product, unverified: unverified));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

/// Estimate without a product: container from pictures, time from the box.
void openQuickEstimate(BuildContext context, {bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => const QuickEstimateScreen());
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

void openRegister(BuildContext context, {String? frontPhoto, String ocrText = '', String? barcode, VisionOutput? vision, bool replace = false}) {
  final route = MaterialPageRoute<void>(builder: (_) => RegisterScreen(frontPhoto: frontPhoto, ocrText: ocrText, barcode: barcode, vision: vision));
  if (replace) {
    Navigator.of(context).pushReplacement(route);
  } else {
    Navigator.of(context).push(route);
  }
}

class _ScanFooter extends StatelessWidget {
  const _ScanFooter();

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...gapped([
        SoftButton(
          label: 'Find it by name',
          sub: 'When the box isn\'t handy',
          lead: const ZIcon('learn'),
          onPressed: () async {
            final nav = Navigator.of(context);
            final p = await showProductSearch(context);
            if (p == null) return;
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => GuideScreen(product: p)));
          },
        ),
        SoftButton(
          label: 'Skip the scan',
          sub: 'Pick the container and type the box time',
          lead: const ZIcon('timer'),
          onPressed: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => const QuickEstimateScreen()));
          },
        ),
        ]),
        const SizedBox(height: 6),
        Center(
          child: ZLink('Can\'t find it? Add your product', onTap: () {
            final nav = Navigator.of(context);
            nav.pop();
            nav.push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen()));
          }),
        ),
      ]);
}
