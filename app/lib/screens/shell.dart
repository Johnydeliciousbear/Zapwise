// Four tabs (Kitchen, Log, Learn, Me) with the floating soft tab bar from the design chart.
// Flows (scan, heating guide, result) are pushed on top as full screens without the tab bar.
import 'package:flutter/material.dart';

import '../ui/soft.dart';
import '../ui/sprites.dart';
import '../ui/theme.dart';
import 'home/home_screen.dart';
import 'learn/learn_screen.dart';
import 'log/log_screen.dart';
import 'me/me_screen.dart';
import 'package:zapwise/ui/i18n.dart';

/// Lets any screen switch tabs, e.g. back to the kitchen after saving a meal.
class ShellNav extends InheritedWidget {
  final ValueNotifier<int> tab;
  const ShellNav({super.key, required this.tab, required super.child});

  static ValueNotifier<int>? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ShellNav>()?.tab;

  /// Closes every pushed screen and shows [index] (0 Kitchen, 1 Log, 2 Learn, 3 Me).
  static void goTab(BuildContext context, int index) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    maybeOf(context)?.value = index;
  }

  @override
  bool updateShouldNotify(ShellNav old) => old.tab != tab;
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  @override
  Widget build(BuildContext context) {
    final tab = ShellNav.maybeOf(context)!;
    return ValueListenableBuilder<int>(
          valueListenable: tab,
          builder: (context, i, _) => Scaffold(
            body: Stack(children: [
              Positioned.fill(
                child: SafeArea(
                  bottom: false,
                  child: IndexedStack(index: i, children: const [HomeScreen(), LogScreen(), LearnScreen(), MeScreen()]),
                ),
              ),
              Positioned(left: 12, right: 12, bottom: 12 + MediaQuery.paddingOf(context).bottom, child: _TabBar(index: i, onTap: (t) => tab.value = t)),
            ]),
          ),
        );
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _TabBar({required this.index, required this.onTap});

  static const _tabs = [('kitchen', 'Kitchen'), ('log', 'Log'), ('learn', 'Learn'), ('me', 'Me')];

  @override
  Widget build(BuildContext context) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: ZC.milk, borderRadius: BorderRadius.circular(28), boxShadow: kRaisedShadow),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var t = 0; t < _tabs.length; t++)
              Semantics(
                button: true,
                selected: t == index,
                label: _tabs[t].$2,
                excludeSemantics: true,
                onTap: () => onTap(t),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(t),
                  child: SizedBox(
                    width: 78,
                    height: 62,
                    child: t == index
                        ? Well(radius: 18, small: true, padding: EdgeInsets.zero, child: _tabContent(t, true))
                        : _tabContent(t, false),
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _tabContent(int t, bool on) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ZIcon(_tabs[t].$1),
        const SizedBox(height: 4),
        TText(_tabs[t].$2, style: ZT.tab.copyWith(color: on ? ZC.roseDeep : ZC.cocoa2)),
      ]);
}

/// Bottom padding for tab screens so content clears the floating tab bar.
double tabBottomPadding(BuildContext context) => 104 + MediaQuery.paddingOf(context).bottom;
