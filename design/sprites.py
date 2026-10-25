from pix import Canvas

# ------------------------------------------------------------------ Zappy
RING_L = [".YYYY.", "Y....Y", "Y....Y", "Y....Y", ".YYYY."]

EYES = {
    'neutral':  ["....", ".ww.", ".ww."],
    'happy':    ["....", ".ww.", "w..w"],
    'thinking': ["..ww", "..ww", "...."],
    'worried':  [".ww.", "wwww", ".ww."],
    'celebrate': ["....", ".ww.", "w..w"],
    'sleepy':   ["....", "....", "wwww"],
}
MOUTH = {
    'neutral':  ["......", ".llll.", "......"],
    'happy':    ["l....l", ".llll.", "......"],
    'thinking': ["......", "...lll", "......"],
    'worried':  ["..ll..", ".l..l.", "......"],
    'celebrate': [".llll.", ".lrrl.", "..ll.."],
    'sleepy':   ["......", "..ll..", "......"],
}
CHEEKS = {'happy', 'celebrate', 'neutral', 'sleepy'}


def face(expr):
    f = Canvas(14, 9)
    f.ascii(0, 0, RING_L)
    f.ascii(8, 0, RING_L)
    f.hline(6, 1, 2, 'Y')
    f.ascii(1, 1, EYES[expr])
    f.ascii(9, 1, EYES[expr])
    f.ascii(4, 6, MOUTH[expr])
    if expr in CHEEKS:
        f.pts([(0, 6), (1, 6), (12, 6), (13, 6)], 'r')
    return f


def zappy_body(expr='neutral'):
    b = Canvas(34, 26)
    b.rrect(1, 2, 32, 20, 'p', r=2)
    b.hline(3, 3, 28, 'l')
    b.vline(2, 5, 14, 'l')
    b.hline(3, 20, 28, 'P')
    b.vline(31, 5, 14, 'P')
    # door and glass
    b.rrect(4, 5, 18, 13, 'o', r=1)
    b.rrect(5, 6, 16, 11, 'd', r=1)
    b.pts([(6, 7), (7, 7), (6, 8)], 'O')
    b.paste(face(expr), 6, 7)
    # control panel
    b.vline(22, 5, 13, 'P')
    b.rect(24, 6, 6, 3, 'k')
    b.pts([(25, 7), (26, 7), (28, 7)], 'm')
    for yy in (11, 15):
        b.rect(25, yy, 3, 3, 'w')
        b.set(26, yy + 1, 'o')
        b.pts([(27, yy + 2)], 'l')
    # feet
    b.rect(4, 22, 4, 2, 'O')
    b.rect(26, 22, 4, 2, 'O')
    b.outline('o')
    return b


BOLT = ["..yyy", ".yyy.", "yyyyy", "..yy.", ".yy..", ".y..."]
SPARK = [".y.", "yyy", ".y."]
DROP = [".s.", "sss", "sSs", ".s."]
ZED = ["wwww", "..w.", ".w..", "wwww"]


def deco(rows):
    d = Canvas(len(rows[0]) + 2, len(rows) + 2)
    d.ascii(1, 1, rows)
    d.outline('o')
    return d


def zappy(expr='neutral'):
    c = Canvas(46, 38)
    body = zappy_body(expr)
    c.paste(body, 6, 9)
    # antenna and bolt
    c.vline(34, 7, 3, 'o')
    c.paste(deco(BOLT), 31, 0)
    if expr == 'worried':
        c.paste(deco(DROP), 1, 10)
    if expr == 'celebrate':
        c.paste(deco(SPARK), 0, 5)
        c.paste(deco(SPARK), 40, 16)
        c.paste(deco(SPARK), 1, 28)
    if expr == 'sleepy':
        c.paste(deco(ZED), 1, 3)
        c.paste(deco([".ww", "..w", "ww."][::1]), 8, 0) if False else None
    if expr == 'thinking':
        for k, (x, y) in enumerate([(2, 14), (0, 9), (2, 3)]):
            s = 2 + (k > 0)
            d = Canvas(s + 2, s + 2)
            d.rect(1, 1, s, s, 'w')
            d.outline('o')
            c.paste(d, x, y)
    return c.trim(pad=0)


if __name__ == '__main__':
    import os
    os.makedirs('out/mascot', exist_ok=True)
    from PIL import Image
    imgs = []
    for e in ['neutral', 'happy', 'thinking', 'worried', 'celebrate', 'sleepy']:
        z = zappy(e)
        z.save(f'out/mascot/zappy_{e}.png', 1)
        z.save(f'out/mascot/zappy_{e}@8x.png', 8)
        z.svg(f'out/mascot/zappy_{e}.svg')
        imgs.append(z.image(8, bg='b'))
    W = sum(i.width for i in imgs) + 40 * (len(imgs) + 1)
    H = max(i.height for i in imgs) + 80
    sheet = Image.new('RGBA', (W, H), (253, 233, 231, 255))
    x = 40
    for im in imgs:
        sheet.paste(im, (x, (H - im.height) // 2))
        x += im.width + 40
    sheet.save('out/_preview_zappy.png')
    print('ok', [zappy(e).w for e in ['neutral']], zappy('neutral').h)
