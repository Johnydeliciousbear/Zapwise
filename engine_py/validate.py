"""Checks of the ZapWise engine against published numbers.

Writes out/validation.csv (read by db/build_db.py into the Validation sheet) and
figures in out/figures/ for the report.

V1  Antimony release from CPET strips in 3 % acetic acid, 24 h at 120/135/150 C [S02]
V2  Arrhenius D(T) from the fitted D0 and Ea against the D values reported at each temperature [S02]
V3  Piringer upper bound against the measured antimony D at 100 C (why antimony gets its own model)
V4  DBP in water heated in PP containers in a 700 W microwave [S05] (order of magnitude only)
V5  Absorption efficiency implied by each complete label recipe (internal consistency of the heating model)
V6  Steam bag film temperature (why steam bags get their own contact mode)
V7  Partition coefficient regression against measured log Kpf (ml/train_kpf.py) [S76]
V8  Realistic (Huang 2017) and upper-bound (Piringer) diffusion coefficients for the PP migrants at 100 C [S78, S01]
"""
import csv
import math
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from zapwise_engine import (Draw, Engine, FoodThermal, Scenario, crank_fraction, d_arrhenius, d_huang2017, d_piringer,  # noqa: E402
                            load_assets, resolve_recipe)

OUT = os.path.join(HERE, 'out')
FIG = os.path.join(OUT, 'figures')
os.makedirs(FIG, exist_ok=True)

P, PR = load_assets()
E = Engine(P, PR)
SB = P['substances']['SB']
rows = []


def add(case, quantity, unit, measured, predicted, note):
    rows.append([case, quantity, unit, '' if measured is None else measured, '' if predicted is None else predicted, note])


# ------------------------------------------------------------------ V1, V2
half = 0.031 / 2.0          # strips immersed: both faces in contact, so each half thickness empties through one face
reported = {120: (6.8, 3.0e-11), 135: (18.6, 2.4e-10), 150: (62.0, 3.3e-9)}
for t_c, (pct, d_rep) in reported.items():
    d_fit = d_arrhenius(SB['d0'], SB['ea_kj'], t_c)
    add('V2', f'D antimony in CPET at {t_c} C', 'cm2/s', d_rep, d_fit, 'Arrhenius fit D0 3.6e14 cm2/s, Ea 188 kJ/mol against the D reported for each temperature [S02].')
    for label, d in (('fitted D', d_fit), ('reported D', d_rep)):
        fo = d * 24 * 3600 / half ** 2
        f = crank_fraction(fo, 1e6)
        add('V1', f'Sb released in 24 h at {t_c} C ({label})', '% of total Sb', pct, round(100 * SB['diffusible'] * f, 2),
            'Strips in 3 % acetic acid, large simulant volume (alpha = 1e6), 62 % of Sb diffusible [S02].')

# ------------------------------------------------------------------ V3
pet = P['polymers']['PET_HI']
d_pir = d_piringer(pet['ap_prime'], pet['tau'], SB['mw'], 100.0)
d_arr = d_arrhenius(SB['d0'], SB['ea_kj'], 100.0)
add('V3', 'D antimony at 100 C, Piringer PET upper bound vs Arrhenius fit', 'cm2/s', d_arr, d_pir,
    f'Piringer is {d_pir / d_arr:.0f} times higher. It is built for organic migrants, so the engine uses the measured Arrhenius fit for antimony.')

# ------------------------------------------------------------------ V4
pp = dict(P['containers']['pp_container'])
water_g = 1080.0                      # 1200 mL container filled to 90 % [S05]
th = FoodThermal(t0=20.0, water=1.0)
eta = 0.9                             # 1 L water absorbs close to the rated power [S42]
temps = []
h = 0.0
for _ in range(7 * 60):
    h += eta * 700.0 / water_g
    temps.append(th.temp(h))
t_end = temps[-1]
for d_cm in (0.06, 0.12):
    for label, c in (('central', 1.415), ('high', 2.83)):
        draw = Draw(p_factor=1.0, edge=0.0, cap=100.0, area_f=1.0, thickness=d_cm, etoh=0.0, k_z=0.0, d_w=P['params']['d_weight_central'], c_p0={'DBP': c})
        mm = E.migrate({}, pp, temps, draw, ['DBP'], water_g)['DBP']
        add('V4', f'DBP in water after 7 min at 700 W, wall {d_cm * 10:.1f} mm, content {label}', 'ug/L', '<0.2 to 2.0',
            round(mm['ug'] / (water_g / 1000.0), 3),
            f"Water ends near {t_end:.0f} C in the model. Partition regression for water (EtOH-eq 0) gives log K {mm['log_k']:.2f}. DBP content of the tested containers was not reported, so the 0-2.83 mg/kg range from S03/S04 is used. Measured range for new containers [S05].")

# ------------------------------------------------------------------ V5
etas = []
for pid, p in PR.items():
    if p['recipe']['completeness'] != 'complete' or p['recipe']['oven_only']:
        continue
    steps, flags = resolve_recipe(p, p['recipe']['ref_watt'])
    t_cook = sum(s['time_s'] for s in steps if s['kind'] == 'cook')
    if t_cook <= 0:
        continue
    thp = E.thermal(p)
    need = thp.h(P['params']['T_target_avg_C']) * p['food_mass_g']
    eta_i = need / (p['recipe']['ref_watt'] * t_cook)
    etas.append((pid, eta_i))
vals = [v for _, v in etas]
add('V5', f'Absorbed fraction of rated power implied by {len(vals)} complete label recipes (median)', '-', 0.6,
    round(statistics.median(vals), 3),
    f'Range {min(vals):.2f}-{max(vals):.2f}. Measured column is the 1 L water reference (about 0.6 in the Panasonic check [S50]; about 1.0 in S42). Small 250-450 g loads couple less than 1 L water [S26], so a value somewhat below 0.6 is expected. A value far outside 0.3-1.0 would mean the heating model disagrees with how labels were written.')

# ------------------------------------------------------------------ V6
# Pliant patent: a vented microwave bag of frozen vegetables reached 95-102 C after 4 min (oven power not stated) [S55]
p = PR['zw-023']
steps, _ = resolve_recipe(p, 1100.0)
fc = E.food_class(p['fat_class'])
cont = P['containers']['steam_bag']
draw = E.central_draw(cont, fc, E.substances_for(cont))
tt_wall, _ = E.contact_history(p, [dict(kind='cook', time_s=240.0)], steps, 1100.0, draw, fc, False, False)
tt, _ = E.contact_history(p, [dict(kind='cook', time_s=240.0)], steps, 1100.0, draw, fc, False, True)
th = E.thermal(p)
k = th.h(P['params']['T_target_avg_C']) / (1100.0 * sum(x['time_s'] for x in steps if x['kind'] == 'cook'))
t_avg_240 = th.temp(k * 1100.0 * 240.0)
add('V6', 'Steam bag film temperature after 4 min (zw-023, 1100 W): generic wall model', 'C', '95 to 102', round(tt_wall[-1], 1),
    f'Patent example, oven power not stated [S55]. The generic model (food average {t_avg_240:.0f} C plus a wall excess) misses the steam that forms inside the bag.')
add('V6', 'Steam bag film temperature after 4 min (zw-023, 1100 W): steam contact mode', 'C', '95 to 102', round(tt[-1], 1),
    'After this check the engine puts the film of steam bags at 100 C once 60 % of the label energy is delivered (steam_onset_fraction).')

# ------------------------------------------------------------------ V7
import json  # noqa: E402
km = json.load(open(os.path.join(HERE, '..', 'ml', 'out', 'kpf', 'metrics.json')))
for label, sc in (('published regression, all 1,881 rows', km['published']['all']), ('refitted regression, whole studies held out', km['mlr_refit']['study_test']),
                  ('refitted regression, chemicals held out', km['chemical_cv']['mlr']), ('published regression, PP rows', km['published_pp_rows'])):
    add('V7', f'log Kpf RMSE, {label}', 'log10 units', '', round(sc['rmse'], 3), f"R2 {sc['r2']:.3f}, n {sc['n']}, mean error {sc['bias']:+.2f}. ml/train_kpf.py [S76].")
lk_dehp_lean, _ = E.log_kpf('DEHP', P['containers']['pp_container'], 35.0, 100.0, 0.0)
lk_dbp_lean, _ = E.log_kpf('DBP', P['containers']['pp_container'], 35.0, 100.0, 0.0)
add('V7', 'log Kpf of DEHP in PP, lean food (EtOH-eq 35 %), 100 C', 'log10', 3.0, round(lk_dehp_lean, 2),
    'Measured column holds the v0.2 rule (JRC default K = 1000 for every lipophilic migrant in watery food). The regression agrees for DEHP.')
add('V7', 'log Kpf of DBP in PP, lean food (EtOH-eq 35 %), 100 C', 'log10', 3.0, round(lk_dbp_lean, 2),
    'For DBP the regression gives a much lower K than the old default, so more DBP is predicted to move into watery food.')

# ------------------------------------------------------------------ V8
h = P['huang2017']
pp_pol = P['polymers']['PP']
for sub in ('DEHP', 'DBP', 'I168'):
    mw = P['substances'][sub]['mw']
    dp = d_piringer(pp_pol['ap_prime'], pp_pol['tau'], mw, 100.0)
    dh = d_huang2017(h['intercept'], h['b_logmw'], h['beta_invt'], pp_pol['huang_b'], pp_pol['huang_tau'], mw, 100.0)
    add('V8', f'D of {sub} in PP at 100 C: Huang 2017 (measured column) vs Piringer upper bound (predicted column)', 'cm2/s', f'{dh:.3g}', f'{dp:.3g}',
        f'Piringer / Huang = {dp / dh:.1f}. The engine uses the log midpoint ({math.sqrt(dp * dh):.3g}) and samples between the two. Huang 2017 SE is 1.17 log units [S78].')

with open(os.path.join(OUT, 'validation.csv'), 'w', newline='') as f:
    w = csv.writer(f)
    w.writerow(['Case', 'Quantity', 'Unit', 'Measured', 'Predicted', 'Note'])
    w.writerows(rows)

# ------------------------------------------------------------------ figures
import matplotlib  # noqa: E402
matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402

plt.rcParams.update({'font.family': 'DejaVu Sans', 'font.size': 10})
COC, ROSE, MINT, BUTTER = '#4B2E39', '#E0607A', '#5FAF95', '#E8B85A'

# figure 1: % TDI vs extra cooking time
fig, ax = plt.subplots(figsize=(6, 3.6), dpi=200)
extras = list(range(0, 301, 30))
for pid, col, lab in (('zw-001', ROSE, 'zw-001 CPET tray, medium fat (antimony)'),
                      ('zw-020', BUTTER, 'zw-020 PP tray, medium fat (phthalates)'),
                      ('zw-007', MINT, 'zw-007 PP tray, lean (phthalates)')):
    ys = [E.evaluate(Scenario(pid, watt=1100, extra_cook_s=x), mc=False)['headline_pct'] for x in extras]
    ax.plot(extras, ys, marker='o', ms=3, color=col, label=lab)
ax.set_xlabel('Extra cooking time beyond the label (s)')
ax.set_ylabel('% of TDI per meal (adult 70 kg)')
ax.legend(frameon=False, fontsize=8)
ax.spines[['top', 'right']].set_visible(False)
fig.tight_layout()
fig.savefig(os.path.join(FIG, 'fig1_extra_time.png'))

# figure 2: temperature history for zw-001
p = PR['zw-001']
steps, _ = resolve_recipe(p, 1100)
plan = [dict(kind=s['kind'], time_s=s['time_s']) for s in steps if s['kind'] in ('cook', 'stand')]
fc = E.food_class(p['fat_class'])
cont = P['containers']['cpet_tray']
draw = E.central_draw(cont, fc, ['SB'])
tt, info = E.contact_history(p, plan, steps, 1100, draw, fc, True)
fig, ax = plt.subplots(figsize=(6, 3.2), dpi=200)
ax.plot([i / 60 for i in range(len(tt))], tt, color=ROSE)
ax.axhline(74, color=COC, lw=0.8, ls='--')
ax.text(0.2, 76, '165 F (74 C)', fontsize=8, color=COC)
ax.set_xlabel('Time (min)')
ax.set_ylabel('Container contact temperature (C)')
ax.spines[['top', 'right']].set_visible(False)
fig.tight_layout()
fig.savefig(os.path.join(FIG, 'fig2_temperature_zw001.png'))

# figure 3: V1 bar chart
fig, ax = plt.subplots(figsize=(5, 3.2), dpi=200)
ts = [120, 135, 150]
meas = [reported[t][0] for t in ts]
pred = [float(r[4]) for r in rows if r[0] == 'V1' and 'fitted' in r[1]]
x = range(3)
ax.bar([i - 0.18 for i in x], meas, width=0.36, color=COC, label='Measured [S02]')
ax.bar([i + 0.18 for i in x], pred, width=0.36, color=ROSE, label='Engine')
ax.set_xticks(list(x), [f'{t} C' for t in ts])
ax.set_ylabel('Sb released in 24 h (% of total)')
ax.legend(frameon=False, fontsize=8)
ax.spines[['top', 'right']].set_visible(False)
fig.tight_layout()
fig.savefig(os.path.join(FIG, 'fig3_sb_validation.png'))

for r in rows:
    print(r[0], '|', r[1], '|', r[3], '|', r[4])
print('etas', [(a, round(b, 2)) for a, b in etas])
