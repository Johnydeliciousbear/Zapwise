"""Kitchen objects, containers and props for ZapWise."""
from pix import Canvas


def stove():
    c = Canvas(34, 38)
    # back panel with knobs
    c.rect(2, 1, 30, 5, 'c')
    c.hline(2, 1, 30, 'w')
    for x in (5, 10, 22, 27):
        c.rect(x, 2, 3, 3, 'G')
        c.set(x + 1, 2, 'o')
    c.rect(15, 2, 4, 3, 'k')
    c.pts([(16, 3)], 'm')
    # cooktop
    c.rect(1, 6, 32, 3, 'k')
    c.hline(1, 6, 32, 'K')
    for x, col in ((4, 'K'), (19, 'r')):
        c.hline(x, 7, 10, col)
    # body
    c.rect(1, 9, 32, 26, 'c')
    c.vline(1, 9, 26, 'w')
    c.vline(32, 9, 26, 'g')
    c.hline(1, 34, 32, 'g')
    # handle
    c.rect(6, 11, 22, 2, 'G')
    c.hline(6, 11, 22, 'g')
    # oven door window
    c.rect(4, 14, 26, 18, 'g')
    c.rect(6, 16, 22, 14, 'd')
    c.pts([(7, 17), (8, 17), (9, 17), (7, 18)], 'O')
    c.rect(10, 25, 14, 3, 'E')  # glowing tray inside
    c.hline(10, 25, 14, 'y')
    # feet
    c.rect(3, 35, 3, 2, 'O')
    c.rect(28, 35, 3, 2, 'O')
    return c.outline('o').trim()


def pot():
    c = Canvas(26, 18)
    c.rect(11, 1, 4, 2, 'o')            # lid knob
    c.rrect(5, 3, 16, 3, 'G', r=1)      # lid
    c.hline(6, 3, 14, 'g')
    c.rect(4, 6, 18, 10, 'g')           # body
    c.vline(5, 7, 8, 'w')
    c.vline(6, 7, 8, 'w')
    c.vline(20, 6, 10, 'G')
    c.hline(4, 6, 18, 'G')
    c.rect(1, 8, 3, 2, 'G')             # handles
    c.rect(22, 8, 3, 2, 'G')
    return c.outline('o').trim()


def air_fryer():
    c = Canvas(22, 26)
    c.rrect(1, 1, 20, 23, 'e', r=4)
    c.vline(2, 6, 13, 'y')
    c.vline(19, 5, 15, 'E')
    c.hline(5, 23, 12, 'E')
    c.rect(6, 4, 10, 3, 'k')
    c.pts([(8, 5), (9, 5), (12, 5)], 'm')
    c.rframe(4, 10, 14, 11, 'E', r=1)   # drawer
    c.rect(8, 13, 6, 2, 'o')            # handle
    return c.outline('o').trim()


def fridge():
    c = Canvas(38, 72)
    c.rrect(1, 1, 36, 68, 'm', r=2)
    c.vline(2, 3, 64, 'w')
    c.vline(3, 3, 64, 'w')
    c.vline(35, 3, 64, 'M')
    c.hline(2, 22, 34, 'M')             # freezer split
    c.hline(2, 23, 34, 'o')
    c.rect(29, 8, 2, 10, 'w')           # handles
    c.vline(31, 8, 10, 'g')
    c.rect(29, 28, 2, 16, 'w')
    c.vline(31, 28, 16, 'g')
    # quest note magnet
    c.rect(8, 30, 12, 13, 'y')
    c.hline(8, 30, 12, 'Y')
    for yy in (33, 36, 39):
        c.hline(10, yy, 8, 'Y')
    c.rect(13, 29, 2, 2, 'r')
    # heart magnet
    c.ascii(10, 8, [".rr.rr.", "rrrrrrr", ".rrrrr.", "..rrr..", "...r..."])
    c.pts([(11, 9)], 'l')
    # feet
    c.rect(4, 69, 4, 2, 'O')
    c.rect(30, 69, 4, 2, 'O')
    return c.outline('o').trim()


def window():
    c = Canvas(52, 40)
    c.rect(1, 1, 50, 36, 'c')           # frame
    c.rect(4, 4, 44, 29, 's')           # sky
    c.rect(4, 24, 44, 9, 'S')
    c.hline(4, 23, 44, 'S')
    # far hills
    for x in range(4, 48):
        h = 3 + (2 if 10 < x < 26 else 0) + (1 if 16 < x < 21 else 0)
        c.vline(x, 33 - h, h, 'M')
    c.disc(38, 11, 4, 'y')              # sun
    c.pts([(36, 9), (37, 9)], 'w')
    for x, y in ((9, 10), (21, 15)):    # clouds
        c.rect(x, y, 10, 3, 'w')
        c.rect(x + 2, y - 2, 5, 2, 'w')
    c.rect(25, 4, 2, 29, 'c')           # mullion
    c.rect(4, 18, 44, 2, 'c')
    c.vline(1, 1, 36, 'w')
    c.rect(0, 36, 52, 3, 'c')           # sill
    c.hline(0, 38, 52, 'g')
    return c.outline('o').trim()


def plant():
    c = Canvas(16, 22)
    c.ascii(2, 1, [
        "....M.....",
        "...MmM..M.",
        "..MmmM.MmM",
        "M.MmM.MmmM",
        "mM.MM.MmM.",
        "mmM.M.MM..",
        ".MmMM.M...",
        "..MMMM....",
    ])
    c.rect(3, 10, 10, 2, 'E')
    c.rrect(4, 12, 8, 7, 'e', r=1)
    c.vline(5, 13, 5, 'y')
    c.vline(10, 13, 5, 'E')
    return c.outline('o').trim()


def shelf(w=70):
    c = Canvas(w + 2, 8)
    c.rect(1, 1, w, 3, 'n')
    c.hline(1, 1, w, 'y')
    c.hline(1, 3, w, 'N')
    for x in (6, w - 8):
        c.rect(x, 4, 3, 3, 'N')
    return c.outline('o').trim()


def glass_box():
    c = Canvas(20, 14)
    c.rrect(1, 1, 18, 3, 'm', r=1)       # snap lid
    c.hline(2, 1, 16, 'w')
    c.rect(1, 3, 2, 2, 'M')
    c.rect(17, 3, 2, 2, 'M')
    c.rect(2, 4, 16, 8, 's')
    c.vline(3, 5, 6, 'w')
    c.vline(4, 5, 3, 'w')
    c.vline(17, 4, 8, 'S')
    c.hline(2, 11, 16, 'S')
    return c.outline('o').trim()


def plates():
    c = Canvas(26, 11)
    c.rrect(1, 1, 24, 8, 'c', r=2)
    c.rframe(3, 2, 20, 6, 'p', r=1)
    c.rrect(4, 3, 18, 4, 'w', r=1)
    c.pts([(6, 3), (7, 3), (8, 3)], 'c')
    c.hline(3, 8, 20, 'g')
    return c.outline('o').trim()


def meal_box():
    c = Canvas(30, 24)
    c.rect(1, 1, 28, 21, 'c')
    c.rect(1, 1, 28, 5, 'r')
    c.hline(1, 1, 28, 'p')
    for x in (4, 6, 8, 10, 13, 15, 17):
        c.set(x, 3, 'w')
    c.rrect(4, 8, 22, 11, 'k', r=1)
    c.rect(6, 10, 10, 7, 'y')
    c.pts([(7, 11), (10, 13), (13, 11), (8, 15)], 'Y')
    c.rect(17, 10, 7, 3, 'M')
    c.rect(17, 14, 7, 3, 'E')
    c.vline(28, 2, 20, 'g')
    c.hline(1, 21, 28, 'g')
    return c.outline('o').trim()


def cpet_tray():
    c = Canvas(24, 9)
    c.rrect(1, 1, 22, 7, 'k', r=1)
    c.hline(2, 1, 20, 'K')
    c.rect(3, 3, 10, 3, 'y')             # mac and cheese
    c.pts([(4, 3), (7, 4), (10, 3)], 'Y')
    c.rect(14, 3, 3, 3, 'M')             # greens
    c.rect(18, 3, 3, 3, 'E')             # carrots
    c.vline(13, 2, 5, 'K')
    c.vline(17, 2, 5, 'K')
    return c.outline('o').trim()


def pp_cup():
    c = Canvas(14, 16)
    c.rrect(1, 1, 12, 2, 'w', r=1)       # lid
    for j in range(11):
        inset = j // 5
        c.hline(2 + inset, 3 + j, 10 - 2 * inset, 'c')
    c.rect(3, 6, 8, 4, 'r')              # label
    c.hline(3, 7, 8, 'w')
    c.vline(10, 3, 9, 'g')
    return c.outline('o').trim()


def foam_box():
    c = Canvas(22, 14)
    c.rrect(1, 1, 20, 5, 'w', r=1)       # lid
    c.rrect(2, 7, 18, 5, 'w', r=1)       # base
    c.hline(1, 6, 20, 'g')
    for x in (5, 9, 13, 17):
        c.vline(x, 2, 3, 'g')
    c.hline(3, 11, 16, 'g')
    return c.outline('o').trim()


def lamp():
    c = Canvas(18, 20)
    c.vline(8, 0, 9, 'o')
    c.rrect(3, 9, 12, 5, 'y', r=2)
    c.hline(2, 13, 14, 'Y')
    c.rect(7, 14, 4, 2, 'w')
    return c.outline('o').trim()


def wall_clock():
    c = Canvas(16, 16)
    c.disc(7, 7, 6, 'c')
    c.disc(7, 7, 5, 'w')
    c.vline(7, 3, 5, 'o')
    c.hline(7, 7, 3, 'o')
    for x, y in ((7, 2), (12, 7), (7, 12), (2, 7)):
        c.set(x, y, 'p')
    return c.outline('o').trim()


def steam():
    c = Canvas(12, 12)
    c.ascii(1, 1, [".w....w.", "w....w..", ".w....w.", "..w....w", ".w....w."])
    return c.trim()


def sparkle():
    c = Canvas(9, 9)
    c.ascii(1, 1, ["...y...", "...y...", "..yyy..", "yyyyyyy", "..yyy..", "...y...", "...y..."])
    return c.outline('o').trim()


OBJECTS = {
    'stove': stove, 'pot': pot, 'air_fryer': air_fryer, 'fridge': fridge, 'window': window, 'plant': plant,
    'shelf': shelf, 'glass_box': glass_box, 'plates': plates, 'cpet_tray': cpet_tray, 'pp_cup': pp_cup,
    'foam_box': foam_box, 'meal_box': meal_box, 'lamp': lamp, 'wall_clock': wall_clock, 'sparkle': sparkle,
}

if __name__ == '__main__':
    import os
    from PIL import Image
    os.makedirs('out/objects', exist_ok=True)
    ims = []
    for name, fn in OBJECTS.items():
        s = fn()
        s.save(f'out/objects/{name}.png')
        s.save(f'out/objects/{name}@6x.png', 6)
        s.svg(f'out/objects/{name}.svg')
        ims.append((name, s.image(6)))
    W, x, y, rowh = 2000, 30, 30, 0
    sheet = Image.new('RGBA', (W, 1400), (253, 233, 231, 255))
    for name, im in ims:
        if x + im.width > W - 30:
            x, y = 30, y + rowh + 30
            rowh = 0
        sheet.paste(im, (x, y), im)
        x += im.width + 30
        rowh = max(rowh, im.height)
    sheet = sheet.crop((0, 0, W, y + rowh + 30))
    sheet.save('out/_preview_objects.png')
    print('ok')
