"""Build ZapWise_DB.xlsx from curated.py and the research JSON files.

Run:  python build_db.py            -> ZapWise_DB.xlsx (then run recalc, then export_assets.py)

The workbook is the single place to edit numbers. Blue text marks values a person
typed in; black text marks formulas. The Status column is colour coded.
"""
import json
import os
import re
import sys

from openpyxl import Workbook
from openpyxl.comments import Comment
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import curated as C  # noqa: E402

# research/ sits next to db/ in the package (older layout: one level higher)
RESEARCH = next((p for p in (os.path.join(HERE, '..', 'research'), os.path.join(HERE, '..', '..', 'research'))
                 if os.path.isdir(p)), os.path.join(HERE, '..', 'research'))
OUT = os.path.join(HERE, 'ZapWise_DB.xlsx')
VALIDATION_CSV = os.path.join(HERE, '..', 'engine_py', 'out', 'validation.csv')

FONT = 'Arial'
F_IN = Font(name=FONT, size=10, color='0000FF')        # typed input
F_FX = Font(name=FONT, size=10, color='000000')        # formula
F_TX = Font(name=FONT, size=10, color='333333')        # descriptive text
F_HD = Font(name=FONT, size=10, bold=True, color='FFFFFF')
F_TITLE = Font(name=FONT, size=14, bold=True, color='4B2E39')
FILL_HD = PatternFill('solid', fgColor='4B2E39')
STATUS_FILL = {
    'VERIFIED': PatternFill('solid', fgColor='D9F2E6'),
    'SECONDARY': PatternFill('solid', fgColor='E3F1F8'),
    'DERIVED': PatternFill('solid', fgColor='EDE7F6'),
    'ASSUMPTION': PatternFill('solid', fgColor='FFF2B3'),
    'UNVERIFIED': PatternFill('solid', fgColor='FBD5C8'),
}
THIN = Side(style='thin', color='D8CCD6')
BORDER = Border(bottom=THIN)
WRAP = Alignment(wrap_text=True, vertical='top')


def status_fill(s):
    s = (s or '').upper()
    for k in ('UNVERIFIED', 'ASSUMPTION', 'DERIVED', 'SECONDARY', 'VERIFIED'):
        if s.startswith(k):
            return STATUS_FILL[k]
    return None


def write_table(ws, headers, rows, widths=None, name=None, input_cols=(), formula_cols=(), status_col=None, start_row=1):
    """Write a header row and rows. Cells whose value starts with '=' are formulas."""
    for j, h in enumerate(headers, 1):
        c = ws.cell(row=start_row, column=j, value=h)
        c.font, c.fill, c.alignment = F_HD, FILL_HD, Alignment(vertical='center', wrap_text=True)
    for i, r in enumerate(rows, start_row + 1):
        for j, v in enumerate(r, 1):
            c = ws.cell(row=i, column=j, value=v)
            h = headers[j - 1]
            if isinstance(v, str) and v.startswith('='):
                c.font = F_FX
            elif h in input_cols:
                c.font = F_IN
            else:
                c.font = F_TX
            c.alignment = WRAP
            c.border = BORDER
        if status_col is not None:
            sc = ws.cell(row=i, column=headers.index(status_col) + 1)
            f = status_fill(str(sc.value))
            if f:
                sc.fill = f
    ws.freeze_panes = ws.cell(row=start_row + 1, column=2)
    if widths:
        for j, w in enumerate(widths, 1):
            ws.column_dimensions[get_column_letter(j)].width = w
    if name and rows:
        ref = f"A{start_row}:{get_column_letter(len(headers))}{start_row + len(rows)}"
        t = Table(displayName=name, ref=ref)
        t.tableStyleInfo = TableStyleInfo(name='TableStyleLight1', showRowStripes=False)
        ws.add_table(t)
    ws.sheet_view.zoomScale = 100


def parse_serving_g(s):
    if not s:
        return None
    m = re.search(r'\((\d+(?:\.\d+)?)\s*g\)', s)
    return float(m.group(1)) if m else None


def classify_step(action, time_s):
    a = action.lower()
    if time_s is None:
        return 'action'
    # 'let sit' and 'let rest' are how Trader Joe's and Albertsons labels say 'stand' (store photos, 2026-10)
    if 'stand' in a or 'leave in microwave' in a or 'let sit' in a or 'let rest' in a:
        return 'stand'
    if 'oven' in a and 'microwave' not in a:
        return 'oven'
    return 'cook'


def load_products():
    raw = []
    for fname in ('products.json', 'products_batch_a.json', 'products_batch_b.json', 'products_batch_c.json', 'products_field_2026-10.json'):
        path = os.path.join(RESEARCH, fname)
        if os.path.exists(path):
            raw += json.load(open(path))['products']
    out = []
    for p in raw:
        mi = p['microwave_instructions']
        nw = p.get('net_weight') or {}
        n = p.get('nutrition_per_serving') or {}
        ckey, conf, cnote = C.PRODUCT_CONTAINER[p['id']]
        steps = []
        for s in mi['steps']:
            kind = classify_step(s['action'], s['time_s'])
            if p['id'] == 'zw-033' and 'trans' in s['action'].lower():
                kind = 'oven'
            if p['id'] == 'zw-033' and 'check' in s['action'].lower():
                kind = 'stand'
            steps.append(dict(kind=kind, text=s['action'], time_s=s['time_s'], time_s_max=s['time_s_max']))
        table = [dict(watt=v['wattage_w'], time_s=v['time_s'], time_s_max=v.get('time_s_max')) for v in (mi.get('wattage_variants') or [])
                 if v.get('wattage_w') is not None and v.get('time_s') is not None]
        if len({t['watt'] for t in table}) != len(table):
            table = []  # entries by piece count or method (e.g. 1 vs 2 sandwiches), not a wattage table
        # Green Giant lists 1000 W as reference and 700 W as a variant: put the reference into the table too
        if table and mi['reference_wattage_w'] and not any(t['watt'] == mi['reference_wattage_w'] for t in table):
            cook = [s for s in steps if s['kind'] == 'cook' and s['time_s']]
            if cook:
                table.append(dict(watt=mi['reference_wattage_w'], time_s=cook[0]['time_s'], time_s_max=cook[0]['time_s_max']))
        table.sort(key=lambda t: -t['watt'])
        ov, ov_note = C.PRODUCT_OVERRIDES.get(p['id'], ({}, ''))
        servings = ov.get('servings', n.get('servings_per_container'))
        out.append(dict(
            id=p['id'], brand=p['brand'], name=p['product_name'], upc=p.get('upc'), category=p['category'],
            net_oz=ov.get('net_oz', nw.get('oz')), net_g_label=None if 'net_oz' in ov else nw.get('g'),
            servings=servings, serving_size=n.get('serving_size'),
            serving_g=parse_serving_g(n.get('serving_size')), kcal=n.get('calories'), fat_g_serving=n.get('total_fat_g'),
            added_water_g=C.ADDED_WATER_G.get(p['id'], 0.0),
            storage=C.STORAGE_OVERRIDE.get(p['id'], C.PRODUCT_STORAGE[p['category']]),
            container_key=ckey, container_confidence=conf, container_note=cnote,
            ref_watt=mi['reference_wattage_w'], completeness=mi['instructions_completeness'],
            do_not_microwave=mi['do_not_microwave'], low_watt_note=mi.get('low_wattage_note'),
            do_not=' | '.join(mi.get('do_not_statements') or []),
            oven=p.get('oven_instructions') or '',
            steps=steps, table=table,
            container_desc=(p.get('container') or {}).get('description') or '',
            sources=' '.join(p.get('source_urls') or []), flags=' | '.join((p.get('data_flags') or []) + ([ov_note] if ov_note else [])),
        ))
    return out


def build():
    wb = Workbook()
    src_ids = {s[0] for s in C.SOURCES}

    # ------------------------------------------------ README
    ws = wb.active
    ws.title = 'README'
    ws['A1'] = 'ZapWise reference database'
    ws['A1'].font = F_TITLE
    lines = [
        ('Purpose', 'Numbers behind the ZapWise migration estimate. Edit here, then run export_assets.py to refresh the app JSON.'),
        ('Compiled', C.ACCESSED),
        ('Blue text', 'Typed values. Change these when you have a better measurement or source.'),
        ('Black text', 'Formulas. Do not overwrite.'),
        ('Status VERIFIED', 'Number read on the cited page.'),
        ('Status SECONDARY', 'Distributor page, Wikipedia or a similar secondary page.'),
        ('Status DERIVED', 'Computed from verified inputs; the note shows how.'),
        ('Status ASSUMPTION', 'A modelling choice. It must be stated in the report and tested where possible.'),
        ('Status UNVERIFIED', 'Commonly cited but not confirmed on a primary page. Replace before the final submission if you can.'),
        ('Sources', 'The Sources sheet numbers every reference (S01...). Other sheets cite those numbers.'),
        ('Checklist', 'Student_Checklist lists the measurements that would replace the weakest assumptions.'),
        ('Sheets', 'Sources, Polymers, Substances, Groups, Alt_References, Contents, Measured, Containers, FoodClasses, KpfModel, ModelParams, BodyWeights, Products, RecipeSteps, WattTables, Literature, Validation, Models, Student_Checklist'),
    ]
    for i, (k, v) in enumerate(lines, 3):
        ws.cell(row=i, column=1, value=k).font = Font(name=FONT, size=10, bold=True)
        c = ws.cell(row=i, column=2, value=v)
        c.font, c.alignment = F_TX, WRAP
        if k.startswith('Status '):
            ws.cell(row=i, column=1).fill = STATUS_FILL[k.split()[1]]
    ws.column_dimensions['A'].width = 22
    ws.column_dimensions['B'].width = 110

    # ------------------------------------------------ Sources
    ws = wb.create_sheet('Sources')
    write_table(ws, ['ID', 'Citation', 'URL', 'Type', 'Accessed'],
                [(s[0], s[1], s[2], s[3], C.ACCESSED) for s in C.SOURCES],
                widths=[7, 80, 60, 13, 12], name='tSources')

    # ------------------------------------------------ Polymers
    ws = wb.create_sheet('Polymers')
    rows = []
    for r in C.POLYMERS:
        key, name, ap, tau, tmax, rho, rho_st, rho_src, src = r
        hm, hb, htau, kmat = C.POLYMER_MODELS[key]
        rows.append((key, name, ap, tau, tmax, rho, rho_st or '', rho_src, src, 'VERIFIED' if src else '', hm, hb, htau, kmat))
    write_table(ws, ['Key', 'Polymer', "A_P'", 'tau (K)', 'T max valid (C)', 'Density (g/cm3)', 'Density status', 'Density source', 'Piringer source', 'Status',
                     'Huang 2017 material', 'Huang b', 'Huang tau (K)', 'Partition material (Huang and Jolliet 2019)'],
                rows, widths=[12, 32, 8, 9, 13, 13, 14, 12, 14, 12, 30, 9, 11, 34], name='tPolymers',
                input_cols={"A_P'", 'tau (K)', 'T max valid (C)', 'Density (g/cm3)', 'Huang b', 'Huang tau (K)'}, status_col='Status')
    n = len(rows) + 3
    h = C.HUANG2017
    notes = [
        'Two diffusion coefficients per polymer. The engine works between them on a log scale (ModelParams d_weight_*).',
        "Piringer upper bound (cm2/s): D_P = 1e4 * exp(A_P' - tau/T - 0.1351*Mr^(2/3) + 0.003*Mr - 10454/T)   [S01]",
        f"Huang 2017 QPPR, realistic (m2/s): log10 D = {h['intercept']} {h['b_logmw']} log10 MW + b + (tau {h['beta_invt']:+.0f})/T; x 1e4 for cm2/s   [S78]",
        'Example: DEHP (Mr 390.57) in PP at 100 C',
    ]
    for i, t in enumerate(notes):
        ws.cell(row=n + i, column=1, value=t).font = Font(name=FONT, size=10, bold=(i == 0)) if i == 0 else F_TX
    ex = n + len(notes)
    ws.cell(row=ex, column=1, value='Piringer (cm2/s)').font = F_TX
    ws.cell(row=ex, column=6, value='=1E4*EXP(INDEX(C2:C14,MATCH("PP",A2:A14,0))-INDEX(D2:D14,MATCH("PP",A2:A14,0))/373.15-0.1351*390.57^(2/3)+0.003*390.57-10454/373.15)').font = F_FX
    ws.cell(row=ex + 1, column=1, value='Huang 2017 (cm2/s)').font = F_TX
    ws.cell(row=ex + 1, column=6, value=f'=1E4*10^({h["intercept"]}{h["b_logmw"]:+}*LOG10(390.57)+INDEX(L2:L14,MATCH("PP",A2:A14,0))+(INDEX(M2:M14,MATCH("PP",A2:A14,0)){h["beta_invt"]:+.0f})/373.15)').font = F_FX
    ws.cell(row=ex + 2, column=1, value='Piringer / Huang').font = F_TX
    ws.cell(row=ex + 2, column=6, value=f'=F{ex}/F{ex + 1}').font = F_FX
    for r_ in (ex, ex + 1):
        ws.cell(row=r_, column=6).number_format = '0.00E+00'
        ws.cell(row=r_, column=7, value='cm2/s').font = F_TX
    ws.cell(row=ex + 2, column=6).number_format = '0.00'

    # ------------------------------------------------ Substances
    ws = wb.create_sheet('Substances')
    rows = [(s['key'], s['name'], s['cas'], s['mw'], s['log_kow'], s['group'], s['rpf'], s['model'], s['d0'], s['ea'], s['diffusible'],
             s['status'], s['sources'], s['note']) for s in C.SUBSTANCES]
    write_table(ws, ['Key', 'Name', 'CAS', 'MW (g/mol)', 'log Kow', 'Group', 'RPF (DEHP-eq)', 'Diffusion model', 'D0 (cm2/s)', 'Ea (kJ/mol)',
                     'Diffusible fraction', 'Status', 'Sources', 'Note'], rows,
                widths=[7, 30, 12, 10, 8, 18, 10, 12, 11, 10, 11, 26, 10, 60], name='tSubstances',
                input_cols={'MW (g/mol)', 'log Kow', 'RPF (DEHP-eq)', 'D0 (cm2/s)', 'Ea (kJ/mol)', 'Diffusible fraction'}, status_col='Status')
    ws.cell(row=len(rows) + 3, column=1, value='Antimony D(100 C) from Haldimann 2013 Arrhenius fit (cm2/s):').font = Font(name=FONT, size=10, bold=True)
    ws.cell(row=len(rows) + 3, column=9, value='=I6*EXP(-J6*1000/(8.314462618*373.15))').font = F_FX

    # ------------------------------------------------ Groups
    ws = wb.create_sheet('Groups')
    rows = []
    for i, g in enumerate(C.GROUPS, 2):
        rows.append((g['key'], g['label_en'], g['label_ko'], g['tdi'], g['unit'], g['agency'], g['year'], f'=D{i}*70', g['status'], g['sources'], g['basis']))
    write_table(ws, ['Key', 'Label (en)', 'Label (ko)', 'TDI', 'Unit', 'Agency', 'Year', 'Daily allowance, 70 kg adult (ug)', 'Status', 'Sources', 'Basis'],
                rows, widths=[18, 30, 20, 8, 16, 9, 7, 16, 10, 10, 70], name='tGroups', input_cols={'TDI'}, status_col='Status')

    ws = wb.create_sheet('Alt_References')
    rows = [(a['substance'], a['agency'], a['value'], a['unit'], a['year'], a['status'], a['sources']) for a in C.ALT_REFERENCES]
    write_table(ws, ['Substance', 'Agency', 'Value', 'Unit', 'Year', 'Status', 'Sources'], rows,
                widths=[10, 14, 10, 36, 7, 10, 9], name='tAltRefs', input_cols={'Value'}, status_col='Status')

    # ------------------------------------------------ Contents
    ws = wb.create_sheet('Contents')
    rows = []
    for i, r in enumerate(C.CONTENTS, 2):
        rows.append((r[0], r[1], r[2], r[3], f'=(C{i}+D{i})/2', 'uniform', r[4], r[5], r[6]))
    write_table(ws, ['Material', 'Substance', 'Low (mg/kg)', 'High (mg/kg)', 'Central (mg/kg)', 'Distribution', 'Status', 'Sources', 'Note'],
                rows, widths=[11, 10, 11, 11, 12, 11, 26, 10, 80], name='tContents', input_cols={'Low (mg/kg)', 'High (mg/kg)'}, status_col='Status')

    # ------------------------------------------------ Measured migration
    ws = wb.create_sheet('Measured')
    rows = [(m['container'], m['substance'], m['group'], m['low'], m['mid'], m['high'], m['unit'], m['basis'], m['conditions'], m['status'], m['sources'])
            for m in C.MEASURED]
    write_table(ws, ['Container', 'Substance', 'Group', 'Low', 'Middle', 'High', 'Unit', 'Basis', 'Conditions', 'Status', 'Sources'], rows,
                widths=[12, 12, 10, 8, 8, 8, 8, 12, 70, 10, 9], name='tMeasured', input_cols={'Low', 'Middle', 'High'}, status_col='Status')
    ws.cell(row=len(rows) + 3, column=1, value='Used when a container has status measured: intake = value x food mass (per_kg_food) or value (per_item); range = low to high.').font = F_TX

    # ------------------------------------------------ Containers
    ws = wb.create_sheet('Containers')
    rows = []
    for i, c in enumerate(C.CONTAINERS, 2):
        tr = c['thickness_range'] or (None, None)
        rows.append((c['key'], c['label_en'], c['label_ko'], c['status'], c['content_key'], c['polymer'], c['density'], c['thickness_cm'], tr[0], tr[1],
                     c['area_ref_cm2'], c['area_form'], c['max_use_c'], f'=IF(M{i}="","",M{i}*9/5+32)', c['reason_en'], c['reason_ko'], c['sources'], c['notes'],
                     c.get('contact_mode', 'wall')))
    write_table(ws, ['Key', 'Label (en)', 'Label (ko)', 'Status', 'Content key', 'Polymer', 'Density (g/cm3)', 'Thickness (cm)', 'Thickness low', 'Thickness high',
                     'Contact area at 300 g (cm2)', 'Form', 'Max use (C)', 'Max use (F)', 'Reason (en)', 'Reason (ko)', 'Sources', 'Notes', 'Contact mode'], rows,
                widths=[16, 34, 26, 9, 10, 9, 9, 10, 9, 9, 12, 8, 9, 9, 40, 40, 12, 50, 10], name='tContainers',
                input_cols={'Density (g/cm3)', 'Thickness (cm)', 'Thickness low', 'Thickness high', 'Contact area at 300 g (cm2)', 'Max use (C)'})
    st_fill = {'ok': 'D9F2E6', 'measured': 'D9F2E6', 'info': 'EDE7F6', 'inert': 'E3F1F8', 'no_data': 'FFF2B3', 'block': 'FBD5C8'}
    for i in range(2, len(rows) + 2):
        v = ws.cell(row=i, column=4).value
        ws.cell(row=i, column=4).fill = PatternFill('solid', fgColor=st_fill[v])
    ws.cell(row=2, column=8).comment = Comment('0.031 cm measured on one CPET tray by Haldimann 2013 [S02].', 'ZapWise')
    ws.cell(row=3, column=8).comment = Comment('ASSUMPTION. Measure real cups with calipers.', 'ZapWise')
    ws.cell(row=2, column=11).comment = Comment('Geometric estimate: 300 g in a 17 x 12 cm tray is 1.5 cm deep; base 204 + wetted wall 85 = about 290 cm2. ASSUMPTION.', 'ZapWise')
    ws.cell(row=3, column=11).comment = Comment('Between a bowl (about 210 cm2) and a tray (about 290 cm2) for 300 g. ASSUMPTION.', 'ZapWise')

    # ------------------------------------------------ FoodClasses
    ws = wb.create_sheet('FoodClasses')
    rows = [(f['key'], f['fat_min'], f['fat_max'], f['k_rule'], f['etoh_low'], f['etoh_high'], f['cap_low'], f['cap_high'], f['status'], f['sources'], f['note'])
            for f in C.FOOD_CLASSES]
    write_table(ws, ['Class', 'Fat fraction min', 'Fat fraction max', 'Partition rule', 'EtOH-eq low (%)', 'EtOH-eq high (%)',
                     'Contact T cap low (C)', 'Contact T cap high (C)', 'Status', 'Sources', 'Note'], rows,
                widths=[9, 10, 10, 44, 10, 10, 11, 11, 30, 12, 70], name='tFoodClasses',
                input_cols={'Fat fraction min', 'Fat fraction max', 'EtOH-eq low (%)', 'EtOH-eq high (%)', 'Contact T cap low (C)', 'Contact T cap high (C)'}, status_col='Status')
    ws.cell(row=6, column=1, value='EtOH-eq is the ethanol share (v/v) of a water-ethanol mixture that dissolves migrants like the food does. It feeds the partition regression on the KpfModel sheet [S76, S77]. Antimony (inorganic) uses K = 1 [S01].').font = F_TX

    # ------------------------------------------------ KpfModel (ml/train_kpf.py output)
    ws = wb.create_sheet('KpfModel')
    kpath = os.path.join(HERE, '..', 'ml', 'out', 'kpf', 'kpf_model.json')
    km = json.load(open(kpath))
    co = km['coefficients']
    crow = [('b0', co['b0'], 'Intercept'), ('b_kow', co['b_kow'], 'log Kow'), ('b_etoh', co['b_etoh'], 'EtOH-eq (%)'),
            ('b_kow_etoh', co['b_kow_etoh'], 'log Kow x EtOH-eq'), ('b_invt', co['b_invt'], '(1/T - 1/298.15), T in K')]
    write_table(ws, ['Coefficient', 'Value', 'Term'], crow, widths=[34, 12, 60], name='tKpfCoef', input_cols={'Value'})
    r0 = len(crow) + 3
    ws.cell(row=r0, column=1, value='Material offsets (log10 units)').font = Font(name=FONT, size=10, bold=True)
    mats = sorted(km['material_offsets'].items())
    write_table(ws, ['Material', 'Offset'], mats, start_row=r0 + 1, name='tKpfMaterial', input_cols={'Offset'})
    r1 = r0 + len(mats) + 3
    ws.cell(row=r1, column=1, value='Applicability domain: highest measured log Kow per EtOH-eq band (the engine caps log Kow here)').font = Font(name=FONT, size=10, bold=True)
    drows = [(d['etoh_low'], d['etoh_high'], d['logkow_min'], d['logkow_max'], d['n']) for d in km['domain']]
    write_table(ws, ['EtOH-eq from (%)', 'EtOH-eq to (%)', 'log Kow min', 'log Kow max', 'Rows'], drows, start_row=r1 + 1, name='tKpfDomain',
                input_cols={'log Kow max'})
    r2 = r1 + len(drows) + 3
    ws.cell(row=r2, column=1, value='Example: DEHP (log Kow 7.5) in PP homopolymer, lean food (EtOH-eq 35 %), 100 C').font = Font(name=FONT, size=10, bold=True)
    ws.cell(row=r2 + 1, column=1, value='log10 Kpf').font = F_TX
    ws.cell(row=r2 + 1, column=2, value=f'=B2+B3*7.5+B4*35+B5*7.5*35+B6*(1/373.15-1/298.15)+INDEX(B{r0 + 2}:B{r0 + 1 + len(mats)},MATCH("Polypropylene (PP) homopolymer",A{r0 + 2}:A{r0 + 1 + len(mats)},0))').font = F_FX
    ws.cell(row=r2 + 1, column=2).number_format = '0.00'
    ws.cell(row=r2 + 2, column=1, value='Old rule (v0.2) used log10 K = 3 for every lipophilic migrant in lean food.').font = F_TX
    ws.cell(row=r2 + 4, column=1, value=km['equation']).font = F_TX
    ws.cell(row=r2 + 5, column=1, value=km['units']).font = F_TX
    ws.cell(row=r2 + 6, column=1, value=f"Residual SD {km['residual_sd_log10']:.2f} log10 units. {km['residual_sd_note']}. Sources S76, S79.").font = F_TX
    ws.freeze_panes = 'A2'

    # ------------------------------------------------ ModelParams
    ws = wb.create_sheet('ModelParams')
    write_table(ws, ['Key', 'Value', 'Unit', 'Status', 'Sources', 'Note'], [tuple(r) for r in C.MODEL_PARAMS],
                widths=[22, 12, 12, 22, 9, 90], name='tModelParams', input_cols={'Value'}, status_col='Status')

    ws = wb.create_sheet('BodyWeights')
    write_table(ws, ['Group', 'Body weight (kg)', 'Status', 'Sources', 'Note'], [tuple(r) for r in C.BODY_WEIGHTS],
                widths=[14, 14, 12, 9, 70], name='tBodyWeights', input_cols={'Body weight (kg)'}, status_col='Status')

    # ------------------------------------------------ Products
    products = load_products()
    ws = wb.create_sheet('Products')
    rows = []
    for i, p in enumerate(products, 2):
        # fat per package: per serving x servings when servings is a number, else per serving scaled by grams
        rows.append((
            p['id'], p['brand'], p['name'], p['upc'], p['category'], p['net_oz'], p['net_g_label'],
            f'=IF(G{i}<>"",G{i},IF(F{i}<>"",ROUND(F{i}*28.3495,0),""))',
            p['servings'], p['serving_g'], p['fat_g_serving'], p['added_water_g'],
            f'=IF(H{i}="","",H{i}+L{i})',
            f'=IF(OR(K{i}="",M{i}=""),"",IF(J{i}<>"",K{i}/J{i}*H{i}/M{i},IF(I{i}<>"",K{i}*I{i}/M{i},"")))',
            f'=IF(N{i}="","",IF(N{i}<FoodClasses!$C$2,"lean",IF(N{i}<FoodClasses!$C$3,"medium","fatty")))',
            p['storage'], p['container_key'], p['container_confidence'], p['container_note'],
            p['ref_watt'], p['completeness'], 'yes' if p['do_not_microwave'] else ('unknown' if p['do_not_microwave'] is None else 'no'),
            p['low_watt_note'] or '', p['do_not'], p['oven'], p['container_desc'], p['flags'], p['sources']))
    write_table(ws, ['ID', 'Brand', 'Product', 'UPC', 'Category', 'Net (oz)', 'Net (g, label)', 'Net (g)', 'Servings', 'Serving (g)', 'Fat per serving (g)',
                     'Added water (g)', 'Food mass (g)', 'Fat fraction', 'Fat class', 'Storage', 'Container key', 'Container confidence', 'Container note',
                     'Reference watt', 'Instructions', 'Do not microwave', 'Low-watt note', 'Do-not statements', 'Oven directions', 'Container description',
                     'Data flags', 'Source URLs'], rows,
                widths=[8, 16, 40, 15, 11, 8, 9, 8, 8, 9, 9, 9, 9, 9, 8, 8, 15, 11, 40, 9, 11, 9, 30, 30, 30, 30, 40, 50], name='tProducts',
                input_cols={'Net (oz)', 'Net (g, label)', 'Servings', 'Serving (g)', 'Fat per serving (g)', 'Added water (g)', 'Storage', 'Container key',
                            'Container confidence', 'Reference watt'})
    for i in range(2, len(rows) + 2):
        ws.cell(row=i, column=14).number_format = '0.0%'
        if ws.cell(row=i, column=12).value:
            ws.cell(row=i, column=12).fill = STATUS_FILL['ASSUMPTION']
        if ws.cell(row=i, column=18).value != 'label':
            ws.cell(row=i, column=18).fill = STATUS_FILL['ASSUMPTION'] if ws.cell(row=i, column=18).value == 'inferred' else STATUS_FILL['UNVERIFIED']

    ws = wb.create_sheet('RecipeSteps')
    rows = []
    for p in products:
        for k, s in enumerate(p['steps'], 1):
            rows.append((p['id'], k, s['kind'], s['text'], s['time_s'], s['time_s_max']))
    write_table(ws, ['Product ID', 'Step', 'Kind', 'Label text (paraphrased)', 'Time (s)', 'Time max (s)'], rows,
                widths=[10, 6, 8, 60, 9, 11], name='tRecipeSteps', input_cols={'Kind', 'Time (s)', 'Time max (s)'})

    ws = wb.create_sheet('WattTables')
    rows = []
    for p in products:
        for t in p['table']:
            rows.append((p['id'], t['watt'], t['time_s'], t['time_s_max']))
    write_table(ws, ['Product ID', 'Watt', 'Time (s)', 'Time max (s)'], rows, widths=[10, 8, 9, 11], name='tWattTables',
                input_cols={'Watt', 'Time (s)', 'Time max (s)'})

    # ------------------------------------------------ Literature
    sub = json.load(open(os.path.join(RESEARCH, 'substances.json')))
    ws = wb.create_sheet('Literature')
    rows = [(m['container'], m['material'], m['food_or_simulant'], m['heating'], m['substance'], str(m['measured_value']), m['unit'], m['source'])
            for m in sub['microwave_migration_measurements']]
    write_table(ws, ['Container', 'Material', 'Food or simulant', 'Heating', 'Substance', 'Measured', 'Unit', 'Source'], rows,
                widths=[34, 14, 18, 30, 16, 26, 16, 60], name='tLiterature')

    # ------------------------------------------------ Validation (from engine run)
    ws = wb.create_sheet('Validation')
    if os.path.exists(VALIDATION_CSV):
        import csv
        with open(VALIDATION_CSV) as f:
            rd = list(csv.reader(f))
        hdr, body = rd[0], rd[1:]
        conv = []
        for i, r in enumerate(body, 2):
            row = []
            for v in r:
                try:
                    row.append(float(v))
                except ValueError:
                    row.append(v)
            # ratio formula when measured (column D) and predicted (column E) are both numbers
            row.append(f'=IF(AND(ISNUMBER(D{i}),ISNUMBER(E{i})),IF(D{i}<>0,E{i}/D{i},""),"")')
            conv.append(row)
        write_table(ws, hdr + ['Predicted / measured'], conv, widths=[10, 40, 26, 10, 12, 12, 70, 12], name='tValidation')
        for i in range(2, len(conv) + 2):
            ws.cell(row=i, column=len(hdr) + 1).number_format = '0.00'
    else:
        ws['A1'] = 'Run engine_py/validate.py, then build_db.py again to fill this sheet.'

    # ------------------------------------------------ Models (ml/ outputs)
    ws = wb.create_sheet('Models')
    mrows = []
    mpath = os.path.join(HERE, '..', 'ml', 'out', 'trashnet', 'metrics.json')
    rpath = os.path.join(HERE, '..', 'ml', 'out', 'retrieval', 'retrieval.json')
    if os.path.exists(mpath):
        mt = json.load(open(mpath))
        mrows += [
            ('Vision model', 'Backbone', 'MobileNetV2 1.0 224, ImageNet weights, frozen', 'S48'),
            ('Vision model', 'Training data', f"TrashNet, {len(mt['classes'])} classes, {mt['n_train_photos']}/{mt['n_val']}/{mt['n_test']} photos (train/val/test)", 'S47'),
            ('Vision model', 'Head', f"{mt['head']} (validation accuracy linear {mt['val_acc']['linear']:.3f}, mlp {mt['val_acc']['mlp']:.3f})", ''),
            ('Vision model', 'Test accuracy', round(mt['test_acc'], 4), ''),
            ('Vision model', 'Test macro F1', round(mt['test_macro_f1'], 4), ''),
            ('Vision model', 'Per-class F1', ', '.join(f'{k} {v}' for k, v in mt['per_class_f1'].items()), ''),
            ('Vision model', 'TFLite size (MB)', mt['tflite_mb'], ''),
            ('Vision model', 'TFLite vs Keras', f"embedding cosine min {mt['tflite_cosine_min']:.4f}, top-1 agreement {mt['tflite_top1_agreement']}", ''),
            ('Vision model', 'Split', mt['split'], ''),
        ]
    if os.path.exists(rpath):
        rt = json.load(open(rpath))
        mrows += [
            ('Product look-up', 'Top-1 on re-photographed objects', round(rt['top1'], 4), 'S47'),
            ('Product look-up', 'Top-5', round(rt['top5'], 4), ''),
            ('Product look-up', 'Cosine, same object (median / 5th pct)', f"{rt['correct_sim_median']:.3f} / {rt['correct_sim_p05']:.3f}", ''),
            ('Product look-up', 'Cosine, object not in gallery (median / 95th pct)', f"{rt['unknown_best_sim_median']:.3f} / {rt['unknown_best_sim_p95']:.3f}", ''),
            ('Product look-up', 'Accept threshold (95th pct of unknown)', round(rt['threshold_accept'], 4), ''),
            ('Product look-up', 'Share of correct matches above threshold', round(rt['share_of_correct_matches_above_threshold'], 4), ''),
            ('Product look-up', 'Note', rt['note'], ''),
        ]
    kmp = os.path.join(HERE, '..', 'ml', 'out', 'kpf', 'metrics.json')
    if os.path.exists(kmp):
        km2 = json.load(open(kmp))
        d = km2['data']
        f3 = lambda x: f"RMSE {x['rmse']:.2f}, R2 {x['r2']:.3f}, n {x['n']}"  # noqa: E731
        mrows += [
            ('Partition coefficient model', 'Data', f"{d['rows']} measured log Kpf/Kmw, {d['chemicals']} chemicals, {d['materials']} materials, {d['temp_c'][0]:.0f}-{d['temp_c'][1]:.0f} C, EtOH-eq {d['etoh'][0]:.0f}-{d['etoh'][1]:.0f} %", 'S76'),
            ('Partition coefficient model', 'Used in the app', 'Published Huang and Jolliet 2019 material-specific regression (KpfModel sheet)', 'S76'),
            ('Partition coefficient model', 'Published regression, all rows', f3(km2['published']['all']), 'S76'),
            ('Partition coefficient model', 'Refitted regression, whole studies held out', f3(km2['mlr_refit']['study_test']), ''),
            ('Partition coefficient model', 'Monotone gradient boosting, whole studies held out', f3(km2['gbr']['study_test']), ''),
            ('Partition coefficient model', 'Refitted regression, chemicals held out (5-fold)', f3(km2['chemical_cv']['mlr']), ''),
            ('Partition coefficient model', 'Monotone gradient boosting, chemicals held out (5-fold)', f3(km2['chemical_cv']['gbr']), ''),
            ('Partition coefficient model', 'Vaferi 2025 GBR as printed (random split, mostly in-sample)', f3(km2['vaferi_2025_gbr_printed']), 'S79'),
            ('Partition coefficient model', 'PP rows (homopolymer and copolymer), published regression', f3(km2['published_pp_rows']), 'S76'),
            ('Partition coefficient model', 'Why the regression', 'Gradient boosting was only 5 % better on held-out chemicals and equal on held-out studies, and it cannot extrapolate to 100 C or to log Kow above the data. The regression extrapolates in a stated, checkable way.', ''),
        ]
    write_table(ws, ['Model', 'Item', 'Value', 'Sources'], mrows, widths=[24, 44, 80, 10], name='tModels')

    # ------------------------------------------------ Student checklist
    ws = wb.create_sheet('Student_Checklist')
    write_table(ws, ['Task', 'Replaces', 'Why', 'Done (y/n)', 'Result'], [(a, b, c, '', '') for a, b, c in C.STUDENT_CHECKLIST],
                widths=[70, 26, 40, 10, 30], name='tChecklist', input_cols={'Done (y/n)', 'Result'})

    # sanity: every cited source exists
    for wsname in ('Polymers', 'Substances', 'Groups', 'Contents', 'Measured', 'Containers', 'FoodClasses', 'ModelParams', 'BodyWeights', 'Products'):
        w = wb[wsname]
        for row in w.iter_rows(min_row=2, values_only=True):
            for v in row:
                if isinstance(v, str):
                    for m in re.findall(r'\bS\d\d\b', v):
                        assert m in src_ids, (wsname, m)

    wb.save(OUT)
    print('wrote', OUT, 'products', len(products))
    json.dump(products, open(os.path.join(HERE, 'products_normalized.json'), 'w'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    build()
