"""Train the ZapWise vision model and export it to TFLite.

One model, two outputs:
  embedding   1280 numbers (MobileNetV2 global average pool). Used for product look-up by cosine similarity.
  material    class probabilities from a small head trained on the photos in --data.

Run (baseline on TrashNet, MIT licence):
  python train_vision.py --data /path/to/trashnet/dataset-resized --out out/trashnet --weights mnv2_no_top.h5
Run (student container photos, same folder layout, files named <objectid>_<n>.jpg):
  python train_vision.py --data photos/containers --out out/containers --weights mnv2_no_top.h5

Outputs in --out: zapwise_vision.tflite, labels.json, metrics.json, confusion.png, features cache.
"""
import argparse
import json
import os
import time

os.environ.setdefault('TF_CPP_MIN_LOG_LEVEL', '3')

import keras  # noqa: E402
import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
from PIL import Image, ImageEnhance  # noqa: E402

from common import SIZE, group_split, list_dataset, load_rgb  # noqa: E402

# what each TrashNet class means for the app (the student's own classes map 1:1 to container keys)
TRASHNET_TO_APP = {
    'cardboard': 'paper_family', 'paper': 'paper_family', 'glass': 'glass', 'metal': 'metal',
    'plastic': 'plastic_family', 'trash': 'unknown',
}


def feature_model(weights):
    inp = keras.Input((SIZE, SIZE, 3), name='rgb_0_255')
    x = keras.layers.Rescaling(1 / 127.5, offset=-1.0, name='to_minus1_1')(inp)
    base = keras.applications.MobileNetV2(input_shape=(SIZE, SIZE, 3), include_top=False, weights=weights, pooling='avg')
    base.trainable = False
    emb = base(x)
    return keras.Model(inp, emb, name='embedder'), base


def augment(arr, rng):
    """Photo-like changes: flip, crop 80-100 %, brightness and contrast +/-20 %."""
    im = Image.fromarray(arr.astype(np.uint8))
    if rng.random() < 0.5:
        im = im.transpose(Image.FLIP_LEFT_RIGHT)
    s = rng.uniform(0.8, 1.0)
    w = int(SIZE * s)
    x0, y0 = rng.integers(0, SIZE - w + 1, size=2)
    im = im.crop((x0, y0, x0 + w, y0 + w)).resize((SIZE, SIZE), Image.BOX)
    im = ImageEnhance.Brightness(im).enhance(rng.uniform(0.8, 1.2))
    im = ImageEnhance.Contrast(im).enhance(rng.uniform(0.8, 1.2))
    return np.asarray(im, dtype=np.float32)


def embed_all(model, paths, aug_copies=0, seed=0, batch=32):
    rng = np.random.default_rng(seed)
    feats, idx = [], []
    buf, bidx = [], []
    for i, p in enumerate(paths):
        a = load_rgb(p)
        views = [a] + [augment(a, rng) for _ in range(aug_copies)]
        for v in views:
            buf.append(v)
            bidx.append(i)
            if len(buf) == batch:
                feats.append(model.predict(np.stack(buf), verbose=0))
                idx += bidx
                buf, bidx = [], []
    if buf:
        feats.append(model.predict(np.stack(buf), verbose=0))
        idx += bidx
    return np.concatenate(feats), np.array(idx)


def train_head(xtr, ytr, xva, yva, n_cls, kind, seed=0):
    keras.utils.set_random_seed(seed)
    inp = keras.Input((xtr.shape[1],))
    x = inp
    if kind == 'mlp':
        x = keras.layers.Dense(256, activation='relu', kernel_regularizer=keras.regularizers.l2(1e-4))(x)
        x = keras.layers.Dropout(0.3)(x)
    out = keras.layers.Dense(n_cls, activation='softmax', kernel_regularizer=keras.regularizers.l2(1e-4), name='material')(x)
    m = keras.Model(inp, out)
    m.compile(optimizer=keras.optimizers.Adam(1e-3), loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    counts = np.bincount(ytr, minlength=n_cls)
    cw = {i: len(ytr) / (n_cls * max(c, 1)) for i, c in enumerate(counts)}
    m.fit(xtr, ytr, validation_data=(xva, yva), epochs=200, batch_size=64, verbose=0, class_weight=cw,
          callbacks=[keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=15, restore_best_weights=True)])
    return m, float(m.evaluate(xva, yva, verbose=0)[1])


def confusion(y, p, n):
    cm = np.zeros((n, n), dtype=int)
    for a, b in zip(y, p):
        cm[a, b] += 1
    return cm


def macro_f1(cm):
    f1s = []
    for i in range(len(cm)):
        tp = cm[i, i]
        prec = tp / cm[:, i].sum() if cm[:, i].sum() else 0.0
        rec = tp / cm[i, :].sum() if cm[i, :].sum() else 0.0
        f1s.append(2 * prec * rec / (prec + rec) if prec + rec else 0.0)
    return float(np.mean(f1s)), f1s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--weights', required=True, help='MobileNetV2 ImageNet no-top .h5')
    ap.add_argument('--aug', type=int, default=2, help='augmented copies per training photo')
    ap.add_argument('--app-map', default='trashnet', help="'trashnet' or path to a json {class: app_key}")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)

    classes, items = list_dataset(args.data)
    tr, va, te = group_split(items)
    print('classes', classes, 'train/val/test', len(tr), len(va), len(te))
    emb_model, base = feature_model(args.weights)

    cache = os.path.join(args.out, 'features.npz')
    t0 = time.time()
    if os.path.exists(cache):
        z = np.load(cache)
        xtr, ytr, xva, yva, xte, yte = (z[k] for k in ('xtr', 'ytr', 'xva', 'yva', 'xte', 'yte'))
    else:
        xtr, itr = embed_all(emb_model, [p for p, _, _ in tr], aug_copies=args.aug, seed=1)
        ytr = np.array([tr[i][1] for i in itr])
        xva, iva = embed_all(emb_model, [p for p, _, _ in va])
        yva = np.array([va[i][1] for i in iva])
        xte, ite = embed_all(emb_model, [p for p, _, _ in te])
        yte = np.array([te[i][1] for i in ite])
        np.savez_compressed(cache, xtr=xtr, ytr=ytr, xva=xva, yva=yva, xte=xte, yte=yte)
    print('features', xtr.shape, 'in %.0f s' % (time.time() - t0))

    heads = {}
    for kind in ('linear', 'mlp'):
        heads[kind] = train_head(xtr, ytr, xva, yva, len(classes), kind)
        print(kind, 'val acc %.3f' % heads[kind][1])
    best = max(heads, key=lambda k: heads[k][1])
    head = heads[best][0]
    pte = head.predict(xte, verbose=0).argmax(1)
    cm = confusion(yte, pte, len(classes))
    acc = float((pte == yte).mean())
    mf1, f1s = macro_f1(cm)
    print('test acc %.3f macro-F1 %.3f (head %s)' % (acc, mf1, best))

    # ------------------------------------------------ combined model and TFLite export
    inp = emb_model.input
    emb = emb_model.output
    probs = head(emb)
    full = keras.Model(inp, [keras.layers.Identity(name='embedding')(emb), keras.layers.Identity(name='material')(probs)])
    conv = tf.lite.TFLiteConverter.from_keras_model(full)
    conv.optimizations = [tf.lite.Optimize.DEFAULT]           # dynamic-range int8 weights, float input and output
    tfl = conv.convert()
    tfl_path = os.path.join(args.out, 'zapwise_vision.tflite')
    open(tfl_path, 'wb').write(tfl)

    # check the TFLite file against Keras on test photos
    interp = tf.lite.Interpreter(model_path=tfl_path)
    interp.allocate_tensors()
    ind = interp.get_input_details()[0]
    outs = interp.get_output_details()
    out_info = [dict(index=o['index'], name=o['name'], shape=[int(s) for s in o['shape']]) for o in outs]
    emb_out = next(o for o in outs if o['shape'][-1] == 1280)
    cls_out = next(o for o in outs if o['shape'][-1] == len(classes))
    sims, agree, tfl_pred = [], 0, []
    sample = te[:60]
    for p, ci, _ in sample:
        a = load_rgb(p)[None]
        k_emb, k_prob = full.predict(a, verbose=0)
        interp.set_tensor(ind['index'], a)
        interp.invoke()
        t_emb = interp.get_tensor(emb_out['index'])
        t_prob = interp.get_tensor(cls_out['index'])
        sims.append(float((k_emb @ t_emb.T)[0, 0] / (np.linalg.norm(k_emb) * np.linalg.norm(t_emb))))
        agree += int(k_prob.argmax() == t_prob.argmax())
        tfl_pred.append(int(t_prob.argmax()))
    tfl_acc = float(np.mean([a == b for a, b in zip(tfl_pred, [ci for _, ci, _ in sample])]))
    print('tflite size %.2f MB, cosine(keras, tflite) min %.4f, top-1 agreement %d/%d' % (len(tfl) / 1e6, min(sims), agree, len(sample)))

    # reference input for the Dart integration test: a preprocessed 224 x 224 PNG and the expected outputs
    p0 = te[0][0]
    a0 = load_rgb(p0)
    Image.fromarray(a0.astype(np.uint8)).save(os.path.join(args.out, 'reference_224.png'))
    interp.set_tensor(ind['index'], a0[None])
    interp.invoke()
    ref = dict(file=os.path.basename(p0), true_class=classes[te[0][1]],
               embedding_head=[float(v) for v in interp.get_tensor(emb_out['index'])[0][:8]],
               probs=[float(v) for v in interp.get_tensor(cls_out['index'])[0]])

    if args.app_map == 'trashnet':
        app_map = TRASHNET_TO_APP
    elif os.path.exists(args.app_map):
        app_map = json.load(open(args.app_map))
    else:
        app_map = {c: c for c in classes}
    json.dump(dict(classes=classes, app_keys=[app_map.get(c, 'unknown') for c in classes], input=dict(shape=[1, SIZE, SIZE, 3], range='0..255 RGB float32'),
                   outputs=out_info, embedding_dim=1280), open(os.path.join(args.out, 'labels.json'), 'w'), indent=1)
    metrics = dict(dataset=os.path.abspath(args.data), classes=classes, n_train_photos=len(tr), n_val=len(va), n_test=len(te),
                   train_feature_rows=int(len(xtr)), head=best, val_acc={k: v[1] for k, v in heads.items()}, test_acc=acc, test_macro_f1=mf1,
                   per_class_f1=dict(zip(classes, [round(f, 3) for f in f1s])), confusion=cm.tolist(),
                   tflite_mb=round(len(tfl) / 1e6, 2), tflite_cosine_min=min(sims), tflite_top1_agreement=f'{agree}/{len(sample)}',
                   tflite_acc_on_sample=tfl_acc, reference=ref, split='by object id (file prefix before _), seed 7, 70/15/15')
    json.dump(metrics, open(os.path.join(args.out, 'metrics.json'), 'w'), indent=1)

    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(5, 4.4), dpi=200)
    ax.imshow(cm, cmap='RdPu')
    ax.set_xticks(range(len(classes)), classes, rotation=40, ha='right', fontsize=8)
    ax.set_yticks(range(len(classes)), classes, fontsize=8)
    for i in range(len(classes)):
        for j in range(len(classes)):
            ax.text(j, i, cm[i, j], ha='center', va='center', fontsize=8, color='white' if cm[i, j] > cm.max() / 2 else '#4B2E39')
    ax.set_xlabel('Predicted')
    ax.set_ylabel('True')
    ax.set_title(f'Test accuracy {acc:.1%}, macro F1 {mf1:.2f}', fontsize=9)
    fig.tight_layout()
    fig.savefig(os.path.join(args.out, 'confusion.png'))
    print('done ->', args.out)


if __name__ == '__main__':
    main()
