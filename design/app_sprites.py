"""Extra container sprites for the Flutter app (same 25-colour palette and outline rules)."""
import os
import shutil

from pix import Canvas

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'app', 'assets', 'ui')


def steam_bag():
    c = Canvas(20, 18)
    c.rrect(1, 3, 18, 13, 'w', r=2)            # bag
    c.hline(2, 3, 16, 'g')                      # sealed top
    c.rect(4, 7, 12, 6, 'm')                    # window with vegetables
    c.pts([(5, 8), (8, 10), (11, 8), (13, 11)], 'M')
    c.pts([(6, 11), (10, 9), (14, 9)], 'E')
    c.vline(17, 4, 11, 'g')
    c.ascii(6, 0, ['w..w..w', '.w..w..', 'w..w..w'])  # steam
    return c.outline('o').trim()


def pouch():
    c = Canvas(16, 20)
    c.rect(2, 1, 12, 2, 'g')                    # tear strip
    c.rrect(1, 3, 14, 15, 'y', r=1)
    c.rect(3, 6, 10, 5, 'c')                    # label
    c.hline(4, 7, 8, 'R')
    c.hline(4, 9, 6, 'G')
    c.vline(13, 4, 13, 'Y')
    c.hline(2, 17, 12, 'Y')
    return c.outline('o').trim()


def paper_cup():
    c = Canvas(14, 17)
    c.rect(1, 1, 12, 2, 'c')                    # rim
    for j in range(12):
        inset = j // 6
        c.hline(2 + inset, 3 + j, 10 - 2 * inset, 'w')
    c.rect(2, 6, 10, 3, 'r')                    # printed band
    c.hline(3, 7, 8, 'y')
    c.vline(11, 3, 10, 'g')
    return c.outline('o').trim()


def popcorn_bag():
    c = Canvas(18, 16)
    c.rrect(1, 4, 16, 10, 'c', r=1)
    c.rect(1, 6, 16, 6, 'r')
    for x in (3, 7, 11, 15):
        c.vline(x, 6, 6, 'w')
    c.ascii(4, 0, ['.y..y..y', 'yYy.yYy.', '.y..y..y', '........'])
    return c.outline('o').trim()


def pp_tray():
    c = Canvas(24, 10)
    c.rrect(1, 1, 22, 8, 'w', r=1)              # natural PP tray with clear film
    c.hline(2, 1, 20, 's')
    c.rect(3, 3, 11, 4, 'E')                    # sauce and pasta
    c.pts([(4, 4), (8, 3), (11, 5)], 'y')
    c.rect(15, 3, 6, 4, 'M')
    c.vline(14, 2, 6, 'g')
    return c.outline('o').trim()


def paper_tray():
    c = Canvas(24, 9)
    c.rrect(1, 1, 22, 7, 'n', r=1)
    c.hline(2, 1, 20, 'c')
    c.rect(3, 3, 18, 3, 'y')
    c.pts([(5, 3), (9, 4), (14, 3), (18, 4)], 'Y')
    c.hline(2, 7, 20, 'N')
    return c.outline('o').trim()


def can():
    c = Canvas(14, 16)
    c.rect(1, 1, 12, 2, 'G')
    c.rect(1, 3, 12, 11, 'g')
    c.rect(1, 5, 12, 6, 'R')
    c.hline(2, 7, 10, 'w')
    c.vline(2, 3, 11, 'w')
    c.rect(1, 13, 12, 1, 'G')
    return c.outline('o').trim()


def sleeve():
    c = Canvas(20, 12)
    c.rrect(1, 1, 18, 10, 'G', r=1)
    c.rect(3, 3, 14, 6, 'g')
    c.pts([(5, 4), (9, 6), (13, 4), (15, 7)], 'w')
    return c.outline('o').trim()


def melamine_bowl():
    """Bamboo-fibre (melamine) serving bowl with an autumn-leaf print, as photographed at Safeway (2026-10-14)."""
    c = Canvas(22, 13)
    c.hline(1, 1, 20, 'c')                  # rim
    c.hline(1, 2, 20, 'g')                  # inside shadow under the rim
    for y, (x, w) in enumerate([(1, 20), (2, 18), (2, 18), (3, 16), (4, 14), (5, 12)], start=3):
        c.hline(x, y, w, 'c')               # tapered body
    c.rect(7, 9, 8, 2, 'c')                 # foot
    c.pts([(4, 4), (5, 5), (9, 3), (10, 4), (14, 5), (15, 4), (17, 3), (7, 6), (12, 7)], 'E')   # orange leaves
    c.pts([(6, 4), (11, 6), (16, 6)], 'n')  # brown leaves
    c.hline(6, 8, 10, 'g')                  # shade toward the foot
    return c.outline('o').trim()


NEW = {'melamine_bowl': melamine_bowl, 'steam_bag': steam_bag, 'pouch': pouch, 'paper_cup': paper_cup, 'popcorn_bag': popcorn_bag, 'pp_tray': pp_tray,
       'paper_tray': paper_tray, 'can': can, 'sleeve': sleeve}


def main():
    proto = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'proto', 'img')
    for sub in ('icons', 'zappy', 'objects', 'scene', 'brand'):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    for f in os.listdir(proto):
        src = os.path.join(proto, f)
        name = f[:-4]
        if name.startswith('icon_'):
            shutil.copy(src, os.path.join(OUT, 'icons', name[5:] + '.png'))
        elif name.startswith('zappy_'):
            shutil.copy(src, os.path.join(OUT, 'zappy', name[6:] + '.png'))
        elif name.startswith('kitchen'):
            shutil.copy(src, os.path.join(OUT, 'scene', f))
        elif name in ('wordmark', 'app_icon'):
            shutil.copy(src, os.path.join(OUT, 'brand', f))
        elif name.startswith('product_'):
            continue  # demo boxes of the prototype
        else:
            shutil.copy(src, os.path.join(OUT, 'objects', f))
    for name in ('meal_box', 'fridge', 'lamp', 'plant', 'wall_clock', 'window', 'shelf'):
        shutil.copy(os.path.join(os.path.dirname(proto), '..', 'out', 'objects', name + '.png'), os.path.join(OUT, 'objects', name + '.png'))
    for name, fn in NEW.items():
        c = fn()
        c.save(os.path.join(OUT, 'objects', name + '.png'))
        print(name, c.w, c.h)


if __name__ == '__main__':
    main()
