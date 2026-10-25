"""Polymer-food partition coefficient (log Kpf) model for the ZapWise engine.

Data (ml/data/kpf/)
  huang_jolliet_2019_kpf_dataset.csv    1,881 measured log Kpf / log Kmw values used by Huang and
                                        Jolliet 2019 (column 'Included in study' = 1), with their
                                        study-wise train/test split ('Split by studies': 1 train, 2 test).
  huang_jolliet_2019_kpf_calculator.csv the published regression coefficients (material-specific and generic).
  vaferi_2025_table_s1.csv              the same databank (1,847 rows) as printed in Vaferi et al. 2025
                                        Table S1, with their gradient boosting predictions.

Models compared
  published  Huang and Jolliet 2019 coefficients as published (no fitting here)
  mlr        same equation refitted on the study-wise training split
             log K = b0 + b1 logKow + b2 EtOH + b3 logKow*EtOH + b4 (1/T - 1/298.15) + material offset
  gbr        gradient boosting (HistGradientBoostingRegressor) with monotone constraints
             (+ logKow, - EtOH, + 1/T), same inputs, same split
  vaferi     the GBR predictions printed by Vaferi 2025 (their split was random rows, so most of their
             values are in-sample; listed for reference only)

Validation
  1. study-wise split from the dataset (whole studies held out)
  2. GroupKFold by chemical (CAS), 5 folds: a chemical never appears in both train and test

Output (out/kpf/)
  kpf_model.json   coefficients the app uses, residual SD, applicability domain
  metrics.json     all scores
  fig_kpf_parity.png, fig_kpf_residuals.png

Run: python train_kpf.py
"""
import json
import os

import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingRegressor
from sklearn.model_selection import GroupKFold

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'data', 'kpf')
OUT = os.path.join(HERE, 'out', 'kpf')
T_REF = 298.15

# dataset material label -> label used in the published coefficient sheet
PUBLISHED_NAME = {
    'LDPE': 'Low-density polyethylene (LDPE)',
    'HDPE': 'High-density polyethylene (HDPE)',
    'LLDPE': 'Linear low-density polyethylene (LLDPE)',
    'PP homopolymer': 'Polypropylene (PP) homopolymer',
    'PET': 'Polyethylene terephthalate (PET)',
    'PVC': 'Polyvinyl chloride (PVC)',
}


def load():
    df = pd.read_csv(os.path.join(DATA, 'huang_jolliet_2019_kpf_dataset.csv'), encoding='utf-8-sig')
    df = df.loc[:, ~df.columns.str.startswith('Unnamed')]
    df.columns = ['id', 'chem', 'cas', 'mat0', 'food', 'etoh', 'mat', 'matn', 'y', 'logkow', 'temp_c', 'ref', 'inc', 's_study', 's_20', 's_resp',
                  's_struct', 's_ozaki']
    df = df[df.inc == 1].copy()
    df['etoh'] = pd.to_numeric(df.etoh, errors='coerce')
    df = df.dropna(subset=['etoh', 'y', 'logkow', 'temp_c'])
    df['temp_k'] = df.temp_c + 273.15
    df['invt'] = 1.0 / df.temp_k - 1.0 / T_REF
    df['cas'] = df.cas.fillna(df.chem.fillna('unknown'))
    df['mat'] = df.mat.replace(PUBLISHED_NAME)
    return df.reset_index(drop=True)


def load_published():
    """Material-specific and generic coefficients from the published calculator sheet."""
    raw = pd.read_csv(os.path.join(DATA, 'huang_jolliet_2019_kpf_calculator.csv'), header=None, encoding='utf-8-sig')
    cells = raw.iloc[:, 6:8].values.tolist()
    spec, generic, mats, where = {}, {}, {}, None
    for name, val in cells:
        if not isinstance(name, str):
            continue
        name = name.strip()
        if name == 'Material specific':
            where = 'spec'
            continue
        if name == 'Material':
            where = 'mat'
            continue
        if name == 'Generic':
            where = 'generic'
            continue
        try:
            v = float(val)
        except (TypeError, ValueError):
            continue
        if where == 'spec':
            spec[name] = v
        elif where == 'mat':
            mats[name] = v
        elif where == 'generic':
            generic[name] = v
    key = {'Intercept': 'b0', 'logKow': 'b_kow', 'EtOH-eq': 'b_etoh', 'logKow*EtOH-eq': 'b_kow_etoh', '(1/T-1/298.15)': 'b_invt'}
    return ({key[k]: v for k, v in spec.items()}, mats, {key[k]: v for k, v in generic.items()})


def design(df, materials):
    cols = [np.ones(len(df)), df.logkow.values, df.etoh.values, (df.logkow * df.etoh).values, df.invt.values]
    for mname in materials:
        cols.append((df.mat == mname).astype(float).values)
    return np.column_stack(cols)


def fit_mlr(df, ref_material):
    """Least squares with one material as reference (offset 0); offsets are then shifted so the
    reference matches the published convention (LDPE = 0)."""
    mats = sorted(m for m in df.mat.unique() if m != ref_material)
    X = design(df, mats)
    beta, *_ = np.linalg.lstsq(X, df.y.values, rcond=None)
    coef = dict(b0=beta[0], b_kow=beta[1], b_etoh=beta[2], b_kow_etoh=beta[3], b_invt=beta[4])
    offsets = {ref_material: 0.0}
    for i, mname in enumerate(mats):
        offsets[mname] = beta[5 + i]
    return coef, offsets


def predict_mlr(df, coef, offsets, default_offset=None):
    off = df.mat.map(offsets)
    if default_offset is not None:
        off = off.fillna(default_offset)
    return (coef['b0'] + coef['b_kow'] * df.logkow + coef['b_etoh'] * df.etoh + coef['b_kow_etoh'] * df.logkow * df.etoh + coef['b_invt'] * df.invt +
            off).values


def gbr_features(df, materials):
    X = np.column_stack([df.logkow.values, df.etoh.values, df.invt.values] + [(df.mat == mname).astype(float).values for mname in materials])
    mono = [1, -1, 1] + [0] * len(materials)
    return X, mono


def fit_gbr(df, materials, seed=7):
    X, mono = gbr_features(df, materials)
    model = HistGradientBoostingRegressor(max_iter=400, learning_rate=0.05, max_depth=4, min_samples_leaf=10, l2_regularization=1.0,
                                          monotonic_cst=mono, random_state=seed)
    model.fit(X, df.y.values)
    return model


def scores(y, p):
    r = y - p
    ss_res = float(np.sum(r ** 2))
    ss_tot = float(np.sum((y - y.mean()) ** 2))
    return dict(n=int(len(y)), rmse=float(np.sqrt(np.mean(r ** 2))), mae=float(np.mean(np.abs(r))), r2=1.0 - ss_res / ss_tot if ss_tot > 0 else float('nan'),
                bias=float(np.mean(r)))


def domain(df):
    """Highest measured log Kow per EtOH-eq band (the regression is not checked beyond these)."""
    bands = [(0, 20), (20, 60), (60, 90), (90, 101)]
    out = []
    for lo, hi in bands:
        s = df[(df.etoh >= lo) & (df.etoh < hi)]
        out.append(dict(etoh_low=lo, etoh_high=min(hi, 100), logkow_max=float(s.logkow.max()), logkow_min=float(s.logkow.min()), n=int(len(s))))
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    df = load()
    spec, mats_pub, generic = load_published()
    materials = sorted(df.mat.unique())
    print(f'{len(df)} rows, {df.cas.nunique()} chemicals, {len(materials)} materials, T {df.temp_c.min():.0f}-{df.temp_c.max():.0f} C')

    train = df[df.s_study == 1]
    test = df[df.s_study == 2]
    metrics = {'data': dict(rows=int(len(df)), chemicals=int(df.cas.nunique()), materials=len(materials), train=int(len(train)), test=int(len(test)),
                            temp_c=[float(df.temp_c.min()), float(df.temp_c.max())], etoh=[float(df.etoh.min()), float(df.etoh.max())],
                            logkow=[float(df.logkow.min()), float(df.logkow.max())])}

    # 1. published coefficients
    pub_all = predict_mlr(df, spec, mats_pub)
    pub_test = predict_mlr(test, spec, mats_pub)
    metrics['published'] = dict(all=scores(df.y.values, pub_all), study_test=scores(test.y.values, pub_test))

    # 2. refit on the study-wise training split
    coef, offsets = fit_mlr(train, 'Low-density polyethylene (LDPE)' if 'Low-density polyethylene (LDPE)' in materials else 'LDPE')
    p_test = predict_mlr(test, coef, offsets, default_offset=0.0)
    metrics['mlr_refit'] = dict(coef=coef, study_test=scores(test.y.values, p_test))

    # 3. monotone gradient boosting, same split
    gbr = fit_gbr(train, materials)
    Xt, _ = gbr_features(test, materials)
    g_test = gbr.predict(Xt)
    metrics['gbr'] = dict(study_test=scores(test.y.values, g_test))

    # 4. GroupKFold by chemical, all three
    gkf = GroupKFold(n_splits=5)
    res = {'published': [], 'mlr': [], 'gbr': []}
    ys = []
    for tr, te in gkf.split(df, groups=df.cas):
        a, b = df.iloc[tr], df.iloc[te]
        c2, o2 = fit_mlr(a, 'Low-density polyethylene (LDPE)')
        res['mlr'].append(predict_mlr(b, c2, o2, default_offset=0.0))
        res['published'].append(predict_mlr(b, spec, mats_pub))
        g2 = fit_gbr(a, materials)
        res['gbr'].append(g2.predict(gbr_features(b, materials)[0]))
        ys.append(b.y.values)
    y_cv = np.concatenate(ys)
    metrics['chemical_cv'] = {k: scores(y_cv, np.concatenate(v)) for k, v in res.items() if k != 'published'}

    # 5. Vaferi 2025 GBR (their own split; reference only)
    vf = pd.read_csv(os.path.join(DATA, 'vaferi_2025_table_s1.csv'))
    metrics['vaferi_2025_gbr_printed'] = scores(vf.logk.values, vf.gbr_pred.values)

    # final model for the app: published coefficients (reproduced by the refit, see metrics)
    resid_sd = metrics['chemical_cv']['mlr']['rmse']
    pp = df[df.mat.isin(['Polypropylene (PP) homopolymer', 'Ethylene-propylene copolymer'])]
    pp_scores = scores(pp.y.values, predict_mlr(pp, spec, mats_pub))
    metrics['published_pp_rows'] = pp_scores
    model = dict(
        name='Huang and Jolliet 2019 material-specific regression',
        equation='log10 Kpf = b0 + b_kow*logKow + b_etoh*EtOH + b_kow_etoh*logKow*EtOH + b_invt*(1/T - 1/298.15) + material offset',
        units='Kpf = concentration in polymer / concentration in food (volume basis); EtOH in % v/v; T in K',
        coefficients=spec,
        material_offsets=mats_pub,
        generic=generic,
        residual_sd_log10=resid_sd,
        residual_sd_note='RMSE of the refitted regression when each chemical is held out (GroupKFold by CAS); whole-study hold-out gives ' + f"{metrics['mlr_refit']['study_test']['rmse']:.2f}",
        domain=domain(df),
        temp_c_range=metrics['data']['temp_c'],
        sources='Huang and Jolliet 2019 (dataset and coefficients); Vaferi et al. 2025 Table S1 (same databank)',
    )
    with open(os.path.join(OUT, 'kpf_model.json'), 'w') as f:
        json.dump(model, f, indent=1)
    with open(os.path.join(OUT, 'metrics.json'), 'w') as f:
        json.dump(metrics, f, indent=1, default=float)

    # figures
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(1, 3, figsize=(13, 4.3), sharex=True, sharey=True)
    for a, (label, pred) in zip(ax, [('Published regression (fitted to all rows)', np.concatenate(res['published'])), ('Refitted regression (chemical held out)', np.concatenate(res['mlr'])),
                                     ('Monotone gradient boosting (chemical held out)', np.concatenate(res['gbr']))]):
        s = scores(y_cv, pred)
        a.scatter(y_cv, pred, s=6, alpha=0.35, color='#B23A57')
        a.plot([-5, 6], [-5, 6], color='#4B2E39', lw=1)
        a.set_title(f'{label}\nRMSE {s["rmse"]:.2f}, R2 {s["r2"]:.2f}', fontsize=10)
        a.set_xlabel('measured log Kpf')
    ax[0].set_ylabel('predicted log Kpf')
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, 'fig_kpf_parity.png'), dpi=150)
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8, 4.5))
    pub_res = df.y.values - pub_all
    order = df.assign(r=pub_res).groupby('mat').r.agg(['mean', 'std', 'count']).sort_values('count', ascending=False)
    ax.bar(range(len(order)), order['mean'], yerr=order['std'], color='#F59BAA', edgecolor='#4B2E39')
    ax.set_xticks(range(len(order)))
    ax.set_xticklabels([f'{m} ({n})' for m, n in zip(order.index, order['count'])], rotation=70, ha='right', fontsize=7)
    ax.axhline(0, color='#4B2E39', lw=1)
    ax.set_ylabel('measured - predicted log Kpf')
    fig.tight_layout()
    fig.savefig(os.path.join(OUT, 'fig_kpf_residuals.png'), dpi=150)
    plt.close(fig)

    for k, v in metrics.items():
        print(k, json.dumps(v, default=float)[:400])


if __name__ == '__main__':
    main()
