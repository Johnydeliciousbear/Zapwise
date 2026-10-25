"""Tiny pixel-art engine: palette-indexed canvas, primitives, auto outline, PNG/SVG export."""
from PIL import Image

PAL = {
    'o': '#4B2E39',  # cocoa outline / text
    'O': '#7A4A5A',  # plum shade
    'r': '#E0607A',  # zap rose (brand)
    'R': '#B23A57',  # deep rose
    'p': '#F59BAA',  # strawberry pink
    'P': '#E27C8F',  # pink shade
    'l': '#FBC9CF',  # light pink
    'b': '#FDE9E7',  # strawberry milk (app background)
    'w': '#FFFFFF',  # white
    'c': '#FFF6F1',  # porcelain
    'e': '#FFC4A3',  # peach
    'E': '#F29672',  # apricot
    'y': '#FFE3A3',  # butter
    'Y': '#E8B85A',  # honey
    'm': '#A8DCC6',  # mint
    'M': '#5FAF95',  # sage
    's': '#C6E6F3',  # sky
    'S': '#8CC4DE',  # deep sky
    'g': '#D8CCD6',  # steam lilac grey
    'G': '#A897A8',  # pewter
    'k': '#3A2A33',  # tray black (CPET)
    'K': '#5E4653',  # tray highlight
    'n': '#D9A07E',  # maple wood
    'N': '#B07657',  # walnut shade
    'd': '#5A3646',  # microwave glass
}
NAMES = {
    'o': 'Cocoa', 'O': 'Plum', 'r': 'Zap Rose', 'R': 'Deep Rose', 'p': 'Strawberry', 'P': 'Strawberry Shade',
    'l': 'Blush', 'b': 'Strawberry Milk', 'w': 'White', 'c': 'Porcelain', 'e': 'Peach', 'E': 'Apricot',
    'y': 'Butter', 'Y': 'Honey', 'm': 'Mint', 'M': 'Sage', 's': 'Sky', 'S': 'Deep Sky', 'g': 'Steam',
    'G': 'Pewter', 'k': 'Tray Black', 'K': 'Tray Shade', 'n': 'Maple', 'N': 'Walnut', 'd': 'Glass',
}


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[None] * w for _ in range(h)]

    # ---------- primitives ----------
    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def rect(self, x, y, w, h, c):
        for j in range(y, y + h):
            for i in range(x, x + w):
                self.set(i, j, c)

    def frame(self, x, y, w, h, c):
        self.hline(x, y, w, c); self.hline(x, y + h - 1, w, c)
        self.vline(x, y, h, c); self.vline(x + w - 1, y, h, c)

    def hline(self, x, y, w, c):
        for i in range(x, x + w):
            self.set(i, y, c)

    def vline(self, x, y, h, c):
        for j in range(y, y + h):
            self.set(x, j, c)

    def rrect(self, x, y, w, h, c, r=1, round=False):
        """Filled rect with staircase corners cut by r. round=True uses circle-shaped insets."""
        import math
        def ins(k):
            if not round:
                return r - k
            return math.ceil(r - math.sqrt(max(r * r - (r - k) ** 2, 0)) - 1e-9)
        for j in range(h):
            inset = 0
            if j < r:
                inset = ins(j)
            elif j >= h - r:
                inset = ins(h - 1 - j)
            self.hline(x + inset, y + j, w - 2 * inset, c)

    def rframe(self, x, y, w, h, c, r=1):
        tmp = Canvas(self.w, self.h)
        tmp.rrect(x, y, w, h, 1, r)
        for j in range(self.h):
            for i in range(self.w):
                if tmp.px[j][i] and any(tmp.get(i + dx, j + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    self.set(i, j, c)

    def disc(self, cx, cy, r, c):
        for j in range(-r, r + 1):
            for i in range(-r, r + 1):
                if i * i + j * j <= r * r + r - 0.5:
                    self.set(cx + i, cy + j, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy; x0 += sx
            if e2 <= dx:
                err += dx; y0 += sy

    def pts(self, lst, c):
        for x, y in lst:
            self.set(x, y, c)

    def ascii(self, x, y, rows, keep_dot=True):
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch == '.' or ch == ' ':
                    continue
                self.set(x + i, y + j, ch)

    def outline(self, c='o', diag=False):
        """Add a 1px outline around every filled pixel (outside the silhouette)."""
        nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
        if diag:
            nb += [(1, 1), (-1, -1), (1, -1), (-1, 1)]
        add = []
        for j in range(self.h):
            for i in range(self.w):
                if self.px[j][i] is None and any(self.get(i + dx, j + dy) not in (None,) for dx, dy in nb):
                    add.append((i, j))
        for i, j in add:
            self.px[j][i] = c
        return self

    def paste(self, other, x, y):
        for j in range(other.h):
            for i in range(other.w):
                v = other.px[j][i]
                if v is not None:
                    self.set(x + i, y + j, v)

    def shadow(self, c='O', dx=1, dy=1):
        """Hard drop shadow under existing pixels."""
        base = [row[:] for row in self.px]
        for j in range(self.h):
            for i in range(self.w):
                if base[j][i] is not None:
                    tx, ty = i + dx, j + dy
                    if 0 <= tx < self.w and 0 <= ty < self.h and base[ty][tx] is None and self.px[ty][tx] is None:
                        self.px[ty][tx] = c
        return self

    def trim(self, pad=0):
        xs = [i for j in range(self.h) for i in range(self.w) if self.px[j][i] is not None]
        ys = [j for j in range(self.h) for i in range(self.w) if self.px[j][i] is not None]
        x0, x1, y0, y1 = min(xs) - pad, max(xs) + pad, min(ys) - pad, max(ys) + pad
        n = Canvas(x1 - x0 + 1, y1 - y0 + 1)
        for j in range(n.h):
            for i in range(n.w):
                n.px[j][i] = self.get(x0 + i, y0 + j)
        return n

    def colors(self):
        return sorted({v for row in self.px for v in row if v is not None})

    # ---------- export ----------
    def image(self, scale=1, bg=None):
        im = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0) if bg is None else rgb(PAL.get(bg, bg)) + (255,))
        for j in range(self.h):
            for i in range(self.w):
                v = self.px[j][i]
                if v is not None:
                    im.putpixel((i, j), rgb(PAL[v]) + (255,))
        if scale != 1:
            im = im.resize((self.w * scale, self.h * scale), Image.NEAREST)
        return im

    def save(self, path, scale=1, bg=None):
        self.image(scale, bg).save(path)

    def svg(self, path, scale=1):
        out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w * scale}" height="{self.h * scale}" viewBox="0 0 {self.w} {self.h}" shape-rendering="crispEdges">']
        for j in range(self.h):
            i = 0
            while i < self.w:
                v = self.px[j][i]
                if v is None:
                    i += 1
                    continue
                k = i
                while k < self.w and self.px[j][k] == v:
                    k += 1
                out.append(f'<rect x="{i}" y="{j}" width="{k - i}" height="1" fill="{PAL[v]}"/>')
                i = k
        out.append('</svg>')
        open(path, 'w').write('\n'.join(out))
