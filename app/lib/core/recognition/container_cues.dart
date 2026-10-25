// Reads printed and moulded markings on a container (via ML Kit OCR) and turns them into
// container-type candidates. This is how the app separates CPET from PP: colour does not
// work (black PP and white or natural CPET are both sold [S71, S74]), but the markings do.
//   resin code (ASTM D7611): 1 PETE/PET, 2 HDPE, 3 PVC, 4 LDPE, 5 PP, 6 PS, 7 other [S72]
//   CPET trays: code 1 plus "dual ovenable" or an oven limit such as 400 F
//   PP: code 5 and "microwave safe", no oven claim [S71, S73]
//   glass and stoneware words win over a bare "microwave safe" or "oven safe" claim; lid wording
//   ("do not microwave lid") is a lid instruction, not a do-not-microwave label (store photos 2026-10)
// tool/cues_check.mjs runs the same patterns in JavaScript; keep both in step.
import 'container_identifier.dart';

class ContainerCues {
  final int? resinCode;
  final Set<String> polymers; // CPET, PET, PP, PS, PE, PVC, OTHER
  final bool ovenClaim;
  final bool microwaveClaim;
  final bool doNotMicrowave;
  final bool paper;
  final bool foam;
  final bool cup;
  final bool lidOff; // label says to heat it without the lid (or with the lid only resting on top)
  final bool glass;
  final bool ceramic;
  final bool melamine;
  const ContainerCues({
    this.resinCode,
    this.polymers = const {},
    this.ovenClaim = false,
    this.microwaveClaim = false,
    this.doNotMicrowave = false,
    this.paper = false,
    this.foam = false,
    this.cup = false,
    this.lidOff = false,
    this.glass = false,
    this.ceramic = false,
    this.melamine = false,
  });

  bool get isEmpty =>
      resinCode == null && polymers.isEmpty && !ovenClaim && !microwaveClaim && !doNotMicrowave && !paper && !foam && !lidOff && !glass && !ceramic && !melamine;
}

const Map<int, String> kResinPolymer = {1: 'PET', 2: 'PE', 3: 'PVC', 4: 'PE', 5: 'PP', 6: 'PS', 7: 'OTHER'};

const _abbr = r'(PETE|PET|HDPE|PE-HD|LDPE|PE-LD|PVC|PP|PS|OTHER)';
final _codeAfter = RegExp('(?<![\\d.])([1-7])\\s*$_abbr\\b', caseSensitive: false);
final _codeBefore = RegExp('\\b$_abbr\\s*([1-7])(?![\\d.])', caseSensitive: false);
final _codeHash = RegExp(r'(?:#|no\.?\s*)([1-7])(?![\d.])', caseSensitive: false);
final _codeSymbol = RegExp('[♳-♹]');
final _cpet = RegExp(r'\bc-?pet\b', caseSensitive: false);
final _pet = RegExp(r'\b(?:pete|pet)\b', caseSensitive: false);
final _pp = RegExp(r'\b(?:pp|polypropylene)\b', caseSensitive: false);
final _ps = RegExp(r'\b(?:ps|polystyrene)\b', caseSensitive: false);
final _pe = RegExp(r'\b(?:hdpe|ldpe|pe-hd|pe-ld|polyethylene)\b', caseSensitive: false);
final _pvc = RegExp(r'\bpvc\b', caseSensitive: false);
final _oven = RegExp(
    r'dual[\s-]?ovenable|\bovenable|oven[\s-]?safe|conventional oven|oven (?:and|&|or) microwave|microwave (?:and|&|or) (?:conventional )?oven|(?:up to|to|max\.?)\s*(?:4[0-4]\d)\s*°?\s*f\b|(?:up to|to|max\.?)\s*(?:2[0-3]\d)\s*°?\s*c\b',
    caseSensitive: false);
// "SAFE FOR MICROWAVE", "MICROWAVE REHEATABLE", "MICROWAVE & FREEZER SAFE", "MICROWAVE OVEN SAFE" (store photos 2026-10)
final _microwave = RegExp(
    r'microwave[\s-]?(?:oven[\s-]?)?safe|microwavable|microwaveable|safe for (?:the )?microwave|microwave[\s-]?reheat|microwave\s*(?:,|and|&)\s*(?:[a-z]+\s*(?:,|and|&)?\s*){1,3}safe',
    caseSensitive: false);
final _microwaveOven = RegExp(r'microwave ovens?', caseSensitive: false);
final _noOven = RegExp(
    r'not (?:conventional )?oven[\s-]?safe|not ovenable|not for (?:use in )?(?:the |a )?(?:conventional |toaster )?oven|do not (?:use|cook|heat|place|put)(?: it| tray| this)? in (?:the |a )?(?:conventional |toaster )?oven|microwave only',
    caseSensitive: false);
final _doNot = RegExp(r'do not microwave(?!\s*(?:the\s*)?lids?\b)|not microwave[\s-]?safe|not for (?:use in )?(?:the )?microwave', caseSensitive: false);
// heat without the lid: "WITHOUT LID", "DO NOT MICROWAVE LID", "REMOVE LID BEFORE ...", "WITH LID REMOVED"
final _lidOff = RegExp(r'without (?:the )?lid|remove (?:the )?lid|lid (?:is )?removed|do not microwave (?:the )?lids?\b', caseSensitive: false);
final _glass = RegExp(r'\bglass\b|borosilicate', caseSensitive: false);
final _ceramic = RegExp(r'stoneware|ceramic|porcelain|earthenware', caseSensitive: false);
final _melamine = RegExp(r'bamboo|melamine', caseSensitive: false); // 'bamboo ware' is melamine resin with bamboo fibre [S82]
final _paper = RegExp(r'\bpaper(?:board)?\b|\bfib(?:er|re)\b|\bcardboard\b|pressed paper|compostable|bagasse|sugarcane', caseSensitive: false);
final _foam = RegExp(r'\bfoam\b|styrofoam|\beps\b', caseSensitive: false);
final _cupWord = RegExp(r'\bcups?\b|\bbowls?\b', caseSensitive: false);

ContainerCues readContainerCues(String text) {
  int? code;
  final m1 = _codeAfter.firstMatch(text);
  final m2 = _codeBefore.firstMatch(text);
  final m3 = _codeHash.firstMatch(text);
  final m4 = _codeSymbol.firstMatch(text);
  if (m1 != null) {
    code = int.parse(m1.group(1)!);
  } else if (m2 != null) {
    code = int.parse(m2.group(2)!);
  } else if (m4 != null) {
    code = m4.group(0)!.codeUnitAt(0) - 0x2672;
  } else if (m3 != null) {
    code = int.parse(m3.group(1)!);
  }
  final polymers = <String>{};
  if (_cpet.hasMatch(text)) polymers.add('CPET');
  if (_pet.hasMatch(text)) polymers.add('PET');
  if (_pp.hasMatch(text)) polymers.add('PP');
  if (_ps.hasMatch(text)) polymers.add('PS');
  if (_pe.hasMatch(text)) polymers.add('PE');
  if (_pvc.hasMatch(text)) polymers.add('PVC');
  if (code != null) polymers.add(kResinPolymer[code]!);
  final doNot = _doNot.hasMatch(text);
  // "not oven safe", "do not use in conventional oven" and "microwave only" cancel an oven claim
  final noOven = _noOven.hasMatch(text);
  return ContainerCues(
    resinCode: code,
    polymers: polymers,
    ovenClaim: !noOven && _oven.hasMatch(text.replaceAll(_noOven, ' ').replaceAll(_microwaveOven, 'microwave')),
    microwaveClaim: !doNot && _microwave.hasMatch(text),
    doNotMicrowave: doNot,
    paper: _paper.hasMatch(text) && !_melamine.hasMatch(text),
    melamine: _melamine.hasMatch(text),
    foam: _foam.hasMatch(text),
    cup: _cupWord.hasMatch(text),
    lidOff: _lidOff.hasMatch(text),
    glass: _glass.hasMatch(text),
    ceramic: _ceramic.hasMatch(text),
  );
}

/// Ranked container keys suggested by the markings (best first). Empty when the markings say
/// nothing useful; the app then falls back to the vision model and a picture question.
List<String> candidatesFromCues(ContainerCues c) {
  final out = <String>[];
  void add(String k) {
    if (!out.contains(k)) out.add(k);
  }

  final p = c.polymers;
  final inert = c.glass || c.ceramic;
  if (c.melamine) add('melamine');
  if (c.glass) add('glass');
  if (c.ceramic) add('ceramic');
  if (p.contains('CPET')) add('cpet_tray');
  if (c.foam) add('eps_foam');
  if (p.contains('PS') && !c.foam) add('ps_rigid');
  if (c.paper) {
    if (c.ovenClaim) add('pet_board_tray');
    if (c.cup) add('paper_cup');
    add('paperboard_tray');
  }
  if (p.contains('PET')) {
    if (c.ovenClaim) {
      add('cpet_tray');
    } else {
      add('pet_clamshell');
      add('cpet_tray');
    }
  }
  if (p.contains('PP')) add('pp_container');
  if (c.ovenClaim && !c.paper && !inert && !c.melamine) add('cpet_tray');
  if (c.microwaveClaim && !p.contains('PET') && !p.contains('CPET') && !c.paper && !inert && !c.melamine) add('pp_container');
  return out;
}

/// True when the markings alone are strong enough to pick [key] without asking:
/// a matching resin code or polymer name, the word CPET, foam, or an oven claim on paper.
bool cuesDecisive(ContainerCues c, String key) {
  final p = c.polymers;
  return switch (key) {
    'cpet_tray' => p.contains('CPET') || (p.contains('PET') && c.ovenClaim),
    'pp_container' => c.resinCode == 5 || p.contains('PP'),
    'eps_foam' => c.foam,
    'ps_rigid' => c.resinCode == 6 || p.contains('PS'),
    'pet_board_tray' => c.paper && c.ovenClaim,
    'paper_cup' => c.paper && c.cup,
    'glass' => c.glass && !c.ceramic && p.isEmpty,
    'ceramic' => c.ceramic && !c.glass && p.isEmpty,
    'melamine' => c.melamine,
    _ => false,
  };
}

class ContainerDecision {
  final String? containerKey; // set when the evidence points to one type
  final List<String> askAmong; // picture choices otherwise, best first
  final ContainerCues cues;
  final ContainerGuess? vision;
  const ContainerDecision(this.containerKey, this.askAmong, this.cues, this.vision);
  bool get labelSaysDoNotMicrowave => cues.doNotMicrowave;
  bool get labelSaysLidOff => cues.lidOff;
}

/// Markings win over the image. A single candidate backed by a decisive marking is taken;
/// anything weaker becomes a picture question with the marking-based guess first.
/// Without markings, a confident vision result decides or provides the picture choices.
ContainerDecision decideContainer(ContainerCues cues, ContainerGuess? guess) {
  final fromCues = candidatesFromCues(cues);
  if (fromCues.length == 1 && cuesDecisive(cues, fromCues.first)) return ContainerDecision(fromCues.first, const [], cues, guess);
  if (fromCues.isNotEmpty) {
    final ask = [...fromCues];
    for (final k in guess?.askAmong ?? const <String>[]) {
      if (!ask.contains(k)) ask.add(k);
    }
    return ContainerDecision(null, ask, cues, guess);
  }
  if (guess != null && guess.containerKey != null) return ContainerDecision(guess.containerKey, const [], cues, guess);
  return ContainerDecision(null, guess?.askAmong ?? kFamilyChoices['unknown']!, cues, guess);
}
