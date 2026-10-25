// Food enthalpy balance: how warm the meal is after a given amount of absorbed energy.
//
// Reference state: the food at its starting temperature t0. Frozen food first warms to 0 C,
// then melts (latent heat x water fraction), then warms to boiling where the average
// temperature stops rising. Values in ModelParams (water fraction, heat capacities) [S27].
import 'dart:math' as m;

class FoodThermal {
  final double t0;
  final double water;
  final double cWater;
  final double cSolids;
  final double cFrozen;
  final double latent;
  final double tBoil;

  const FoodThermal({
    required this.t0,
    this.water = 0.75,
    this.cWater = 4.187,
    this.cSolids = 1.8,
    this.cFrozen = 2.05,
    this.latent = 333.57,
    this.tBoil = 100.0,
  });

  double get cThawed => water * cWater + (1.0 - water) * cSolids;
  double get lMelt => water * latent;

  /// Enthalpy above the starting state (J/g) at temperature t (C).
  double h(double t) {
    if (t0 < 0) {
      if (t <= 0) return cFrozen * (t - t0);
      return cFrozen * (0 - t0) + lMelt + cThawed * m.min(t, tBoil);
    }
    return cThawed * (m.min(t, tBoil) - t0);
  }

  /// Average food temperature (C) for enthalpy h (J/g).
  double temp(double h) {
    if (t0 < 0) {
      final hIce = cFrozen * (0 - t0);
      if (h <= hIce) return t0 + h / cFrozen;
      if (h <= hIce + lMelt) return 0.0;
      return m.min(tBoil, (h - hIce - lMelt) / cThawed);
    }
    return m.min(tBoil, t0 + h / cThawed);
  }
}
