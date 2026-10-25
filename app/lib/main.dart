// ZapWise: scan a packaged meal before you heat it.
//   flutter run                         the full app
//   flutter run -t lib/main_backend_check.dart   core check without the UI
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_scope.dart';
import 'app/app_state.dart';
import 'screens/flows.dart';
import 'screens/shell.dart';
import 'ui/soft.dart';
import 'ui/sprites.dart';
import 'ui/theme.dart';
import 'package:zapwise/ui/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await loadLanguage(await SharedPreferences.getInstance());
  runApp(const ZapWiseApp());
}

class ZapWiseApp extends StatefulWidget {
  const ZapWiseApp({super.key});

  @override
  State<ZapWiseApp> createState() => _ZapWiseAppState();
}

class _ZapWiseAppState extends State<ZapWiseApp> {
  AppState? _state;
  Object? _error;
  final _tab = ValueNotifier<int>(0);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() => _error = null);
    try {
      final s = await AppState.start();
      if (mounted) setState(() => _state = s);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    return MaterialApp(
      title: 'ZapWise',
      navigatorKey: rootNavKey,
      debugShowCheckedModeBanner: false,
      theme: zapTheme(),
      // AppScope and ShellNav sit above the navigator so pushed screens can reach them too
      builder: (context, child) {
        // honour the phone's text size up to 2x (low-vision users often need more than 1.3x);
        // the language scope sits here so every route and sheet can translate
        final mq = MediaQuery.of(context);
        final scaled = LangScope(child: MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 2.0)), child: child!));
        return s == null ? scaled : AppScope(state: s, child: ShellNav(tab: _tab, child: scaled));
      },
      home: s == null ? _Splash(error: _error, onRetry: _boot) : const Shell(),
    );
  }
}

class _Splash extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;
  const _Splash({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const PixelImage('brand/wordmark', scale: 3, semanticLabel: 'ZapWise'),
              const SizedBox(height: 24),
              Zappy(error == null ? Mood.thinking : Mood.worried, scale: 3),
              const SizedBox(height: 16),
              TText(error == null ? 'Warming up the kitchen' : 'ZapWise couldn\'t start.', style: ZT.h2, textAlign: TextAlign.center),
              if (error != null) ...[
                const SizedBox(height: 8),
                TText('$error', style: ZT.smallMuted, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                PixelButton(label: 'Try again', small: true, onPressed: onRetry),
              ],
            ]),
          ),
        ),
      );
}
