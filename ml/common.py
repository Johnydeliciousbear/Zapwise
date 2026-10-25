"""Shared image preprocessing. The Dart side (app/lib/core/recognition/image_prep.dart) does the same steps:

1. decode and apply EXIF orientation
2. centre-crop to a square (side = shorter edge)
3. resize to 224 x 224 with box averaging (PIL BOX here, image package Interpolation.average in Dart)
4. RGB float values in 0..255 (the model rescales to -1..1 inside)
"""
import os

import numpy as np
from PIL import Image, ImageOps

SIZE = 224
IMG_EXT = ('.jpg', '.jpeg', '.png', '.webp')


def load_rgb(path_or_img):
    im = path_or_img if isinstance(path_or_img, Image.Image) else Image.open(path_or_img)
    im = ImageOps.exif_transpose(im).convert('RGB')
    w, h = im.size
    s = min(w, h)
    left, top = (w - s) // 2, (h - s) // 2
    im = im.crop((left, top, left + s, top + s)).resize((SIZE, SIZE), Image.BOX)
    return np.asarray(im, dtype=np.float32)


def list_dataset(root):
    """root/<class>/<file>. The object id is the part of the file name before the first '_'
    (e.g. pp_container/obj07_02.jpg -> obj07). Photos of one physical object must stay in one split."""
    classes = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)) and not d.startswith('.'))
    items = []
    for ci, c in enumerate(classes):
        for f in sorted(os.listdir(os.path.join(root, c))):
            if f.lower().endswith(IMG_EXT):
                obj = f.split('_')[0] if '_' in f else os.path.splitext(f)[0]
                items.append((os.path.join(root, c, f), ci, f'{c}/{obj}'))
    return classes, items


def group_split(items, seed=7, val=0.15, test=0.15):
    """Split by object id so the same object never appears in train and test."""
    rng = np.random.default_rng(seed)
    by_class = {}
    for p, ci, g in items:
        by_class.setdefault(ci, {}).setdefault(g, []).append((p, ci, g))
    tr, va, te = [], [], []
    for ci, groups in sorted(by_class.items()):
        keys = sorted(groups)
        rng.shuffle(keys)
        n = len(keys)
        n_te = max(1, int(round(n * test)))
        n_va = max(1, int(round(n * val)))
        for k in keys[:n_te]:
            te += groups[k]
        for k in keys[n_te:n_te + n_va]:
            va += groups[k]
        for k in keys[n_te + n_va:]:
            tr += groups[k]
    return tr, va, te
