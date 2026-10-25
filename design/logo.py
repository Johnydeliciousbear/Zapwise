"""Pixel wordmark and app icon for ZapWise."""
from pix import Canvas
from sprites import zappy_body, deco, BOLT

CAP, XH, DESC = 9, 7, 3
G = {
    'Z': ["XXXXXXXX", "XXXXXXXX", ".....XX.", "....XX..", "...XX...", "..XX....", ".XX.....", "XXXXXXXX", "XXXXXXXX"],
    'a': [".XXXXX.", "XXXXXXX", ".....XX", ".XXXXXX", "XX...XX", "XXXXXXX", ".XXXXXX"],
    'p': ["XXXXXX.", "XXXXXXX", "XX...XX", "XX...XX", "XX...XX", "XXXXXXX", "XXXXXX.", "XX.....", "XX.....", "XX....."],
    'W': ["XX........XX", "XX........XX", "XX........XX", "XX...XX...XX", "XX...XX...XX", "XX..XXXX..XX",
          "XX.XX..XX.XX", "XXXX....XXXX", "XXX......XXX"],
    'i': ["XX"] * 7,
    's': [".XXXXXX", "XXXXXXX", "XX.....", ".XXXXX.", ".....XX", "XXXXXXX", "XXXXXX."],
    'e': [".XXXXX.", "XXXXXXX", "XX...XX", "XXXXXXX", "XX.....", "XXXXXXX", ".XXXXX."],
}
LOWER = set('apise')


def wordmark(text='ZapWise', fill='r', light='p', gap=3, shadow=True):
    widths = [len(G[ch][0]) for ch in text]
    W = sum(widths) + gap * (len(text) - 1) + 8
    H = CAP + DESC + 12
    c = Canvas(W, H)
    top = 7
    x = 3
    ipos = None
    for ch in text:
        g = G[ch]
        y0 = top + (CAP - XH if ch in LOWER else 0)
        for j, row in enumerate(g):
            for i, v in enumerate(row):
                if v == 'X':
                    c.set(x + i, y0 + j, fill)
        # top highlight row
        for i, v in enumerate(g[0]):
            if v == 'X':
                c.set(x + i, y0, light)
        if ch == 'i':
            ipos = (x, y0)
        x += len(g[0]) + gap
    c.outline('o')
    if shadow:
        c.shadow('O', 1, 1)
    if ipos:
        b = deco(BOLT)
        c.paste(b, ipos[0] - 2, ipos[1] - b.h - 1)
    return c.trim()


def app_icon():
    c = Canvas(32, 32)
    c.rect(0, 0, 32, 32, 'b')
    c.rect(0, 25, 32, 7, 'l')
    c.hline(0, 25, 32, 'p')
    # mini zappy
    m = Canvas(28, 22)
    m.rrect(1, 2, 26, 16, 'p', r=2)
    m.hline(3, 3, 22, 'l')
    m.vline(2, 5, 10, 'l')
    m.hline(3, 16, 22, 'P')
    m.rrect(4, 5, 16, 10, 'o', r=1)
    m.rrect(5, 6, 14, 8, 'd', r=1)
    # glasses + eyes
    m.ascii(6, 6, [".YYYY...YYYY.", "Y.ww.YYY.ww.Y", "Y.ww.Y.Y.ww.Y", ".YYYY...YYYY.", "r...l...l...r", ".....lll....."])
    m.vline(21, 5, 10, 'P')
    m.rect(23, 6, 2, 2, 'm')
    m.rect(23, 9, 2, 2, 'w')
    m.rect(23, 12, 2, 2, 'w')
    m.rect(4, 18, 3, 2, 'O')
    m.rect(21, 18, 3, 2, 'O')
    m.outline('o')
    c.paste(m, 2, 6)
    b = deco(["..yy", ".yy.", "yyyy", ".yy.", "yy.."])
    c.paste(b, 21, 0)
    c.vline(22, 6, 2, 'o')
    return c


if __name__ == '__main__':
    import os
    os.makedirs('out/brand', exist_ok=True)
    w = wordmark()
    w.save('out/brand/zapwise_wordmark.png')
    w.save('out/brand/zapwise_wordmark@8x.png', 8)
    w.svg('out/brand/zapwise_wordmark.svg')
    ic = app_icon()
    ic.save('out/brand/app_icon_32.png')
    ic.save('out/brand/app_icon_1024.png', 32)
    ic.svg('out/brand/app_icon.svg')
    from PIL import Image
    a = w.image(8, bg='b')
    b = ic.image(8)
    sheet = Image.new('RGBA', (a.width + b.width + 120, max(a.height, b.height) + 80), (253, 233, 231, 255))
    sheet.paste(a, (40, 40))
    sheet.paste(b, (a.width + 80, 40))
    sheet.save('out/_preview_brand.png')
    print(w.w, w.h)
