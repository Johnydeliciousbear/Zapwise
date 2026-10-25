"""ZapWise reference engine (Python).

This file is the readable reference for the Dart engine in app/lib/core/engine/.
Both implementations follow the same steps and use the same random number
generator, so test vectors produced here (make_test_vectors.py) must be matched by
the Dart unit tests.

Pipeline for one meal
  1. recipe      label steps -> times at the user's wattage (energy equivalence or label table)
  2. heat        food enthalpy balance -> average food temperature -> container contact temperature
  3. diffuse     contact temperature history -> integral of D(T) dt. Organic migrants: between the
                 Huang 2017 QPPR (realistic) and the Piringer upper bound on a log scale. Antimony: Arrhenius fit.
  4. partition   Huang and Jolliet 2019 regression: log Kpf from log Kow, food EtOH-eq, temperature, polymer
  5. migrate     Crank solution for a polymer layer against a well-mixed food
  6. expose      micrograms eaten -> % of the tolerable daily intake (TDI) per reference group
  7. range       Monte Carlo over uncertain inputs -> 5th, 50th, 95th percentiles

Units: temperature C (K inside D), time s, length cm, mass g, concentration mg/kg (= ug/g),
migrated amount ug, D cm2/s.
"""
from __future__ import annotations

import json
import math
import os
from dataclasses import dataclass, field

ASSETS = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app', 'assets', 'data')


def load_assets(path=ASSETS):
    params = json.load(open(os.path.join(path, 'zapwise_params.json')))
    products = {p['id']: p for p in json.load(open(os.path.join(path, 'products.json')))['products']}
    return params, products


# =============================================================== random numbers
class Rng:
    """xorshift32. Small, fast and easy to reproduce exactly in Dart."""

    def __init__(self, seed: int):
        self.x = (seed & 0xFFFFFFFF) or 0x9E3779B9

    def next_u32(self) -> int:
        x = self.x
        x ^= (x << 13) & 0xFFFFFFFF
        x ^= x >> 17
        x ^= (x << 5) & 0xFFFFFFFF
        self.x = x & 0xFFFFFFFF
        return self.x

    def uniform(self, lo: float, hi: float) -> float:
        return lo + (hi - lo) * (self.next_u32() / 4294967296.0)

    def normal(self) -> float:
        """Standard normal by Box-Muller from two draws (u1 in (0, 1] so the log is finite)."""
        u1 = 1.0 - self.next_u32() / 4294967296.0
        u2 = self.next_u32() / 4294967296.0
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


# =============================================================== special functions
def erfcx(z: float) -> float:
    """Scaled complementary error function exp(z^2) erfc(z) for z >= 0.

    Chebyshev fit from Numerical Recipes (erfcc), fractional error below 1.2e-7.
    erfc(z) = t exp(-z^2 + P(t)), so exp(z^2) erfc(z) = t exp(P(t)), which stays
    finite for large z.
    """
    if z < 0:
        raise ValueError('erfcx defined here for z >= 0')
    t = 1.0 / (1.0 + 0.5 * z)
    p = (-1.26551223 + t * (1.00002368 + t * (0.37409196 + t * (0.09678418 + t * (-0.18628806 + t * (0.27886807 + t * (
        -1.13520398 + t * (1.48851587 + t * (-0.82215223 + t * 0.17087277)))))))))
    return t * math.exp(p)


# =============================================================== diffusion coefficients
def d_piringer(ap_prime: float, tau: float, mr: float, t_c: float) -> float:
    """Piringer upper-bound diffusion coefficient in cm2/s [JRC59476, S01]."""
    tk = t_c + 273.15
    ap = ap_prime - tau / tk
    return 1e4 * math.exp(ap - 0.1351 * mr ** (2.0 / 3.0) + 0.003 * mr - 10454.0 / tk)


def d_huang2017(intercept: float, b_logmw: float, beta_invt: float, b: float, tau: float, mw: float, t_c: float) -> float:
    """Huang et al. 2017 QPPR diffusion coefficient in cm2/s [S78, Eq. 5]:
    log10 D (m2/s) = intercept + b_logmw log10 MW + b + (tau + beta_invt)/T."""
    tk = t_c + 273.15
    return 1e4 * 10.0 ** (intercept + b_logmw * math.log10(mw) + b + (tau + beta_invt) / tk)


def ln_d_coefficients(pol: dict, h: dict, mw: float):
    """ln D(T) = A + B/T (T in K) for the Piringer upper bound and the Huang 2017 QPPR.
    Returns ((A_pir, B_pir), (A_huang, B_huang)) in ln(cm2/s)."""
    a_pir = math.log(1e4) + pol['ap_prime'] - 0.1351 * mw ** (2.0 / 3.0) + 0.003 * mw
    b_pir = -(pol['tau'] + 10454.0)
    ln10 = math.log(10.0)
    a_h = ln10 * (4.0 + h['intercept'] + h['b_logmw'] * math.log10(mw) + pol['huang_b'])
    b_h = ln10 * (pol['huang_tau'] + h['beta_invt'])
    return (a_pir, b_pir), (a_h, b_h)


def d_arrhenius(d0: float, ea_kj: float, t_c: float, r_gas: float = 8.314462618) -> float:
    tk = t_c + 273.15
    return d0 * math.exp(-ea_kj * 1000.0 / (r_gas * tk))


# =============================================================== Crank solution
def _crank_root(alpha: float, k: int) -> float:
    """k-th positive root of tan(q) = -alpha q, found by bisection on ((k - 1/2) pi, k pi)."""
    lo, hi = (k - 0.5) * math.pi, k * math.pi
    # f(q) = sin q + alpha q cos q changes sign on (lo, hi)
    flo = math.sin(lo) + alpha * lo * math.cos(lo)
    for _ in range(60):
        mid = 0.5 * (lo + hi)
        fm = math.sin(mid) + alpha * mid * math.cos(mid)
        if (fm > 0) == (flo > 0):
            lo, flo = mid, fm
        else:
            hi = mid
    return 0.5 * (lo + hi)


def crank_roots(alpha: float, n: int):
    """Positive roots of tan(q) = -alpha q, one in each ((k - 1/2) pi, k pi)."""
    return [_crank_root(alpha, k) for k in range(1, n + 1)]


def crank_fraction(fo: float, alpha: float, short_time_fo: float = 0.05) -> float:
    """Fraction of the equilibrium amount that has migrated, M_t / M_inf.

    Polymer layer of thickness d, one face against a well-mixed food, the other face
    sealed. fo = (integral of D dt) / d^2, alpha = V_F / (K V_P).
    Short times use the semi-infinite solution (Crank 1975), longer times the series.
    """
    if fo <= 0:
        return 0.0
    if fo < short_time_fo:
        x = math.sqrt(fo) / alpha
        f = (1.0 + alpha) * (1.0 - erfcx(x))
        return min(1.0, max(0.0, f))
    s = 0.0
    for k in range(1, 201):
        q = _crank_root(alpha, k)
        term = 2.0 * alpha * (1.0 + alpha) / (1.0 + alpha + alpha * alpha * q * q) * math.exp(-q * q * fo)
        s += term
        if term < 1e-14:
            break
    return min(1.0, max(0.0, 1.0 - s))


# =============================================================== food heating
@dataclass
class FoodThermal:
    t0: float                 # starting temperature (C)
    water: float = 0.75
    c_water: float = 4.187
    c_solids: float = 1.8
    c_frozen: float = 2.05
    latent: float = 333.57
    t_boil: float = 100.0

    @property
    def c_thawed(self):
        return self.water * self.c_water + (1.0 - self.water) * self.c_solids

    @property
    def l_melt(self):
        return self.water * self.latent

    def h(self, t: float) -> float:
        """Enthalpy (J/g) above the starting state."""
        if self.t0 < 0:
            if t <= 0:
                return self.c_frozen * (t - self.t0)
            return self.c_frozen * (0 - self.t0) + self.l_melt + self.c_thawed * min(t, self.t_boil)
        return self.c_thawed * (min(t, self.t_boil) - self.t0)

    def temp(self, h: float) -> float:
        """Average food temperature (C) for enthalpy h; plateaus at 0 C (melting) and boiling."""
        if self.t0 < 0:
            h_ice = self.c_frozen * (0 - self.t0)
            if h <= h_ice:
                return self.t0 + h / self.c_frozen
            if h <= h_ice + self.l_melt:
                return 0.0
            return min(self.t_boil, (h - h_ice - self.l_melt) / self.c_thawed)
        return min(self.t_boil, self.t0 + h / self.c_thawed)


# =============================================================== recipe
def _mid(a, b):
    return a if b is None else 0.5 * (a + b)


def table_time(table, watt):
    """Cook time at `watt` from a label wattage table, linear in 1/W between entries."""
    pts = sorted(((e['watt'], _mid(e['time_s'], e.get('time_s_max'))) for e in table), key=lambda p: p[0])
    if watt <= pts[0][0]:
        w, t = pts[0]
        return t * w / watt
    if watt >= pts[-1][0]:
        w, t = pts[-1]
        return t * w / watt
    for (wa, ta), (wb, tb) in zip(pts, pts[1:]):
        if wa <= watt <= wb:
            xa, xb, x = 1.0 / wa, 1.0 / wb, 1.0 / watt
            return ta + (tb - ta) * (x - xa) / (xb - xa)
    raise AssertionError


def resolve_recipe(product: dict, watt: float):
    """Label steps converted to the user's oven. Returns (steps, flags).

    steps: list of dict(kind in cook/stand/action/oven, time_s, time_lo, time_hi, text)
    Cook times scale with reference_watt / watt (energy equivalence, first-order rule).
    """
    r = product['recipe']
    flags = []
    out = []
    ref = r['ref_watt']
    for s in r['steps']:
        k = s['kind']
        if k == 'cook':
            lo, hi = s['time_s'], s.get('time_s_max') or s['time_s']
            f = ref / watt
            out.append(dict(kind='cook', time_s=_mid(lo, s.get('time_s_max')) * f, time_lo=lo * f, time_hi=hi * f, text=s['text']))
        elif k == 'cook_table':
            t = table_time(r['watt_table'], watt)
            out.append(dict(kind='cook', time_s=t, time_lo=t, time_hi=t, text=s['text']))
        elif k == 'stand':
            lo, hi = s['time_s'], s.get('time_s_max') or s['time_s']
            out.append(dict(kind='stand', time_s=_mid(lo, s.get('time_s_max')), time_lo=lo, time_hi=hi, text=s['text']))
        elif k == 'oven':
            out.append(dict(kind='oven', time_s=0.0, time_lo=0.0, time_hi=0.0, text=s['text']))
            if 'oven_step_not_modeled' not in flags:
                flags.append('oven_step_not_modeled')
        else:
            out.append(dict(kind='action', time_s=0.0, time_lo=0.0, time_hi=0.0, text=s['text']))
    if r.get('ref_watt_assumed'):
        flags.append('ref_watt_assumed')
    if r.get('min_watt') and watt < r['min_watt']:
        flags.append('below_label_min_watt')
    if not any(s['kind'] == 'cook' for s in out):
        flags.append('no_recipe')
    if r.get('watt_table'):
        ws = [e['watt'] for e in r['watt_table']]
        if watt < min(ws) or watt > max(ws):
            flags.append('outside_label_table')
    return out, flags


# =============================================================== scenario
@dataclass
class Scenario:
    product_id: str
    container_key: str | None = None      # None -> product's own container
    watt: float = 1100.0                   # user's microwave rating
    plan: list | None = None               # [{'kind': 'cook'|'stand', 'time_s': ..}]; None -> recipe
    extra_cook_s: float = 0.0              # convenience: extra time added to the last cook step
    eat_in_container: bool = True
    body_weight_kg: float = 70.0
    portion: float | None = None           # fraction of the package eaten; None -> 1/servings
    method: str = 'microwave'              # microwave | stove


@dataclass
class Draw:
    p_factor: float
    edge: float
    cap: float
    area_f: float
    thickness: float | None
    etoh: float                 # food ethanol equivalent (% v/v) for the partition regression
    k_z: float = 0.0            # standard normal error of the partition regression
    d_w: float = 0.5            # 0 = Huang 2017 QPPR, 1 = Piringer upper bound (log scale)
    c_p0: dict = field(default_factory=dict)


class Engine:
    def __init__(self, params: dict, products: dict):
        self.P = params
        self.products = products
        self.p = params['params']

    # ----------------------------------------------------------- helpers
    def food_class(self, key):
        for fc in self.P['food_classes']:
            if fc['key'] == key:
                return fc
        raise KeyError(key)

    def thermal(self, product):
        st = product['storage']
        t0 = {'frozen': self.p['T0_frozen_C'], 'chilled': self.p['T0_chilled_C']}.get(st, self.p['T0_shelf_C'])
        return FoodThermal(t0=t0, water=self.p['water_fraction'], c_water=self.p['c_water'], c_solids=self.p['c_solids'],
                           c_frozen=self.p['c_frozen'], latent=self.p['latent_heat_water'], t_boil=self.p['T_boil_C'])

    def substances_for(self, container):
        ck = container.get('content_key')
        if not ck or ck not in self.P['contents']:
            return []
        return sorted(self.P['contents'][ck].keys())

    def central_draw(self, container, fc, subs):
        p = self.p
        return Draw(p_factor=0.5 * (p['power_factor_low'] + p['power_factor_high']), edge=p['edge_excess_C'],
                    cap=0.5 * (fc['cap_low'] + fc['cap_high']), area_f=0.5 * (p['area_factor_low'] + p['area_factor_high']),
                    thickness=container.get('thickness_cm'), etoh=0.5 * (fc['etoh_low'] + fc['etoh_high']), k_z=0.0, d_w=p['d_weight_central'],
                    c_p0={s: 0.5 * (self.P['contents'][container['content_key']][s]['low'] + self.P['contents'][container['content_key']][s]['high'])
                          for s in subs})

    def random_draw(self, rng, container, fc, subs):
        """Fixed draw order (the Dart port must match): power, edge, cap, area, thickness, EtOH-eq,
        partition error (two draws), diffusion weight, contents (sorted keys)."""
        p = self.p
        d = Draw(p_factor=rng.uniform(p['power_factor_low'], p['power_factor_high']),
                 edge=rng.uniform(p['edge_excess_low_C'], p['edge_excess_high_C']),
                 cap=rng.uniform(fc['cap_low'], fc['cap_high']),
                 area_f=rng.uniform(p['area_factor_low'], p['area_factor_high']),
                 thickness=None, etoh=0.0)
        tl, th = container.get('thickness_low'), container.get('thickness_high')
        u = rng.uniform(0.0, 1.0)
        d.thickness = (tl + (th - tl) * u) if tl is not None else container.get('thickness_cm')
        d.etoh = rng.uniform(fc['etoh_low'], fc['etoh_high'])
        d.k_z = rng.normal()
        d.d_w = rng.uniform(p['d_weight_low'], p['d_weight_high'])
        for s in subs:
            c = self.P['contents'][container['content_key']][s]
            d.c_p0[s] = rng.uniform(c['low'], c['high'])
        return d

    # ----------------------------------------------------------- temperature history
    def contact_history(self, product, plan, recipe_steps, watt, draw, fc, eat_in_container, steam=False):
        """Contact temperature at each time step (list of floats, C) plus summary numbers.

        steam=True (steam bags): after steam_onset_fraction of the label energy the film sits in steam at T_boil.
        """
        th = self.thermal(product)
        onset = self.p['steam_onset_fraction']
        dt = self.p['dt_s']
        t_target = self.p['T_target_avg_C']
        h_target = th.h(t_target)
        e_recipe = watt * sum(s['time_s'] for s in recipe_steps if s['kind'] == 'cook')
        if e_recipe <= 0:  # no label recipe: treat the user's plan as the recipe
            e_recipe = watt * sum(s['time_s'] for s in plan if s['kind'] == 'cook')
        k = h_target / e_recipe if e_recipe > 0 else 0.0
        h = 0.0
        temps = []
        t_avg = th.t0
        for s in plan:
            n = int(math.floor(s['time_s'] / dt + 0.5))  # same rule as Dart (round half up)
            if s['kind'] == 'cook':
                for _ in range(n):
                    h += k * watt * draw.p_factor * dt
                    t_avg = th.temp(h)
                    edge = draw.edge * min(1.0, h / h_target)
                    tc = min(draw.cap, t_avg + edge)
                    if steam and h / h_target >= onset:
                        tc = max(tc, th.t_boil)
                    temps.append(tc)
            elif s['kind'] == 'stand':
                for _ in range(n):
                    temps.append(t_avg)
        t_end = t_avg
        if eat_in_container:
            n = int(math.floor(self.p['eat_minutes'] * 60.0 / dt + 0.5))
            t_stop = min(t_end, self.p['eat_end_C'])
            for i in range(1, n + 1):
                temps.append(t_end + (t_stop - t_end) * i / n)
        e_plan = watt * sum(s['time_s'] for s in plan if s['kind'] == 'cook')
        return temps, dict(t_end_avg=t_end, t_contact_max=max(temps) if temps else th.t0, energy_ratio=(e_plan / e_recipe) if e_recipe else None)

    def d_of(self, sub, container, t_c, d_w=None):
        """Diffusion coefficient (cm2/s) at t_c. Organic migrants: log-scale mix of the Huang 2017
        QPPR (d_w = 0) and the Piringer upper bound (d_w = 1). Antimony: Arrhenius fit."""
        s = self.P['substances'][sub]
        if s['model'] == 'arrhenius':
            return d_arrhenius(s['d0'], s['ea_kj'], t_c, self.p['R_gas'])
        w = self.p['d_weight_central'] if d_w is None else d_w
        (ap, bp), (ah, bh) = ln_d_coefficients(self.P['polymers'][container['polymer']], self.P['huang2017'], s['mw'])
        tk = t_c + 273.15
        return math.exp((1.0 - w) * (ah + bh / tk) + w * (ap + bp / tk))

    def log_kpf(self, sub, container, etoh, t_eff_c, k_z):
        """log10 Kpf (polymer / food) from the Huang and Jolliet 2019 regression [S76].
        log Kow is capped at the highest value measured for the food's EtOH-eq band.
        Returns (log10 K, log Kow used). Migrants without log Kow (antimony) use K = 1."""
        sp = self.P['substances'][sub]
        if sp['log_kow'] is None:
            return 0.0, None
        kp = self.P['kpf']
        c = kp['coefficients']
        dom = kp['domain']
        cap = dom[-1]['logkow_max']
        for band in dom:
            if band['etoh_low'] <= etoh < band['etoh_high']:
                cap = band['logkow_max']
                break
        x = min(sp['log_kow'], cap)
        mat = self.P['polymers'][container['polymer']]['kpf_material']
        invt = 1.0 / (t_eff_c + 273.15) - 1.0 / self.p['kpf_t_ref_K']
        lk = (c['b0'] + c['b_kow'] * x + c['b_etoh'] * etoh + c['b_kow_etoh'] * x * etoh + c['b_invt'] * invt
              + kp['material_offsets'][mat] + k_z * self.p['kpf_resid_sd'])
        return lk, x

    # ----------------------------------------------------------- one pass
    def migrate(self, product, container, temps, draw, subs, mass_g):
        dt = self.p['dt_s']
        area = container['area_ref_cm2'] * (mass_g / self.p['area_ref_mass_g']) ** (2.0 / 3.0) * draw.area_f
        d = draw.thickness
        v_p = area * d
        m_p = container['density'] * v_p
        v_f = mass_g / self.p['food_density']
        out = {}
        for s in subs:
            sp = self.P['substances'][s]
            theta = 0.0
            dt_sum = 0.0
            if sp['model'] == 'arrhenius':
                for t in temps:
                    dd = d_arrhenius(sp['d0'], sp['ea_kj'], t, self.p['R_gas']) * dt
                    theta += dd
                    dt_sum += dd * t
            else:
                (ap, bp), (ah, bh) = ln_d_coefficients(self.P['polymers'][container['polymer']], self.P['huang2017'], sp['mw'])
                w = draw.d_w
                a_mix = (1.0 - w) * ah + w * ap
                b_mix = (1.0 - w) * bh + w * bp
                for t in temps:
                    dd = math.exp(a_mix + b_mix / (t + 273.15)) * dt
                    theta += dd
                    dt_sum += dd * t
            # partition coefficient at the diffusion-weighted contact temperature
            t_eff = dt_sum / theta if theta > 0 else (temps[-1] if temps else 25.0)
            lk, kow_used = self.log_kpf(s, container, draw.etoh, t_eff, draw.k_z)
            K = 10.0 ** lk
            alpha = v_f / (K * v_p)
            c_eff = draw.c_p0[s] * sp['diffusible']
            m_eq = c_eff * m_p * alpha / (1.0 + alpha)
            fo = theta / (d * d)
            f = crank_fraction(fo, alpha, self.p['short_time_Fo'])
            out[s] = dict(ug=m_eq * f, fraction=f, fo=fo, alpha=alpha, K=K, log_k=lk, theta=theta, t_eff=t_eff,
                          kow_capped=kow_used is not None and kow_used < sp['log_kow'])
        return out

    def exposure(self, migrated, portion, bw):
        res = {}
        for s, m in migrated.items():
            sp = self.P['substances'][s]
            g = sp['group']
            res.setdefault(g, 0.0)
            res[g] += m['ug'] * portion * sp['rpf']
        return {g: v / (bw * self.P['groups'][g]['tdi']) * 100.0 for g, v in res.items()}

    def band(self, pct):
        if pct is None:
            return None
        if pct < self.p['band_low_pct']:
            return 'lower'
        if pct < self.p['band_high_pct']:
            return 'middle'
        return 'higher'

    # ----------------------------------------------------------- public
    def plan_for(self, sc: Scenario, recipe_steps):
        if sc.plan is not None:
            plan = [dict(x) for x in sc.plan]
        else:
            plan = [dict(kind=s['kind'], time_s=s['time_s']) for s in recipe_steps if s['kind'] in ('cook', 'stand')]
        if sc.extra_cook_s:
            idx = max((i for i, s in enumerate(plan) if s['kind'] == 'cook'), default=None)
            if idx is not None:
                plan[idx]['time_s'] += sc.extra_cook_s
        return plan

    def evaluate(self, sc: Scenario, mc: bool = True):
        product = self.products[sc.product_id]
        ckey = sc.container_key or product['container_key']
        if sc.method == 'stove':
            ckey = 'stove_pot'
        container = self.P['containers'][ckey]
        recipe_steps, flags = resolve_recipe(product, sc.watt)
        result = dict(product_id=sc.product_id, container=ckey, status=container['status'], flags=list(flags), recipe=recipe_steps,
                      groups={}, headline_pct=None, band=None, range=None, substances={}, temperature=None)
        if product['recipe']['oven_only'] and sc.method == 'microwave':
            result['status'] = 'label_no_microwave' if product['recipe']['do_not_microwave'] == 'yes' else 'oven_only'
            return result
        if container['status'] == 'measured':
            return self.measured(product, ckey, sc, result)
        if container['status'] != 'ok':
            if container['status'] == 'inert':
                result['headline_pct'] = 0.0
                result['band'] = 'lower'
            return result
        plan = self.plan_for(sc, recipe_steps)
        fc = self.food_class(product['fat_class'])
        subs = self.substances_for(container)
        mass = product['food_mass_g']
        portion = sc.portion if sc.portion is not None else 1.0 / (product.get('servings') or 1.0)

        draw = self.central_draw(container, fc, subs)
        steam = container.get('contact_mode') == 'steam'
        temps, tinfo = self.contact_history(product, plan, recipe_steps, sc.watt, draw, fc, sc.eat_in_container, steam)
        mig = self.migrate(product, container, temps, draw, subs, mass)
        groups = self.exposure(mig, portion, sc.body_weight_kg)
        result['temperature'] = tinfo
        result['substances'] = mig
        result['groups'] = groups
        result['headline_pct'] = max(groups.values()) if groups else 0.0
        result['headline_group'] = max(groups, key=groups.get) if groups else None
        result['band'] = self.band(result['headline_pct'])
        label_plan = [dict(kind=s['kind'], time_s=s['time_s']) for s in recipe_steps if s['kind'] in ('cook', 'stand')]
        if label_plan and (plan != label_plan or not sc.eat_in_container):
            lt, _ = self.contact_history(product, label_plan, recipe_steps, sc.watt, draw, fc, True, steam)
            lg = self.exposure(self.migrate(product, container, lt, draw, subs, mass), portion, sc.body_weight_kg)
            base = max(lg.values()) if lg else 0.0
            result['vs_label'] = result['headline_pct'] / base if base > 0 else None
        else:
            result['vs_label'] = 1.0

        # flags
        if tinfo['energy_ratio'] is not None and tinfo['energy_ratio'] < self.p['energy_short_ratio']:
            result['flags'].append('below_recipe_energy')
        if container.get('max_use_c') and tinfo['t_contact_max'] > container['max_use_c']:
            result['flags'].append('above_container_max_use')
        pol = self.P['polymers'].get(container.get('polymer') or '', None)
        if pol and any(self.P['substances'][s]['model'] == 'piringer' for s in subs) and tinfo['t_contact_max'] > pol['t_max_valid_c']:
            result['flags'].append('outside_model_validity')
        if any(self.P['substances'][s]['model'] == 'arrhenius' for s in subs):
            result['flags'].append('arrhenius_extrapolated')
        if not product.get('fat_known', True):
            result['flags'].append('fat_unknown')
        if any(m.get('kow_capped') for m in mig.values()):
            result['flags'].append('kow_capped_to_data')

        if mc:
            rng = Rng(int(self.p['mc_seed']))
            vals = []
            for _ in range(int(self.p['mc_samples'])):
                dr = self.random_draw(rng, container, fc, subs)
                tt, _ = self.contact_history(product, plan, recipe_steps, sc.watt, dr, fc, sc.eat_in_container, steam)
                g = self.exposure(self.migrate(product, container, tt, dr, subs, mass), portion, sc.body_weight_kg)
                vals.append(max(g.values()) if g else 0.0)
            vals.sort()
            result['range'] = dict(p05=percentile(vals, 0.05), p50=percentile(vals, 0.50), p95=percentile(vals, 0.95))
        return result


def _measured(self, product, ckey, sc, result):
    """Estimate from measured migration (container status 'measured').

    intake = value x food mass (per_kg_food) or value (per_item), times the eaten share.
    The range is the low and high of the measurements, not a Monte Carlo result.
    """
    recs = self.P['measured'].get(ckey, [])
    portion = sc.portion if sc.portion is not None else 1.0 / (product.get('servings') or 1.0)
    mass_kg = product['food_mass_g'] / 1000.0
    lo, mid, hi = {}, {}, {}
    for r in recs:
        f = (mass_kg if r['basis'] == 'per_kg_food' else 1.0) * portion
        g = r['group']
        for store, v in ((lo, r['low']), (mid, r['mid']), (hi, r['high'])):
            store[g] = store.get(g, 0.0) + v * f
    tdi = {g: sc.body_weight_kg * self.P['groups'][g]['tdi'] for g in mid}
    groups = {g: mid[g] / tdi[g] * 100.0 for g in mid}
    result['groups'] = groups
    if groups:
        hg = max(groups, key=groups.get)
        result['headline_group'] = hg
        result['headline_pct'] = groups[hg]
        result['band'] = self.band(groups[hg])
        result['range'] = dict(p05=lo[hg] / tdi[hg] * 100.0, p50=groups[hg], p95=hi[hg] / tdi[hg] * 100.0)
    result['flags'].append('measurement_based')
    result['vs_label'] = None
    return result


Engine.measured = _measured


def percentile(sorted_vals, q):
    n = len(sorted_vals)
    if n == 0:
        return None
    pos = q * (n - 1)
    lo = int(math.floor(pos))
    hi = min(lo + 1, n - 1)
    return sorted_vals[lo] + (sorted_vals[hi] - sorted_vals[lo]) * (pos - lo)


if __name__ == '__main__':
    P, PR = load_assets()
    eng = Engine(P, PR)
    for pid in ('zw-001', 'zw-007', 'zw-015', 'zw-013', 'zw-023', 'zw-016', 'zw-031'):
        r = eng.evaluate(Scenario(pid, watt=1100))
        rng = r['range']
        print(pid, PR[pid]['name'][:34].ljust(34), r['container'].ljust(15), r['status'].ljust(9),
              'pct=%s' % (None if r['headline_pct'] is None else '%.4f' % r['headline_pct']), r['band'],
              '' if not rng else 'p05 %.4f p50 %.4f p95 %.4f' % (rng['p05'], rng['p50'], rng['p95']),
              (r['temperature'] or {}).get('t_contact_max'), r['flags'])
