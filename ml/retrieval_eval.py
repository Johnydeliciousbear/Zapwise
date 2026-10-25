"""How well does the embedding find the same object again from a new photo?

Simulates the app's product look-up: a gallery holds one photo per object, each query is a
re-photographed version (crop, rotation, light, blur, JPEG). Also measures how similar
photos of objects that are NOT in the gallery look, which sets the threshold below which
the app asks the user to register a new product instead of guessing.

Run:  python retrieval_eval.py --data <image root> --model out/trashnet/zapwise_vision.tflite --out out/retrieval
"""
import argparse
import io
import json
import os

os.environ.setdefault('TF_CPP_MIN_LOG_LEVEL', '3')
import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
from PIL import Image, ImageEnhance, ImageFilter  # noqa: E402

from common import list_dataset, load_rgb  # noqa: E402


class Vision:
    def __init__(self, path):
        self.it = tf.lite.Interpreter(model_path=path)
        self.it.allocate_tensors()
        self.inp = self.it.get_input_details()[0]['index']
        self.emb = next(o['index'] for o in self.it.get_output_details() if o['shape'][-1] == 1280)

    def embed(self, arr):
        self.it.set_tensor(self.inp, arr[None].astype(np.float32))
        self.it.invoke()
        v = self.it.get_tensor(self.emb)[0].astype(np.float64)
        return v / (np.linalg.norm(v) + 1e-12)


def rephotograph(path, rng):
    im = Image.open(path).convert('RGB')
    w, h = im.size
    s = rng.uniform(0.7, 0.92)
    cw, ch = int(w * s), int(h * s)
    x0, y0 = rng.integers(0, w - cw + 1), rng.integers(0, h - ch + 1)
    im = im.crop((x0, y0, x0 + cw, y0 + ch)).rotate(rng.uniform(-12, 12), resample=Image.BILINEAR, expand=False, fillcolor=(235, 230, 225))
    im = ImageEnhance.Brightness(im).enhance(rng.uniform(0.75, 1.25))
    im = ImageEnhance.Contrast(im).enhance(rng.uniform(0.75, 1.25))
    if rng.random() < 0.5:
        im = im.filter(ImageFilter.GaussianBlur(rng.uniform(0.3, 1.2)))
    buf = io.BytesIO()
    im.save(buf, 'JPEG', quality=int(rng.integers(55, 85)))
    return Image.open(io.BytesIO(buf.getvalue()))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--data', required=True)
    ap.add_argument('--model', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--gallery', type=int, default=300)
    ap.add_argument('--unknown', type=int, default=300)
    ap.add_argument('--views', type=int, default=2)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(11)
    _, items = list_dataset(args.data)
    order = rng.permutation(len(items))
    gal = [items[i][0] for i in order[:args.gallery]]
    unk = [items[i][0] for i in order[args.gallery:args.gallery + args.unknown]]
    v = Vision(args.model)
    G = np.stack([v.embed(load_rgb(p)) for p in gal])

    top1 = top5 = n = 0
    best_true, margins = [], []
    for gi, p in enumerate(gal):
        for _ in range(args.views):
            q = v.embed(load_rgb(rephotograph(p, rng)))
            sims = G @ q
            rank = np.argsort(-sims)
            n += 1
            top1 += int(rank[0] == gi)
            top5 += int(gi in rank[:5])
            best_true.append(float(sims[rank[0]]) if rank[0] == gi else None)
            margins.append(float(sims[rank[0]] - sims[rank[1]]))
    unk_best = []
    for p in unk:
        q = v.embed(load_rgb(rephotograph(p, rng)))
        unk_best.append(float((G @ q).max()))
    correct = np.array([b for b in best_true if b is not None])
    unk_best = np.array(unk_best)

    # threshold: accept a match only if similarity >= tau. Choose tau so that at most 5 % of unknown objects are accepted.
    tau = float(np.quantile(unk_best, 0.95))
    accepted_correct = float((correct >= tau).mean())
    res = dict(gallery=len(gal), queries=n, top1=top1 / n, top5=top5 / n,
               correct_sim_median=float(np.median(correct)), correct_sim_p05=float(np.quantile(correct, 0.05)),
               unknown_best_sim_median=float(np.median(unk_best)), unknown_best_sim_p95=tau,
               threshold_accept=tau, share_of_correct_matches_above_threshold=accepted_correct,
               note='Gallery and unknown photos are TrashNet images (MIT). Replace with product photos once the student has them.')
    json.dump(res, open(os.path.join(args.out, 'retrieval.json'), 'w'), indent=1)
    print(json.dumps(res, indent=1))

    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(5.5, 3.2), dpi=200)
    ax.hist(correct, bins=30, alpha=0.75, color='#E0607A', label='same object, new photo')
    ax.hist(unk_best, bins=30, alpha=0.75, color='#5FAF95', label='object not in gallery')
    ax.axvline(tau, color='#4B2E39', ls='--', lw=1)
    ax.text(tau, ax.get_ylim()[1] * 0.9, f' threshold {tau:.2f}', fontsize=8, color='#4B2E39')
    ax.set_xlabel('Cosine similarity of the best gallery match')
    ax.set_ylabel('Photos')
    ax.legend(frameon=False, fontsize=8)
    ax.spines[['top', 'right']].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(args.out, 'retrieval_hist.png'))


if __name__ == '__main__':
    main()
