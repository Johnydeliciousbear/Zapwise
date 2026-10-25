"""Export ZapWise_DB.xlsx to the JSON assets the Flutter app and the Python engine read.

Run:  python export_assets.py [path/to/ZapWise_DB.xlsx]
Out:  ../app/assets/data/zapwise_params.json and ../app/assets/data/products.json

Only typed input cells are read. Derived fields (net grams, fat fraction, fat class)
are recomputed here with the same rules as the sheet formulas, and the script checks
that both agree when the workbook has cached formula values.
"""
import datetime
import json
import os
import re
import sys

from openpyxl import load_workbook

HERE = os.path.dirname(os.path.abspath(__file__))
XLSX = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, 'ZapWise_DB.xlsx')
OUT_DIR = os.path.join(HERE, '..', 'app', 'assets', 'data')
VERSION = '0.3.2'

STOP = {'the', 'and', 'with', 'of', 'in', 'a', 'n', 'style', 'flavor', 'original', 'single', 'serve', 'bowl', 'bowls', 'cup', 'cups', '&', 'for'}


def sheet_rows(wb, name):
    ws = wb[name]
    rows = list(ws.iter_rows(values_only=True))
    hdr = rows[0]
    out = []
    for r in rows[1:]:
        if r[0] is None:
            break
        out.append(dict(zip(hdr, r)))
    return out


def num(v):
    if v is None or v == '':
        return None
    return float(v)


def tokens(text):
    t = re.sub(r"[^a-z0-9 ]", ' ', text.lower().replace("'", ''))
    return sorted({w for w in t.split() if len(w) > 1 and w not in STOP})


def kpf_model(wb):
    """Coefficients, material offsets and log Kow domain from the KpfModel sheet (three tables on one sheet)."""
    ws = wb['KpfModel']
    rows = list(ws.iter_rows(values_only=True))
    coef, offsets, domain = {}, {}, []
    mode = 'coef'
    for r in rows[1:]:
        a, b = r[0], r[1]
        if a is None:
            continue
        if a == 'Material':
            mode = 'mat'
            continue
        if a == 'EtOH-eq from (%)':
            mode = 'dom'
            continue
        if isinstance(a, str) and a.startswith(('Material offsets', 'Applicability', 'Example', 'log10 Kpf', 'Old rule', 'log10 Kpf =', 'Kpf =', 'Residual')):
            if a.startswith('Example'):
                mode = None
            continue
        if mode == 'coef' and isinstance(b, (int, float)):
            coef[a] = float(b)
        elif mode == 'mat' and isinstance(b, (int, float)):
            offsets[a] = float(b)
        elif mode == 'dom' and isinstance(a, (int, float)):
            domain.append(dict(etoh_low=float(a), etoh_high=float(r[1]), logkow_max=float(r[3])))
    assert set(coef) == {'b0', 'b_kow', 'b_etoh', 'b_kow_etoh', 'b_invt'}, coef
    assert domain and offsets
    return dict(coefficients=coef, material_offsets=offsets, domain=domain)


def main():
    wb = load_workbook(XLSX)                       # formulas as text
    wbv = load_workbook(XLSX, data_only=True)      # cached values (after recalc)

    params = {r['Key']: r['Value'] for r in sheet_rows(wb, 'ModelParams')}
    food_classes = [dict(key=r['Class'], fat_min=num(r['Fat fraction min']), fat_max=num(r['Fat fraction max']),
                         etoh_low=num(r['EtOH-eq low (%)']), etoh_high=num(r['EtOH-eq high (%)']),
                         cap_low=num(r['Contact T cap low (C)']), cap_high=num(r['Contact T cap high (C)']))
                    for r in sheet_rows(wb, 'FoodClasses')]

    def fat_class(f):
        if f is None:
            return None
        for fc in food_classes:
            if f < fc['fat_max'] or fc is food_classes[-1]:
                return fc['key']

    polymers = {r['Key']: dict(name=r['Polymer'], ap_prime=num(r["A_P'"]), tau=num(r['tau (K)']), t_max_valid_c=num(r['T max valid (C)']),
                               density=num(r['Density (g/cm3)']), huang_material=r['Huang 2017 material'], huang_b=num(r['Huang b']),
                               huang_tau=num(r['Huang tau (K)']), kpf_material=r['Partition material (Huang and Jolliet 2019)'])
                for r in sheet_rows(wb, 'Polymers')}
    kpf = kpf_model(wb)
    substances = {r['Key']: dict(name=r['Name'], cas=r['CAS'], mw=num(r['MW (g/mol)']), log_kow=num(r['log Kow']), group=r['Group'],
                                 rpf=num(r['RPF (DEHP-eq)']), model=r['Diffusion model'], d0=num(r['D0 (cm2/s)']), ea_kj=num(r['Ea (kJ/mol)']),
                                 diffusible=num(r['Diffusible fraction']), sources=r['Sources']) for r in sheet_rows(wb, 'Substances')}
    groups = {r['Key']: dict(label_en=r['Label (en)'], tdi=num(r['TDI']), unit=r['Unit'], agency=r['Agency'],
                             year=r['Year'], sources=r['Sources'], basis=r['Basis']) for r in sheet_rows(wb, 'Groups')}
    alt_refs = [dict(substance=r['Substance'], agency=r['Agency'], value=num(r['Value']), unit=r['Unit'], year=r['Year'], sources=r['Sources'])
                for r in sheet_rows(wb, 'Alt_References')]
    contents = {}
    for r in sheet_rows(wb, 'Contents'):
        contents.setdefault(r['Material'], {})[r['Substance']] = dict(low=num(r['Low (mg/kg)']), high=num(r['High (mg/kg)']), sources=r['Sources'])
    containers = {}
    for r in sheet_rows(wb, 'Containers'):
        containers[r['Key']] = dict(
            label_en=r['Label (en)'], status=r['Status'], content_key=r['Content key'] or None,
            polymer=r['Polymer'] or None, density=num(r['Density (g/cm3)']), thickness_cm=num(r['Thickness (cm)']),
            thickness_low=num(r['Thickness low']), thickness_high=num(r['Thickness high']), area_ref_cm2=num(r['Contact area at 300 g (cm2)']),
            form=r['Form'], max_use_c=num(r['Max use (C)']), reason_en=r['Reason (en)'] or '',
            sources=r['Sources'] or '', contact_mode=r.get('Contact mode') or 'wall')
    measured = {}
    for r in sheet_rows(wb, 'Measured'):
        measured.setdefault(r['Container'], []).append(dict(substance=r['Substance'], group=r['Group'], low=num(r['Low']), mid=num(r['Middle']),
                                                           high=num(r['High']), unit=r['Unit'], basis=r['Basis'], conditions=r['Conditions'],
                                                           sources=r['Sources']))
    body_weights = {r['Group']: num(r['Body weight (kg)']) for r in sheet_rows(wb, 'BodyWeights')}
    sources = {r['ID']: dict(citation=r['Citation'], url=r['URL']) for r in sheet_rows(wb, 'Sources')}

    # ---------------------------------------------------------- products
    steps = {}
    for r in sheet_rows(wb, 'RecipeSteps'):
        steps.setdefault(r['Product ID'], []).append(dict(kind=r['Kind'], text=r['Label text (paraphrased)'],
                                                          time_s=num(r['Time (s)']), time_s_max=num(r['Time max (s)'])))
    tables = {}
    for r in sheet_rows(wb, 'WattTables'):
        tables.setdefault(r['Product ID'], []).append(dict(watt=num(r['Watt']), time_s=num(r['Time (s)']), time_s_max=num(r['Time max (s)'])))
    cached = {r['ID']: r for r in sheet_rows(wbv, 'Products')}
    products = []
    mismatches = 0
    for r in sheet_rows(wb, 'Products'):
        net_g = num(r['Net (g, label)'])
        if net_g is None and r['Net (oz)'] is not None:
            net_g = round(float(r['Net (oz)']) * 28.3495)
        water = num(r['Added water (g)']) or 0.0
        mass = net_g + water if net_g is not None else None
        mass_note = None
        if mass is None:
            sg, sv = num(r['Serving (g)']), num(r['Servings'])
            mass = (sg * sv if sg and sv else 300.0) + water
            mass_note = 'food mass estimated (no net weight)'
        fat_s, serv_g, servings = num(r['Fat per serving (g)']), num(r['Serving (g)']), num(r['Servings'])
        fat = None
        if fat_s is not None and mass:
            if serv_g:
                fat = fat_s / serv_g * net_g / mass
            elif servings:
                fat = fat_s * servings / mass
        fc = fat_class(fat)
        cv = cached.get(r['ID'], {})
        if mass_note is None and cv.get('Fat fraction') not in (None, '') and fat is not None and abs(cv['Fat fraction'] - fat) > 1e-9:
            mismatches += 1
        if cv.get('Fat class') not in (None, '') and cv['Fat class'] != fc:
            mismatches += 1
        note = (r['Low-watt note'] or '')
        m = re.search(r'(?:below|under)\s*(\d{3,4})\s*W', note + ' ' + (r['Do-not statements'] or ''), re.I)
        min_watt = float(m.group(1)) if m else None
        st = [dict(x) for x in steps.get(r['ID'], [])]
        if tables.get(r['ID']):
            # the step that says 'cook for the wattage-specific time' takes its time from the watt table
            for x in st:
                if x['kind'] == 'cook' or (x['kind'] == 'action' and 'cook' in x['text'].lower()):
                    x['kind'] = 'cook_table'
                    break
        oven_only = r['Category'] == 'oven_only' or r['Do not microwave'] == 'yes'
        ref = num(r['Reference watt'])
        products.append(dict(
            id=r['ID'], brand=r['Brand'], name=r['Product'], upc=(str(r['UPC']) if r['UPC'] else None), category=r['Category'],
            net_g=net_g, servings=servings, food_mass_g=mass, fat_fraction=fat, fat_class=fc or 'medium', fat_known=fc is not None,
            storage=r['Storage'], container_key=r['Container key'], container_confidence=r['Container confidence'],
            container_note=r['Container note'],
            recipe=dict(ref_watt=(max(t['watt'] for t in tables[r['ID']]) if tables.get(r['ID']) else (ref or float(params['default_ref_watt']))),
                        ref_watt_assumed=ref is None and not tables.get(r['ID']),
                        steps=st, watt_table=tables.get(r['ID'], []), completeness=r['Instructions'],
                        do_not_microwave=r['Do not microwave'], oven_only=oven_only, min_watt=min_watt,
                        no_reheat_tray='reheat tray' in (r['Do-not statements'] or '').lower() or 'reheat bowl' in (r['Do-not statements'] or '').lower(),
                        oven_text=r['Oven directions'] or ''),
            search_tokens=tokens(f"{r['Brand']} {r['Product']}"),
            flags=[f for f in (r['Data flags'] or '').split(' | ') if f] + ([mass_note] if mass_note else []),
            source_urls=(r['Source URLs'] or '').split(),
        ))
    if mismatches:
        raise SystemExit(f'{mismatches} differences between sheet formulas and export rules')

    os.makedirs(OUT_DIR, exist_ok=True)
    meta = dict(version=VERSION, generated=datetime.date.today().isoformat(), source='ZapWise_DB.xlsx')
    sys.path.insert(0, HERE)
    import curated as C
    huang2017 = {k: v for k, v in C.HUANG2017.items() if k != 'se'}
    json.dump(dict(meta=meta, polymers=polymers, substances=substances, groups=groups, alt_references=alt_refs, contents=contents,
                   containers=containers, measured=measured, food_classes=food_classes, params=params, body_weights=body_weights, sources=sources,
                   kpf=kpf, huang2017=huang2017),
              open(os.path.join(OUT_DIR, 'zapwise_params.json'), 'w'), indent=1, ensure_ascii=False)
    json.dump(dict(meta=meta, products=products), open(os.path.join(OUT_DIR, 'products.json'), 'w'), indent=1, ensure_ascii=False)
    print('exported', len(products), 'products,', len(containers), 'containers ->', os.path.abspath(OUT_DIR))


if __name__ == '__main__':
    main()
