/* ZapWise engine, JavaScript port of engine_py/zapwise_engine.py (the reference).
   Same steps, same random number generator, same draw order, so results match the
   Python engine and the Dart engine in the Flutter app. Checked by web/check_engine.js. */
(function (root) {
  'use strict';

  // ------------------------------------------------------------ random numbers (xorshift32)
  function Rng(seed) { this.x = (seed >>> 0) || 0x9E3779B9; }
  Rng.prototype.nextU32 = function () {
    var x = this.x;
    x = (x ^ (x << 13)) >>> 0;
    x = (x ^ (x >>> 17)) >>> 0;
    x = (x ^ (x << 5)) >>> 0;
    this.x = x;
    return x;
  };
  Rng.prototype.uniform = function (lo, hi) { return lo + (hi - lo) * (this.nextU32() / 4294967296.0); };
  Rng.prototype.normal = function () {
    var u1 = 1.0 - this.nextU32() / 4294967296.0;
    var u2 = this.nextU32() / 4294967296.0;
    return Math.sqrt(-2.0 * Math.log(u1)) * Math.cos(2.0 * Math.PI * u2);
  };

  // ------------------------------------------------------------ special functions
  function erfcx(z) {
    var t = 1.0 / (1.0 + 0.5 * z);
    var p = -1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 + t * (0.27886807 + t * (-1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277))))))));
    return t * Math.exp(p);
  }
  function lnDCoefficients(pol, h, mw) {
    var aPir = Math.log(1e4) + pol.ap_prime - 0.1351 * Math.pow(mw, 2.0 / 3.0) + 0.003 * mw;
    var bPir = -(pol.tau + 10454.0);
    var ln10 = Math.log(10.0);
    var aH = ln10 * (4.0 + h.intercept + h.b_logmw * Math.log10(mw) + pol.huang_b);
    var bH = ln10 * (pol.huang_tau + h.beta_invt);
    return [[aPir, bPir], [aH, bH]];
  }
  function dArrhenius(d0, eaKj, tC, rGas) {
    return d0 * Math.exp(-eaKj * 1000.0 / ((rGas || 8.314462618) * (tC + 273.15)));
  }
  function crankRoot(alpha, k) {
    var lo = (k - 0.5) * Math.PI, hi = k * Math.PI;
    var flo = Math.sin(lo) + alpha * lo * Math.cos(lo);
    for (var i = 0; i < 60; i++) {
      var mid = 0.5 * (lo + hi);
      var fm = Math.sin(mid) + alpha * mid * Math.cos(mid);
      if ((fm > 0) === (flo > 0)) { lo = mid; flo = fm; } else { hi = mid; }
    }
    return 0.5 * (lo + hi);
  }
  function crankFraction(fo, alpha, shortFo) {
    if (fo <= 0) return 0.0;
    if (fo < (shortFo === undefined ? 0.05 : shortFo)) {
      var x = Math.sqrt(fo) / alpha;
      return Math.min(1.0, Math.max(0.0, (1.0 + alpha) * (1.0 - erfcx(x))));
    }
    var s = 0.0;
    for (var k = 1; k <= 200; k++) {
      var q = crankRoot(alpha, k);
      var term = 2.0 * alpha * (1.0 + alpha) / (1.0 + alpha + alpha * alpha * q * q) * Math.exp(-q * q * fo);
      s += term;
      if (term < 1e-14) break;
    }
    return Math.min(1.0, Math.max(0.0, 1.0 - s));
  }
  function percentile(v, q) {
    var n = v.length; if (!n) return null;
    var pos = q * (n - 1), lo = Math.floor(pos), hi = Math.min(lo + 1, n - 1);
    return v[lo] + (v[hi] - v[lo]) * (pos - lo);
  }

  // ------------------------------------------------------------ food heating
  function FoodThermal(o) {
    this.t0 = o.t0; this.water = o.water; this.cWater = o.cWater; this.cSolids = o.cSolids;
    this.cFrozen = o.cFrozen; this.latent = o.latent; this.tBoil = o.tBoil;
    this.cThawed = this.water * this.cWater + (1.0 - this.water) * this.cSolids;
    this.lMelt = this.water * this.latent;
  }
  FoodThermal.prototype.h = function (t) {
    if (this.t0 < 0) {
      if (t <= 0) return this.cFrozen * (t - this.t0);
      return this.cFrozen * (0 - this.t0) + this.lMelt + this.cThawed * Math.min(t, this.tBoil);
    }
    return this.cThawed * (Math.min(t, this.tBoil) - this.t0);
  };
  FoodThermal.prototype.temp = function (h) {
    if (this.t0 < 0) {
      var hIce = this.cFrozen * (0 - this.t0);
      if (h <= hIce) return this.t0 + h / this.cFrozen;
      if (h <= hIce + this.lMelt) return 0.0;
      return Math.min(this.tBoil, (h - hIce - this.lMelt) / this.cThawed);
    }
    return Math.min(this.tBoil, this.t0 + h / this.cThawed);
  };

  // ------------------------------------------------------------ recipe
  function mid(a, b) { return (b === null || b === undefined) ? a : 0.5 * (a + b); }
  function tableTime(table, watt) {
    var pts = table.map(function (e) { return [e.watt, mid(e.time_s, e.time_s_max)]; }).sort(function (a, b) { return a[0] - b[0]; });
    if (watt <= pts[0][0]) return pts[0][1] * pts[0][0] / watt;
    var last = pts[pts.length - 1];
    if (watt >= last[0]) return last[1] * last[0] / watt;
    for (var i = 0; i < pts.length - 1; i++) {
      var wa = pts[i][0], ta = pts[i][1], wb = pts[i + 1][0], tb = pts[i + 1][1];
      if (wa <= watt && watt <= wb) {
        var xa = 1.0 / wa, xb = 1.0 / wb, x = 1.0 / watt;
        return ta + (tb - ta) * (x - xa) / (xb - xa);
      }
    }
    throw new Error('unreachable');
  }
  function resolveRecipe(product, watt) {
    var r = product.recipe, flags = [], out = [], ref = r.ref_watt;
    r.steps.forEach(function (s) {
      var lo, hi;
      if (s.kind === 'cook') {
        lo = s.time_s; hi = s.time_s_max || s.time_s; var f = ref / watt;
        out.push({ kind: 'cook', time_s: mid(lo, s.time_s_max) * f, time_lo: lo * f, time_hi: hi * f, text: s.text });
      } else if (s.kind === 'cook_table') {
        var t = tableTime(r.watt_table, watt);
        out.push({ kind: 'cook', time_s: t, time_lo: t, time_hi: t, text: s.text });
      } else if (s.kind === 'stand') {
        lo = s.time_s; hi = s.time_s_max || s.time_s;
        out.push({ kind: 'stand', time_s: mid(lo, s.time_s_max), time_lo: lo, time_hi: hi, text: s.text });
      } else if (s.kind === 'oven') {
        out.push({ kind: 'oven', time_s: 0, time_lo: 0, time_hi: 0, text: s.text });
        if (flags.indexOf('oven_step_not_modeled') < 0) flags.push('oven_step_not_modeled');
      } else {
        out.push({ kind: 'action', time_s: 0, time_lo: 0, time_hi: 0, text: s.text });
      }
    });
    if (r.ref_watt_assumed) flags.push('ref_watt_assumed');
    if (r.min_watt && watt < r.min_watt) flags.push('below_label_min_watt');
    if (!out.some(function (s) { return s.kind === 'cook'; })) flags.push('no_recipe');
    if (r.watt_table && r.watt_table.length) {
      var ws = r.watt_table.map(function (e) { return e.watt; });
      if (watt < Math.min.apply(null, ws) || watt > Math.max.apply(null, ws)) flags.push('outside_label_table');
    }
    return { steps: out, flags: flags };
  }

  // ------------------------------------------------------------ engine
  function Engine(params, products) { this.P = params; this.products = products; this.p = params.params; }

  Engine.prototype.foodClass = function (key) {
    var fc = this.P.food_classes; for (var i = 0; i < fc.length; i++) if (fc[i].key === key) return fc[i];
    throw new Error('food class ' + key);
  };
  Engine.prototype.thermal = function (product) {
    var p = this.p, st = product.storage;
    var t0 = st === 'frozen' ? p.T0_frozen_C : st === 'chilled' ? p.T0_chilled_C : p.T0_shelf_C;
    return new FoodThermal({ t0: t0, water: p.water_fraction, cWater: p.c_water, cSolids: p.c_solids, cFrozen: p.c_frozen, latent: p.latent_heat_water, tBoil: p.T_boil_C });
  };
  Engine.prototype.substancesFor = function (c) {
    var ck = c.content_key; if (!ck || !this.P.contents[ck]) return [];
    return Object.keys(this.P.contents[ck]).sort();
  };
  Engine.prototype.centralDraw = function (c, fc, subs) {
    var p = this.p, P = this.P, cp = {};
    subs.forEach(function (s) { var v = P.contents[c.content_key][s]; cp[s] = 0.5 * (v.low + v.high); });
    return { pFactor: 0.5 * (p.power_factor_low + p.power_factor_high), edge: p.edge_excess_C, cap: 0.5 * (fc.cap_low + fc.cap_high),
      areaF: 0.5 * (p.area_factor_low + p.area_factor_high), thickness: c.thickness_cm, etoh: 0.5 * (fc.etoh_low + fc.etoh_high), kZ: 0.0, dW: p.d_weight_central, cP0: cp };
  };
  Engine.prototype.randomDraw = function (rng, c, fc, subs) {
    var p = this.p, P = this.P;
    var d = { pFactor: rng.uniform(p.power_factor_low, p.power_factor_high), edge: rng.uniform(p.edge_excess_low_C, p.edge_excess_high_C),
      cap: rng.uniform(fc.cap_low, fc.cap_high), areaF: rng.uniform(p.area_factor_low, p.area_factor_high), thickness: null, etoh: 0, kZ: 0, dW: 0.5, cP0: {} };
    var tl = c.thickness_low, th = c.thickness_high, u = rng.uniform(0.0, 1.0);
    d.thickness = (tl !== null && tl !== undefined) ? tl + (th - tl) * u : c.thickness_cm;
    d.etoh = rng.uniform(fc.etoh_low, fc.etoh_high);
    d.kZ = rng.normal();
    d.dW = rng.uniform(p.d_weight_low, p.d_weight_high);
    subs.forEach(function (s) { var v = P.contents[c.content_key][s]; d.cP0[s] = rng.uniform(v.low, v.high); });
    return d;
  };
  Engine.prototype.contactHistory = function (product, plan, recipeSteps, watt, draw, fc, eatIn, steam) {
    var th = this.thermal(product), p = this.p, onset = p.steam_onset_fraction, dt = p.dt_s;
    var hTarget = th.h(p.T_target_avg_C);
    var cookSum = function (list) { return list.reduce(function (a, s) { return a + (s.kind === 'cook' ? s.time_s : 0); }, 0); };
    var eRecipe = watt * cookSum(recipeSteps);
    if (eRecipe <= 0) eRecipe = watt * cookSum(plan);
    var k = eRecipe > 0 ? hTarget / eRecipe : 0.0, h = 0.0, temps = [], tAvg = th.t0, i, n;
    plan.forEach(function (s) {
      n = Math.floor(s.time_s / dt + 0.5);
      if (s.kind === 'cook') {
        for (i = 0; i < n; i++) {
          h += k * watt * draw.pFactor * dt;
          tAvg = th.temp(h);
          var edge = draw.edge * Math.min(1.0, h / hTarget);
          var tc = Math.min(draw.cap, tAvg + edge);
          if (steam && h / hTarget >= onset) tc = Math.max(tc, th.tBoil);
          temps.push(tc);
        }
      } else if (s.kind === 'stand') {
        for (i = 0; i < n; i++) temps.push(tAvg);
      }
    });
    var tEnd = tAvg;
    if (eatIn) {
      n = Math.floor(p.eat_minutes * 60.0 / dt + 0.5);
      var tStop = Math.min(tEnd, p.eat_end_C);
      for (i = 1; i <= n; i++) temps.push(tEnd + (tStop - tEnd) * i / n);
    }
    var ePlan = watt * cookSum(plan), tMax = th.t0;
    for (i = 0; i < temps.length; i++) if (i === 0 || temps[i] > tMax) tMax = temps[i];
    return { temps: temps, info: { t_end_avg: tEnd, t_contact_max: temps.length ? tMax : th.t0, energy_ratio: eRecipe ? ePlan / eRecipe : null } };
  };
  Engine.prototype.logKpf = function (sub, c, etoh, tEff, kZ) {
    var sp = this.P.substances[sub];
    if (sp.log_kow === null || sp.log_kow === undefined) return [0.0, null];
    var kp = this.P.kpf, co = kp.coefficients, dom = kp.domain, cap = dom[dom.length - 1].logkow_max;
    for (var i = 0; i < dom.length; i++) if (dom[i].etoh_low <= etoh && etoh < dom[i].etoh_high) { cap = dom[i].logkow_max; break; }
    var x = Math.min(sp.log_kow, cap);
    var mat = this.P.polymers[c.polymer].kpf_material;
    var invt = 1.0 / (tEff + 273.15) - 1.0 / this.p.kpf_t_ref_K;
    var lk = co.b0 + co.b_kow * x + co.b_etoh * etoh + co.b_kow_etoh * x * etoh + co.b_invt * invt + kp.material_offsets[mat] + kZ * this.p.kpf_resid_sd;
    return [lk, x];
  };
  Engine.prototype.migrate = function (product, c, temps, draw, subs, massG) {
    var p = this.p, P = this.P, dt = p.dt_s, self = this;
    var area = c.area_ref_cm2 * Math.pow(massG / p.area_ref_mass_g, 2.0 / 3.0) * draw.areaF;
    var d = draw.thickness, vP = area * d, mP = c.density * vP, vF = massG / p.food_density, out = {};
    subs.forEach(function (s) {
      var sp = P.substances[s], theta = 0.0, dtSum = 0.0, i, dd;
      if (sp.model === 'arrhenius') {
        for (i = 0; i < temps.length; i++) { dd = dArrhenius(sp.d0, sp.ea_kj, temps[i], p.R_gas) * dt; theta += dd; dtSum += dd * temps[i]; }
      } else {
        var co = lnDCoefficients(P.polymers[c.polymer], P.huang2017, sp.mw), w = draw.dW;
        var aMix = (1.0 - w) * co[1][0] + w * co[0][0], bMix = (1.0 - w) * co[1][1] + w * co[0][1];
        for (i = 0; i < temps.length; i++) { dd = Math.exp(aMix + bMix / (temps[i] + 273.15)) * dt; theta += dd; dtSum += dd * temps[i]; }
      }
      var tEff = theta > 0 ? dtSum / theta : (temps.length ? temps[temps.length - 1] : 25.0);
      var lkr = self.logKpf(s, c, draw.etoh, tEff, draw.kZ), K = Math.pow(10.0, lkr[0]);
      var alpha = vF / (K * vP), cEff = draw.cP0[s] * sp.diffusible;
      var mEq = cEff * mP * alpha / (1.0 + alpha), fo = theta / (d * d), f = crankFraction(fo, alpha, p.short_time_Fo);
      out[s] = { ug: mEq * f, fraction: f, fo: fo, alpha: alpha, K: K, log_k: lkr[0], theta: theta, t_eff: tEff,
        kow_capped: lkr[1] !== null && lkr[1] < sp.log_kow };
    });
    return out;
  };
  Engine.prototype.exposure = function (mig, portion, bw) {
    var P = this.P, res = {}, out = {};
    Object.keys(mig).forEach(function (s) { var sp = P.substances[s]; res[sp.group] = (res[sp.group] || 0) + mig[s].ug * portion * sp.rpf; });
    Object.keys(res).forEach(function (g) { out[g] = res[g] / (bw * P.groups[g].tdi) * 100.0; });
    return out;
  };
  Engine.prototype.band = function (pct) {
    if (pct === null || pct === undefined) return null;
    return pct < this.p.band_low_pct ? 'lower' : pct < this.p.band_high_pct ? 'middle' : 'higher';
  };
  Engine.prototype.planFor = function (sc, recipeSteps) {
    var plan = sc.plan ? sc.plan.map(function (x) { return { kind: x.kind, time_s: x.time_s }; })
      : recipeSteps.filter(function (s) { return s.kind === 'cook' || s.kind === 'stand'; }).map(function (s) { return { kind: s.kind, time_s: s.time_s }; });
    if (sc.extra_cook_s) {
      var idx = -1; plan.forEach(function (s, i) { if (s.kind === 'cook') idx = i; });
      if (idx >= 0) plan[idx].time_s += sc.extra_cook_s;
    }
    return plan;
  };
  function maxKey(o) { var best = null; Object.keys(o).forEach(function (k) { if (best === null || o[k] > o[best]) best = k; }); return best; }
  function samePlan(a, b) { if (a.length !== b.length) return false; for (var i = 0; i < a.length; i++) if (a[i].kind !== b[i].kind || a[i].time_s !== b[i].time_s) return false; return true; }

  /* sc: { product (object) or product_id, container_key, watt, extra_cook_s, eat_in_container, body_weight_kg, portion, method } */
  Engine.prototype.evaluate = function (sc, mc) {
    if (mc === undefined) mc = true;
    var P = this.P, p = this.p;
    var product = sc.product || this.products[sc.product_id];
    var watt = sc.watt || 1100, bw = sc.body_weight_kg || 70, eatIn = sc.eat_in_container !== false;
    var ckey = sc.container_key || product.container_key;
    if (sc.method === 'stove') ckey = 'stove_pot';
    var c = P.containers[ckey];
    var rr = resolveRecipe(product, watt), recipeSteps = rr.steps;
    var result = { product_id: product.id, container: ckey, status: c.status, flags: rr.flags.slice(), recipe: recipeSteps,
      groups: {}, headline_pct: null, headline_group: null, band: null, range: null, substances: {}, temperature: null, vs_label: null };
    if (product.recipe.oven_only && (sc.method || 'microwave') === 'microwave') {
      result.status = product.recipe.do_not_microwave === 'yes' ? 'label_no_microwave' : 'oven_only';
      return result;
    }
    if (c.status === 'measured') return this.measured(product, ckey, sc, result);
    if (c.status !== 'ok') {
      if (c.status === 'inert') { result.headline_pct = 0.0; result.band = 'lower'; }
      return result;
    }
    var plan = this.planFor(sc, recipeSteps), fc = this.foodClass(product.fat_class), subs = this.substancesFor(c);
    var mass = product.food_mass_g, portion = (sc.portion !== undefined && sc.portion !== null) ? sc.portion : 1.0 / (product.servings || 1.0);
    var draw = this.centralDraw(c, fc, subs), steam = c.contact_mode === 'steam';
    var hist = this.contactHistory(product, plan, recipeSteps, watt, draw, fc, eatIn, steam);
    var mig = this.migrate(product, c, hist.temps, draw, subs, mass);
    var groups = this.exposure(mig, portion, bw);
    result.temperature = hist.info; result.substances = mig; result.groups = groups;
    var hg = maxKey(groups);
    result.headline_pct = hg ? groups[hg] : 0.0; result.headline_group = hg; result.band = this.band(result.headline_pct);
    var labelPlan = recipeSteps.filter(function (s) { return s.kind === 'cook' || s.kind === 'stand'; }).map(function (s) { return { kind: s.kind, time_s: s.time_s }; });
    if (labelPlan.length && (!samePlan(plan, labelPlan) || !eatIn)) {
      var lt = this.contactHistory(product, labelPlan, recipeSteps, watt, draw, fc, true, steam);
      var lg = this.exposure(this.migrate(product, c, lt.temps, draw, subs, mass), portion, bw), lk = maxKey(lg), base = lk ? lg[lk] : 0;
      result.vs_label = base > 0 ? result.headline_pct / base : null;
    } else {
      result.vs_label = 1.0;
    }
    var ti = hist.info;
    if (ti.energy_ratio !== null && ti.energy_ratio < p.energy_short_ratio) result.flags.push('below_recipe_energy');
    if (c.max_use_c && ti.t_contact_max > c.max_use_c) result.flags.push('above_container_max_use');
    var pol = P.polymers[c.polymer || ''];
    if (pol && subs.some(function (s) { return P.substances[s].model === 'piringer'; }) && ti.t_contact_max > pol.t_max_valid_c) result.flags.push('outside_model_validity');
    if (subs.some(function (s) { return P.substances[s].model === 'arrhenius'; })) result.flags.push('arrhenius_extrapolated');
    if (product.fat_known === false) result.flags.push('fat_unknown');
    if (Object.keys(mig).some(function (s) { return mig[s].kow_capped; })) result.flags.push('kow_capped_to_data');
    if (mc) {
      var rng = new Rng(Math.floor(p.mc_seed)), vals = [];
      for (var i = 0; i < Math.floor(p.mc_samples); i++) {
        var dr = this.randomDraw(rng, c, fc, subs);
        var tt = this.contactHistory(product, plan, recipeSteps, watt, dr, fc, eatIn, steam);
        var g = this.exposure(this.migrate(product, c, tt.temps, dr, subs, mass), portion, bw), gk = maxKey(g);
        vals.push(gk ? g[gk] : 0.0);
      }
      vals.sort(function (a, b) { return a - b; });
      result.range = { p05: percentile(vals, 0.05), p50: percentile(vals, 0.50), p95: percentile(vals, 0.95) };
    }
    return result;
  };
  Engine.prototype.measured = function (product, ckey, sc, result) {
    var P = this.P, recs = P.measured[ckey] || [], bw = sc.body_weight_kg || 70;
    var portion = (sc.portion !== undefined && sc.portion !== null) ? sc.portion : 1.0 / (product.servings || 1.0);
    var massKg = product.food_mass_g / 1000.0, lo = {}, md = {}, hi = {};
    recs.forEach(function (r) {
      var f = (r.basis === 'per_kg_food' ? massKg : 1.0) * portion, g = r.group;
      lo[g] = (lo[g] || 0) + r.low * f; md[g] = (md[g] || 0) + r.mid * f; hi[g] = (hi[g] || 0) + r.high * f;
    });
    var groups = {}, tdi = {};
    Object.keys(md).forEach(function (g) { tdi[g] = bw * P.groups[g].tdi; groups[g] = md[g] / tdi[g] * 100.0; });
    result.groups = groups;
    var hg = maxKey(groups);
    if (hg) {
      result.headline_group = hg; result.headline_pct = groups[hg]; result.band = this.band(groups[hg]);
      result.range = { p05: lo[hg] / tdi[hg] * 100.0, p50: groups[hg], p95: hi[hg] / tdi[hg] * 100.0 };
    }
    result.flags.push('measurement_based');
    result.vs_label = null;
    return result;
  };

  root.ZapEngine = { Engine: Engine, Rng: Rng, resolveRecipe: resolveRecipe, crankFraction: crankFraction };
})(typeof window !== 'undefined' ? window : globalThis);
