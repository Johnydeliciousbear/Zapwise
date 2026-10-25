// Language support. Screens keep writing English; TText (a drop-in for Text) looks the
// rendered string up in the Spanish table when Spanish is on. Strings that carry numbers are
// matched with patterns. Anything not in the table stays English, so a missing entry never
// breaks a screen. Import this file as package:zapwise/ui/i18n.dart everywhere, so the app
// has one language notifier.
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'i18n_es.dart';

/// 'en' or 'es'. Set at start-up from the saved choice or the phone's language.
final ValueNotifier<String> appLang = ValueNotifier<String>('en');

const kLangPref = 'app_language';

Future<void> loadLanguage(SharedPreferences prefs) async {
  final saved = prefs.getString(kLangPref);
  if (saved != null) {
    appLang.value = saved;
    return;
  }
  final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  appLang.value = phone == 'es' ? 'es' : 'en';
}

Future<void> setLanguage(String lang) async {
  appLang.value = lang;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLangPref, lang);
}

/// Puts the language above every route, so widgets rebuild when it changes.
class LangScope extends InheritedNotifier<ValueNotifier<String>> {
  LangScope({super.key, required super.child}) : super(notifier: appLang);

  static String of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LangScope>()?.notifier?.value ?? appLang.value;
}

/// Translate one rendered English string for the current language.
String tr(BuildContext context, String en) => trFor(LangScope.of(context), en);

/// Same, without a context (for code that already knows the language).
String trFor(String lang, String en) {
  if (lang != 'es' || en.isEmpty) return en;
  final hit = kEs[en];
  if (hit != null) return hit;
  for (final f in _esFunctions) {
    final out = f(en);
    if (out != null) return out;
  }
  for (final (re, rep) in kEsPatterns) {
    final m = re.firstMatch(en);
    if (m != null) {
      return rep.replaceAllMapped(RegExp(r'\\(\d)'), (g) => m.group(int.parse(g.group(1)!)) ?? '');
    }
  }
  // two lines built together (a method and a time): translate each line on its own
  if (en.contains('\n')) {
    final parts = en.split('\n');
    final out = [for (final p in parts) trFor(lang, p)].join('\n');
    if (out != en) return out;
  }
  return en;
}

/// Text that translates itself. Same arguments as the Text fields the app uses.
class TText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;
  final String? semanticsLabel;
  const TText(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow, this.softWrap, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    final lang = LangScope.of(context);
    return Text(
      trFor(lang, data),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: semanticsLabel == null ? null : trFor(lang, semanticsLabel!),
    );
  }
}

// ------------------------------------------------------------------ patterns that need code

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _low(String s) => s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

/// Translate a container label that may have been lower-cased by the screen.
String _label(String s) => _low(kEs[s] ?? kEs[_cap(s)] ?? s);

const Map<String, String> _thisNoun = {
  'tray': 'esta bandeja',
  'cup': 'este vaso',
  'bag': 'esta bolsa',
  'pouch': 'esta bolsita',
  'tub': 'este envase',
  'clamshell': 'este envase',
  'foam box': 'esta caja de espuma',
  'glass dish': 'este recipiente de vidrio',
  'plate': 'este plato',
  'pot': 'esta olla',
  'container': 'este envase',
};

const Map<String, String> _theNoun = {
  'tray': 'la bandeja',
  'cup': 'el vaso',
  'bag': 'la bolsa',
  'pouch': 'la bolsita',
  'tub': 'el envase',
  'clamshell': 'el envase',
  'foam box': 'la caja de espuma',
  'glass dish': 'el recipiente de vidrio',
  'plate': 'el plato',
  'pot': 'la olla',
  'container': 'el envase',
};

final List<String? Function(String)> _esFunctions = [
  // v0.3.2 caption under the big number
  (s) {
    final m = RegExp(r"^of (your|(.+)'s) daily\nsafe limit$").firstMatch(s);
    if (m == null) return null;
    return m.group(1) == 'your' ? 'de tu límite\ndiario seguro' : 'del límite diario\nseguro de ${m.group(2)}';
  },
  // one-line verdict above the number
  (s) {
    final m = RegExp(r"^(Low\. A|A|That's high for one meal\. Use a) (plate|bowl)( makes it almost zero\.| would cut this to almost zero\.|\.)$").firstMatch(s);
    if (m == null) return null;
    final swap = m.group(2) == 'bowl' ? 'un tazón' : 'un plato';
    final swapCap = m.group(2) == 'bowl' ? 'Un tazón' : 'Un plato';
    if (m.group(1) == 'Low. A') return 'Bajo. $swapCap lo deja en casi cero.';
    if (m.group(1) == 'A' && m.group(3)!.contains('would')) return '$swapCap lo bajaría a casi cero.';
    if (m.group(1) == 'A') return '$swapCap lo deja en casi cero.';
    return 'Es alto para una comida. Usa $swap.';
  },
  (s) {
    final m = RegExp(r'^Microwaved in the (.+)$').firstMatch(s);
    return m == null ? null : 'En microondas, en ${_theNoun[m.group(1)] ?? 'el envase'}';
  },
  // 'Heat it in the tray (7:09)', or with no time when the box has no cook step
  (s) {
    final m = RegExp(r'^Heat it (on a plate|in the (.+?))( \((\d+:\d\d)\))?$').firstMatch(s);
    if (m == null || (m.group(2) != null && _theNoun[m.group(2)] == null)) return null;
    final where = m.group(1) == 'on a plate' ? 'en un plato' : 'en ${_theNoun[m.group(2)]}';
    return m.group(4) == null ? 'Calentar $where' : 'Calentar $where (${m.group(4)})';
  },
  // 'My glass dish': the shelf name after "Mi"
  (s) {
    final m = RegExp(r'^My (.+)$').firstMatch(s);
    if (m == null) return null;
    final name = m.group(1)!;
    return kEs[name] != null || kEs[_cap(name)] != null ? 'Mi ${_label(name)}' : null;
  },
  (s) {
    final m = RegExp(r"^Last 7 days, % of (your|(.+)'s) daily safe limit$").firstMatch(s);
    if (m == null) return null;
    return m.group(1) == 'your' ? 'Últimos 7 días, % de tu límite diario seguro' : 'Últimos 7 días, % del límite diario seguro de ${m.group(2)}';
  },
  // ring label on the result screen
  (s) {
    final m = RegExp(r"^of (your|(.+)'s) daily limit\nfrom this (.+)$").firstMatch(s);
    if (m == null) return null;
    final who = m.group(1) == 'your' ? 'de tu límite diario' : 'del límite diario de ${m.group(2)}';
    return '$who\nde ${_thisNoun[m.group(3)] ?? 'este envase'}';
  },
  // 'Kid, 8 to 12, about 30 kg (66 lb)'
  (s) {
    final m = RegExp(r'^(.+), about (\d+ kg \(\d+ lb\))$').firstMatch(s);
    if (m == null) return null;
    return '${kEs[m.group(1)] ?? m.group(1)}, unos ${m.group(2)}';
  },
  // 'In the black ovenable tray (cpet), microwave'
  (s) {
    final m = RegExp(r'^In the (.+), microwave$').firstMatch(s);
    if (m == null) return null;
    return 'En ${_label(m.group(1)!)}, microondas';
  },
  (s) {
    final m = RegExp(r'^A typical weight for this group is (.+)\.$').firstMatch(s);
    return m == null ? null : 'Un peso típico para esta edad es ${m.group(1)}.';
  },
  (s) {
    final m = RegExp(r'^Quick estimate: (.+)$').firstMatch(s);
    return m == null ? null : 'Cálculo rápido: ${_label(m.group(1)!)}';
  },
];
