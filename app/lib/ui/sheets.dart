// Bottom sheets and short status messages.
import 'package:flutter/material.dart';

import 'soft.dart';
import 'theme.dart';
import 'package:zapwise/ui/i18n.dart';

/// Opens a bottom sheet in the app style. The builder gets the sheet's own context.
Future<T?> showZapSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: ZC.milk,
      barrierColor: ZC.dim,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      builder: (ctx) {
        // the keyboard when it is open, otherwise the system navigation bar
        final kb = MediaQuery.viewInsetsOf(ctx).bottom, nav = MediaQuery.viewPaddingOf(ctx).bottom;
        return Padding(padding: EdgeInsets.only(bottom: kb > nav ? kb : nav), child: builder(ctx));
      },
    );

/// Standard sheet body: grab handle, title row with a close button, scrolling content.
class SheetBody extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool showClose;
  const SheetBody({super.key, required this.title, required this.children, this.showClose = true});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: ZC.shade, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Semantics(header: true, child: TText(title, style: ZT.title.copyWith(fontSize: 20)))),
              if (showClose) RoundButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop(), semantic: 'Close'),
            ]),
            const SizedBox(height: 14),
            ...gapped(children),
          ],
        ),
      );
}

/// Short message at the bottom of the screen ('Saved to today's log').
void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: TText(message, textAlign: TextAlign.center), duration: const Duration(milliseconds: 2600), margin: const EdgeInsets.fromLTRB(32, 0, 32, 110)));
}
