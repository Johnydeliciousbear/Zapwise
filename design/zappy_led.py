"""Zappy v2: simplified LED-face microwave (candidate D)."""
from pix import Canvas
from sprites import deco

FACES = {  # 14 x 11 patch inside the black window, centre at column 6.5
    'neutral':   ["", "", "...mm....mm...", "...mm....mm...", "", "", "", "....m....m....", ".....mmmm....."],
    'blink':     ["", "", "", "...mm....mm...", "", "", "", "....m....m....", ".....mmmm....."],
    'happy':     ["", "", "...mm....mm...", "..mmmm..mmmm..", "", "", "", "....m....m....", ".....mmmm....."],
    'thinking':  ["", "....mm....mm..", "....mm....mm..", "", "", "", "", "", ".......mmm...."],
    'worried':   ["", ".....m..m.....", "...mm....mm...", "...mm....mm...", "", "", "", ".....mmmm.....", "....m....m...."],
    'celebrate': ["", "...m......m...", "..mmm....mmm..", "...m......m...", "", "", "....mmmmmm....", "....m....m....", ".....mmmm....."],
    'sleepy':    ["", "", "", "..mmm....mmm..", "", "", "", "", "......mm......"],
}


def body(expr='neutral'):
    c = Canvas(32, 26)
    c.rrect(1, 2, 28, 20, 'p', r=3, round=True)
    c.hline(4, 3, 22, 'l')
    c.hline(4, 20, 22, 'P')
    c.rrect(4, 5, 16, 13, 'k', r=2, round=True)
    c.set(6, 6, 'K'); c.set(7, 6, 'K'); c.set(6, 7, 'K')
    for j, row in enumerate(FACES[expr]):
        for i, ch in enumerate(row):
            if ch == 'm':
                c.set(5 + i, 6 + j, 'm')
    c.rect(23, 7, 3, 3, 'm')
    c.rect(23, 12, 3, 2, 'l')
    return c.outline('o').trim()


SPARK = [".y.", "yyy", ".y."]
DROP = [".s.", "sss", "sSs", ".s."]
ZED = ["wwww", "..w.", ".w..", "wwww"]


def zappy(expr='neutral'):
    """Body plus mood decorations, on a fixed 42 x 32 canvas so screens can swap moods without jumping."""
    c = Canvas(42, 32)
    c.paste(body(expr), 6, 6)
    if expr == 'worried':
        c.paste(deco(DROP), 0, 4)
    if expr == 'celebrate':
        c.paste(deco(SPARK), 0, 2)
        c.paste(deco(SPARK), 36, 0)
        c.paste(deco(SPARK), 37, 22)
    if expr == 'sleepy':
        c.paste(deco(ZED), 0, 0)
    if expr == 'thinking':
        for k, (x, y, s) in enumerate([(2, 10, 2), (0, 4, 3), (5, 0, 3)][:2]):
            d = Canvas(s + 2, s + 2)
            d.rect(1, 1, s, s, 'w')
            d.outline('o')
            c.paste(d, x, y)
    return c


def app_icon():
    c = Canvas(32, 32)
    c.rect(0, 0, 32, 32, 'b')
    c.rect(0, 24, 32, 8, 'l')
    c.hline(0, 24, 32, 'p')
    b = body('happy')
    c.paste(b, 1, 6)
    return c


if __name__ == '__main__':
    import os
    os.makedirs('out/mascot_led', exist_ok=True)
    for e in FACES:
        b = body(e)
        b.save(f'out/mascot_led/zappy_body_{e}.png')
        b.save(f'out/mascot_led/zappy_body_{e}@8x.png', 8)
        b.svg(f'out/mascot_led/zappy_body_{e}.svg')
        z = zappy(e)
        z.save(f'out/mascot_led/zappy_{e}.png')
        z.save(f'out/mascot_led/zappy_{e}@8x.png', 8)
    ic = app_icon()
    ic.save('out/mascot_led/app_icon_32.png')
    ic.save('out/mascot_led/app_icon_1024.png', 32)
    print('body', body('neutral').w, body('neutral').h)
