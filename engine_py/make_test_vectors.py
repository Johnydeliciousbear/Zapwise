"""Write app/test/fixtures/engine_vectors.json. The Dart tests in app/test/engine_test.dart
check that the Dart engine reproduces every number here (relative tolerance 1e-6)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from zapwise_engine import (Engine, FoodThermal, Rng, Scenario, crank_fraction, crank_roots, d_arrhenius, d_huang2017, d_piringer,  # noqa: E402
                            erfcx, load_assets, resolve_recipe, table_time)

P, PR = load_assets()
E = Engine(P, PR)
OUT = os.path.join(HERE, '..', 'app', 'test', 'fixtures', 'engine_vectors.json')

v = {}
r = Rng(int(P['params']['mc_seed']))
v['rng'] = dict(seed=int(P['params']['mc_seed']), u32=[r.next_u32() for _ in range(12)])
r = Rng(int(P['params']['mc_seed']))
v['normal'] = [r.normal() for _ in range(8)]
v['erfcx'] = [[z, erfcx(z)] for z in (0.0, 1e-4, 0.01, 0.1, 0.5, 1.0, 2.0, 5.0, 20.0, 1e3)]
pp = P['polymers']['PP']
v['piringer'] = [dict(ap=pp['ap_prime'], tau=pp['tau'], mr=mr, t=t, d=d_piringer(pp['ap_prime'], pp['tau'], mr, t))
                 for mr in (278.3, 390.57) for t in (40.0, 100.0, 121.0)]
h = P['huang2017']
v['huang2017'] = [dict(b=pp['huang_b'], tau=pp['huang_tau'], mw=mw, t=t, d=d_huang2017(h['intercept'], h['b_logmw'], h['beta_invt'], pp['huang_b'], pp['huang_tau'], mw, t))
                  for mw in (278.3, 390.57, 646.94) for t in (40.0, 100.0, 121.0)]
v['d_mix'] = [dict(sub=sub, t=t, w=w, d=E.d_of(sub, P['containers']['pp_container'], t, w)) for sub in ('DEHP', 'I168') for t in (60.0, 100.0) for w in (0.0, 0.5, 1.0)]
v['log_kpf'] = []
for sub in ('DEHP', 'DBP', 'I168', 'SB'):
    for ck in ('pp_container', 'cpet_tray'):
        if sub == 'SB' and ck == 'pp_container':
            continue
        for etoh in (0.0, 35.0, 59.9, 60.0, 90.0, 100.0):
            for t in (25.0, 100.0):
                lk, x = E.log_kpf(sub, P['containers'][ck], etoh, t, 0.5)
                v['log_kpf'].append(dict(sub=sub, container=ck, etoh=etoh, t=t, k_z=0.5, log_k=lk, kow_used=x))
sb = P['substances']['SB']
v['arrhenius'] = [dict(d0=sb['d0'], ea=sb['ea_kj'], t=t, d=d_arrhenius(sb['d0'], sb['ea_kj'], t)) for t in (80.0, 100.0, 120.0, 150.0)]
v['crank_roots'] = [dict(alpha=a, roots=crank_roots(a, 5)) for a in (0.02, 1.0, 30.0)]
v['crank'] = [dict(fo=fo, alpha=a, f=crank_fraction(fo, a)) for fo in (1e-7, 1e-4, 0.01, 0.049, 0.051, 0.2, 1.0) for a in (0.02, 1.0, 30.0, 1e4)]
th = []
for t0 in (-18.0, 20.0):
    ft = FoodThermal(t0=t0)
    for t in (-5.0, 0.0, 50.0, 85.0, 100.0):
        if t0 > t:
            continue
        h = ft.h(t)
        th.append(dict(t0=t0, t=t, h=h, back=ft.temp(h)))
    th.append(dict(t0=t0, t=None, h=ft.h(100.0) + 500.0, back=ft.temp(ft.h(100.0) + 500.0)))
v['thermal'] = th
v['table_time'] = [dict(product=pid, watt=w, t=table_time(PR[pid]['recipe']['watt_table'], w))
                   for pid in ('zw-023', 'zw-028', 'zw-026') for w in (650.0, 800.0, 900.0, 1000.0, 1100.0, 1250.0)]
v['recipes'] = []
for pid in ('zw-001', 'zw-013', 'zw-015', 'zw-023', 'zw-026', 'zw-033', 'zw-012', 'zw-121', 'zw-323', 'zw-201'):
    for w in (700.0, 1100.0):
        steps, flags = resolve_recipe(PR[pid], w)
        v['recipes'].append(dict(product=pid, watt=w, steps=[dict(kind=s['kind'], time_s=s['time_s'], time_lo=s['time_lo'], time_hi=s['time_hi']) for s in steps], flags=flags))

scen = [
    dict(product_id='zw-001'), dict(product_id='zw-001', extra_cook_s=120.0), dict(product_id='zw-001', watt=700.0),
    dict(product_id='zw-007'), dict(product_id='zw-020', eat_in_container=False), dict(product_id='zw-015', body_weight_kg=30.0),
    dict(product_id='zw-005'), dict(product_id='zw-007', container_key='ceramic'), dict(product_id='zw-007', container_key='takeout_tub'),
    dict(product_id='zw-013'), dict(product_id='zw-031'), dict(product_id='zw-016'), dict(product_id='zw-001', method='stove'),
    dict(product_id='zw-020', plan=[dict(kind='cook', time_s=90.0), dict(kind='stand', time_s=30.0), dict(kind='cook', time_s=45.0)]),
    dict(product_id='zw-023'), dict(product_id='zw-301'), dict(product_id='zw-313'), dict(product_id='zw-017', body_weight_kg=30.0),
    dict(product_id='zw-122'), dict(product_id='zw-206'), dict(product_id='zw-304', extra_cook_s=60.0),
]
v['scenarios'] = []
for s in scen:
    kw = dict(s)
    kw.setdefault('watt', 1100.0)
    res = E.evaluate(Scenario(**kw), mc=True)
    v['scenarios'].append(dict(input=kw, status=res['status'], headline_pct=res['headline_pct'], band=res['band'], range=res['range'],
                               groups=res['groups'], flags=res['flags'], vs_label=res.get('vs_label'),
                               t_contact_max=(res['temperature'] or {}).get('t_contact_max'), t_end_avg=(res['temperature'] or {}).get('t_end_avg'),
                               substances={k: dict(ug=m['ug'], fraction=m['fraction'], fo=m['fo'], alpha=m['alpha'], log_k=m['log_k'], t_eff=m['t_eff'])
                                           for k, m in res['substances'].items()}))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump(v, open(OUT, 'w'), indent=1)
print('wrote', OUT, len(v['scenarios']), 'scenarios')
for s in v['scenarios']:
    print(s['input'], s['status'], s['headline_pct'], s['band'], s['range'] and {k: round(x, 4) for k, x in s['range'].items()}, s['flags'])
