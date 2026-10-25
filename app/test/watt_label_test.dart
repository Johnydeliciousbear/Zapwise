import 'package:flutter_test/flutter_test.dart';
import 'package:zapwise/core/recognition/watt_label.dart';

void main() {
  test('reads the output power from appliance labels', () {
    const cases = <String, double?>{
      'MODEL NN-SN65KB\n120V~ 60Hz\nINPUT 1500W\nOUTPUT 1200W': 1200,
      'Microwave output: 1.1 kW\nRated input 1.5 kW': 1100,
      'Rated Power Output: 1000 W\nInput Power: 1450W': 1000,
      '120 V 60 Hz 13.0 A 1500 W\nMicrowave 1100 watts': 1100,
      'COOKING POWER 900W': 900,
      'Serial 12345 made in China': null,
      '1150 W': 1150,
    };
    cases.forEach((text, want) => expect(wattFromApplianceLabel(text), want, reason: text));
  });
}
