"""16x16 pixel UI icons for ZapWise. Pastel fill, cocoa outline, light from top-left."""
from pix import Canvas


def _c():
    return Canvas(16, 16)


def kitchen():
    c = _c()
    c.rrect(1, 4, 14, 9, 'p', r=1)
    c.hline(2, 4, 12, 'l')
    c.rect(3, 6, 7, 5, 'd')
    c.set(4, 7, 'O')
    c.pts([(11, 6), (12, 6)], 'k')
    c.pts([(11, 8), (11, 10)], 'w')
    c.rect(2, 13, 2, 1, 'O'); c.rect(12, 13, 2, 1, 'O')
    c.ascii(11, 0, [".yy", "yy.", ".y."])
    return c.outline('o')


def log():
    c = _c()
    c.rect(3, 1, 10, 14, 'c')
    c.rect(3, 1, 2, 14, 'r')
    for y in (4, 7, 10):
        c.hline(7, y, 5, 'l')
    c.rect(10, 1, 2, 4, 'y')
    c.set(10, 4, None)
    return c.outline('o')


def learn():
    c = _c()
    c.ascii(2, 1, [
        "..cccccc..",
        "...ssss...",
        "...ssss...",
        "...ssss...",
        "..ssssss..",
        ".ssswssss.",
        ".ssssssss.",
        "pppppppppp",
        "ppwppppppp",
        "pppppppppp",
        "pppppppppp",
        ".pppppppp.",
    ])
    return c.outline('o')


def me():
    c = _c()
    c.disc(8, 5, 3, 'e')
    c.set(7, 4, 'y')
    c.ascii(3, 10, ["..pppppp..", ".pplllppp.", "pppppppppp", "pppppppppp", "pppppppppp"])
    return c.outline('o')


def camera():
    c = _c()
    c.rect(5, 2, 5, 2, 'l')
    c.rrect(1, 4, 14, 10, 'l', r=1)
    c.hline(2, 4, 12, 'w')
    c.disc(8, 9, 3, 'g')
    c.disc(8, 9, 2, 'd')
    c.set(7, 8, 'w')
    c.set(12, 6, 'r')
    return c.outline('o')


def plate():
    c = _c()
    c.disc(8, 8, 6, 'p')
    c.disc(8, 8, 4, 'c')
    c.pts([(6, 6), (7, 5), (5, 7)], 'w')
    return c.outline('o')


def swap():
    c = _c()
    c.ascii(1, 2, [
        "..........r...",
        "rrrrrrrrrrrr..",
        "rrrrrrrrrrrrr.",
        "..........r...",
        "..............",
        "...p..........",
        ".ppppppppppppp",
        "pppppppppppppp",
        "...p..........",
    ])
    return c.outline('o')


def info():
    c = _c()
    c.disc(8, 8, 6, 's')
    c.rect(7, 4, 2, 2, 'o')
    c.rect(7, 7, 2, 5, 'o')
    return c.outline('o')


def alert():
    c = _c()
    c.ascii(1, 1, [
        "......yy......",
        "......yy......",
        ".....yyyy.....",
        ".....yooy.....",
        "....yyooyy....",
        "....yyooyy....",
        "...yyyooyyy...",
        "...yyyooyyy...",
        "..yyyyyyyyyy..",
        "..yyyyooyyyy..",
        ".yyyyyooyyyyy.",
        "yyyyyyyyyyyyyy",
    ])
    return c.outline('o')


def check():
    c = _c()
    c.disc(8, 8, 6, 'm')
    c.ascii(4, 5, ["......o", ".....oo", "o...oo.", "oo.oo..", ".ooo...", "..o...."])
    return c.outline('o')


def flame():
    c = _c()
    c.ascii(3, 1, [
        "....E.....",
        "....EE....",
        "...EEE....",
        "...EEEE...",
        "..EEEEE.E.",
        "..EEyEEEE.",
        ".EEEyyEEEE",
        ".EEyyyyEEE",
        "EEEyyyyyEE",
        "EEyyyyyyEE",
        "EEyyyyyyEE",
        ".EEyyyyEE.",
        "..EEEEEE..",
    ])
    return c.outline('o')


def timer():
    c = _c()
    c.rect(6, 1, 4, 2, 'r')
    c.disc(8, 9, 5, 'c')
    c.disc(8, 9, 4, 'w')
    c.vline(8, 6, 4, 'o')
    c.hline(8, 9, 3, 'o')
    c.set(12, 4, 'o')
    return c.outline('o')


def star():
    c = _c()
    c.ascii(1, 1, [
        "......y......",
        ".....yyy.....",
        ".....yyy.....",
        "yyyyyyyyyyyyy",
        ".yyyyyyyyyyy.",
        "..yyyyyyyyy..",
        "...yyyyyyy...",
        "...yyyyyyy...",
        "..yyyy.yyyy..",
        "..yyy...yyy..",
        ".yy.......yy.",
    ])
    c.pts([(6, 3), (6, 4)], 'w')
    return c.outline('o')


def quest():
    c = _c()
    c.rect(3, 1, 2, 14, 'G')
    c.ascii(5, 2, ["rrrrrrrr", "rrrrrrr.", "rrrrrr..", "rrrrrrr.", "rrrrrrrr"])
    c.hline(5, 2, 7, 'p')
    c.set(3, 1, 'g')
    return c.outline('o')


def heart():
    c = _c()
    c.ascii(2, 3, [
        ".rrr...rrr.",
        "rrrrr.rrrrr",
        "rllrrrrrrrr",
        "rlrrrrrrrrr",
        "rrrrrrrrrrr",
        ".rrrrrrrrr.",
        "..rrrrrrr..",
        "...rrrrr...",
        "....rrr....",
        ".....r.....",
    ])
    return c.outline('o')


def container():
    c = _c()
    c.rrect(1, 3, 14, 3, 'm', r=1)
    c.hline(2, 3, 12, 'w')
    c.rect(2, 6, 12, 7, 's')
    c.vline(3, 7, 4, 'w')
    c.vline(13, 6, 7, 'S')
    return c.outline('o')


ICONS = {
    'kitchen': kitchen, 'log': log, 'learn': learn, 'me': me, 'camera': camera, 'plate': plate, 'swap': swap,
    'info': info, 'alert': alert, 'check': check, 'flame': flame, 'timer': timer, 'star': star, 'quest': quest,
    'heart': heart, 'container': container,
}

if __name__ == '__main__':
    import os
    from PIL import Image
    os.makedirs('out/icons', exist_ok=True)
    S = 6
    sheet = Image.new('RGBA', (len(ICONS) * (16 * S + 24) + 24, 16 * S + 48 + 16 * 2 + 24), (253, 233, 231, 255))
    for k, (name, fn) in enumerate(ICONS.items()):
        ic = fn()
        ic.save(f'out/icons/{name}.png')
        ic.save(f'out/icons/{name}@2x.png', 2)
        ic.save(f'out/icons/{name}@4x.png', 4)
        ic.svg(f'out/icons/{name}.svg')
        x = 24 + k * (16 * S + 24)
        sheet.paste(ic.image(S), (x, 24), ic.image(S))
        sheet.paste(ic.image(2), (x, 24 + 16 * S + 16), ic.image(2))
    sheet.save('out/_preview_icons.png')
    print('ok')
