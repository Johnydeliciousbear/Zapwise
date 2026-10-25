// Container type from the vision model's material output.
//
// The bundled baseline model was trained on TrashNet (cardboard, glass, metal, paper, plastic,
// trash). It cannot tell CPET from PP, and on real store photos it often could not tell the
// material family either, so it only orders a picture-choice question; the user taps the picture.
// When the student's own model (classes = container keys) replaces it, labels map 1:1 and the
// question is only asked when the model is unsure.
class ContainerGuess {
  final String? containerKey; // set when confident
  final List<String> askAmong; // picture choices to show, best first
  final double confidence;
  final String family;
  const ContainerGuess({this.containerKey, this.askAmong = const [], required this.confidence, required this.family});
  bool get needsQuestion => containerKey == null;
}

/// Picture choices per material family, ordered by how common they are for packaged meals.
const Map<String, List<String>> kFamilyChoices = {
  'plastic_family': ['cpet_tray', 'pp_container', 'takeout_tub', 'pet_clamshell', 'eps_foam', 'ps_rigid'],
  'paper_family': ['paperboard_tray', 'pet_board_tray', 'paper_cup'],
  'glass': ['glass'],
  'metal': ['metal'],
  'unknown': ['ceramic', 'glass', 'pp_container', 'cpet_tray', 'paperboard_tray', 'metal'],
};

ContainerGuess identifyContainer(List<double> probs, List<String> appKeys, Set<String> knownContainerKeys, {double sure = 0.80}) {
  var best = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[best]) best = i;
  }
  final key = appKeys[best];
  final conf = probs[best];
  // student model: labels are container keys
  if (knownContainerKeys.contains(key)) {
    if (conf >= sure) return ContainerGuess(containerKey: key, confidence: conf, family: key);
    final order = [for (var i = 0; i < probs.length; i++) i]..sort((a, b) => probs[b].compareTo(probs[a]));
    return ContainerGuess(askAmong: [for (final i in order.take(4)) appKeys[i]], confidence: conf, family: key);
  }
  // baseline model: families. It never decides on its own. On the student's 49 store photos of
  // containers with known material (ml/field_photo_eval.py, 2026-10-14) it was right 9 times, and it
  // called PP boxes, paper plates and stoneware "metal" with confidence up to 1.0, which would have
  // told users not to microwave a microwave-safe box. Its family only orders the picture choices.
  final choices = kFamilyChoices[key] ?? kFamilyChoices['unknown']!;
  final ask = [...choices, for (final k in kFamilyChoices['unknown']!) if (!choices.contains(k)) k];
  return ContainerGuess(askAmong: ask, confidence: conf, family: key);
}
