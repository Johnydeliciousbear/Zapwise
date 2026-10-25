// Numerical building blocks of the migration estimate.
// Mirrors engine_py/zapwise_engine.py; test/engine_test.dart checks both agree.
import 'dart:math' as m;

/// xorshift32. Same sequence as the Python reference for the same seed.
class Rng {
  int _x;
  Rng(int seed) : _x = (seed & 0xFFFFFFFF) == 0 ? 0x9E3779B9 : (seed & 0xFFFFFFFF);

  int nextU32() {
    var x = _x;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _x = x & 0xFFFFFFFF;
    return _x;
  }

  double uniform(double lo, double hi) => lo + (hi - lo) * (nextU32() / 4294967296.0);

  /// Standard normal by Box-Muller from two draws (u1 in (0, 1] so the log is finite).
  double normal() {
    final u1 = 1.0 - nextU32() / 4294967296.0;
    final u2 = nextU32() / 4294967296.0;
    return m.sqrt(-2.0 * m.log(u1)) * m.cos(2.0 * m.pi * u2);
  }
}

/// exp(z^2) * erfc(z) for z >= 0 (Numerical Recipes erfcc fit, fractional error < 1.2e-7).
double erfcx(double z) {
  if (z < 0) throw ArgumentError('erfcx is defined here for z >= 0');
  final t = 1.0 / (1.0 + 0.5 * z);
  final p = -1.26551223 +
      t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277))))))));
  return t * m.exp(p);
}

/// Piringer upper-bound diffusion coefficient (cm2/s), JRC59476 [S01].
double dPiringer(double apPrime, double tau, double mr, double tC) {
  final tk = tC + 273.15;
  final ap = apPrime - tau / tk;
  return 1e4 * m.exp(ap - 0.1351 * m.pow(mr, 2.0 / 3.0) + 0.003 * mr - 10454.0 / tk);
}

/// Huang et al. 2017 QPPR diffusion coefficient (cm2/s) [S78, Eq. 5]:
/// log10 D (m2/s) = intercept + bLogMw log10 MW + b + (tau + betaInvT) / T.
double dHuang2017(double intercept, double bLogMw, double betaInvT, double b, double tau, double mw, double tC) {
  final tk = tC + 273.15;
  return 1e4 * m.pow(10.0, intercept + bLogMw * log10(mw) + b + (tau + betaInvT) / tk).toDouble();
}

double log10(double x) => m.log(x) / m.ln10;

/// Arrhenius diffusion coefficient (cm2/s) from a fitted D0 and activation energy.
double dArrhenius(double d0, double eaKj, double tC, [double rGas = 8.314462618]) {
  final tk = tC + 273.15;
  return d0 * m.exp(-eaKj * 1000.0 / (rGas * tk));
}

/// k-th positive root of tan(q) = -alpha q, by bisection on ((k - 1/2) pi, k pi).
double crankRoot(double alpha, int k) {
  var lo = (k - 0.5) * m.pi;
  var hi = k * m.pi;
  var flo = m.sin(lo) + alpha * lo * m.cos(lo);
  for (var i = 0; i < 60; i++) {
    final mid = 0.5 * (lo + hi);
    final fm = m.sin(mid) + alpha * mid * m.cos(mid);
    if ((fm > 0) == (flo > 0)) {
      lo = mid;
      flo = fm;
    } else {
      hi = mid;
    }
  }
  return 0.5 * (lo + hi);
}

/// Positive roots of tan(q) = -alpha q, one in each ((k - 1/2) pi, k pi).
List<double> crankRoots(double alpha, int n) => [for (var k = 1; k <= n; k++) crankRoot(alpha, k)];

/// Fraction of the equilibrium amount that has migrated (Crank 1975).
/// fo = (integral of D dt) / d^2, alpha = V_food / (K V_polymer).
double crankFraction(double fo, double alpha, [double shortTimeFo = 0.05]) {
  if (fo <= 0) return 0.0;
  if (fo < shortTimeFo) {
    final x = m.sqrt(fo) / alpha;
    final f = (1.0 + alpha) * (1.0 - erfcx(x));
    return f.clamp(0.0, 1.0).toDouble();
  }
  var s = 0.0;
  for (var k = 1; k <= 200; k++) {
    final q = crankRoot(alpha, k);
    final term = 2.0 * alpha * (1.0 + alpha) / (1.0 + alpha + alpha * alpha * q * q) * m.exp(-q * q * fo);
    s += term;
    if (term < 1e-14) break;
  }
  return (1.0 - s).clamp(0.0, 1.0).toDouble();
}

/// Linear-interpolation percentile of an already sorted list.
double? percentile(List<double> sorted, double q) {
  final n = sorted.length;
  if (n == 0) return null;
  final pos = q * (n - 1);
  final lo = pos.floor();
  final hi = m.min(lo + 1, n - 1);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}
