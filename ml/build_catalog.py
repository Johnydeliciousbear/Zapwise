"""Embed product photos for the app's image look-up.

Folder layout:   photos/products/<product_id>/<anything>.jpg   (3-6 photos per product: front, angled, in hand)
Run:             python build_catalog.py --photos photos/products --model ../app/assets/models/zapwise_vision.tflite
Writes:          ../app/assets/data/catalog_embeddings.json

Product ids must match products.json (zw-001 ...). Use the same TFLite file the app ships,
so photo and catalog vectors come from the same model.
"""
import argparse
import base64
import json
import os

os.environ.setdefault('TF_CPP_MIN_LOG_LEVEL', '3')
import numpy as np  # noqa: E402

from common import IMG_EXT, load_rgb  # noqa: E402
from retrieval_eval import Vision  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--photos', required=True)
    ap.add_argument('--model', default=os.path.join(HERE, '..', 'app', 'assets', 'models', 'zapwise_vision.tflite'))
    ap.add_argument('--products', default=os.path.join(HERE, '..', 'app', 'assets', 'data', 'products.json'))
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'app', 'assets', 'data', 'catalog_embeddings.json'))
    args = ap.parse_args()
    known = {p['id'] for p in json.load(open(args.products))['products']}
    v = Vision(args.model)
    items, skipped = [], []
    for pid in sorted(os.listdir(args.photos)):
        d = os.path.join(args.photos, pid)
        if not os.path.isdir(d):
            continue
        if pid not in known:
            skipped.append(pid)
            continue
        vecs = []
        for f in sorted(os.listdir(d)):
            if f.lower().endswith(IMG_EXT):
                e = v.embed(load_rgb(os.path.join(d, f))).astype(np.float32)
                vecs.append(base64.b64encode(e.astype('<f4').tobytes()).decode('ascii'))
        if vecs:
            items.append(dict(product_id=pid, vectors=vecs))
    json.dump(dict(dim=1280, model=os.path.basename(args.model), items=items), open(args.out, 'w'))
    print(f'{len(items)} products, {sum(len(i["vectors"]) for i in items)} photos -> {args.out}')
    if skipped:
        print('folders not in products.json (skipped):', skipped)


if __name__ == '__main__':
    main()
