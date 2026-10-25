"""Kitchen v2: base scene without Zappy, air fryer and shelf items, so the app can place them."""
from pix import Canvas
import objects as ob

W, H = 196, 216
FLOOR, COUNTER = 194, 154


def pet_clam():
    c = Canvas(20, 12)
    c.rrect(1, 1, 18, 4, 's', r=1)
    c.rrect(1, 6, 18, 4, 's', r=1)
    c.hline(1, 5, 18, 'S')
    c.hline(3, 2, 10, 'w')
    c.hline(3, 7, 10, 'w')
    return c.outline('o').trim()


def deli_tub():
    c = Canvas(18, 14)
    c.rrect(1, 1, 16, 3, 'w', r=1)
    c.hline(2, 3, 14, 'g')
    for j in range(8):
        inset = j // 4
        c.hline(2 + inset, 4 + j, 14 - 2 * inset, 'c')
    c.vline(4, 5, 5, 'w')
    c.vline(14, 4, 7, 'g')
    return c.outline('o').trim()


def product(band='r', food=(('y', 'Y'), ('M', None), ('E', None)), w=30, h=23):
    c = Canvas(w + 2, h + 2)
    c.rect(1, 1, w - 2, h - 2, 'c')
    c.rect(1, 1, w - 2, 5, band)
    for x in range(4, 12, 2):
        c.set(x, 3, 'w')
    c.rrect(4, 8, w - 8, h - 12, 'k', r=1)
    fx = 6
    widths = [9, 6, 5][:len(food)]
    for (col, spot), fw in zip(food, widths):
        c.rect(fx, 10, fw - 1, h - 16, col)
        if spot:
            c.pts([(fx + 1, 11), (fx + 4, 12), (fx + 2, 13)], spot)
        fx += fw
    c.vline(w - 2, 2, h - 3, 'g')
    c.hline(1, h - 2, w - 2, 'g')
    return c.outline('o').trim()


def rug():
    c = Canvas(64, 12)
    c.rrect(1, 1, 62, 10, 'r', r=3, round=True)
    c.rrect(3, 2, 58, 8, 'p', r=2, round=True)
    for x in range(6, 58, 6):
        c.rect(x, 5, 3, 2, 'l')
    return c.outline('o').trim()


def kitchen(reward=False):
    c = Canvas(W, H)
    c.rect(0, 0, W, FLOOR, 'b')
    for j in range(4, FLOOR, 10):
        for i in range((j // 10) % 2 * 5 + 2, W, 10):
            c.set(i, j, 'l')
    c.rect(40, 98, 112, COUNTER - 98, 'c')
    for j in range(98, COUNTER, 7):
        c.hline(40, j, 112, 'l')
        off = 0 if (j // 7) % 2 else 6
        for i in range(40 + off, 152, 12):
            c.vline(i, j, 7, 'l')
    c.rect(0, FLOOR, W, H - FLOOR, 'c')
    for j in range(FLOOR, H, 6):
        for i in range(0, W, 12):
            if ((i // 12) + (j - FLOOR) // 6) % 2 == 0:
                c.rect(i, j, 12, 6, 'l')
    c.hline(0, FLOOR, W, 'P')
    c.paste(ob.lamp(), 128, 0)
    c.paste(ob.wall_clock(), 16, 22)
    c.paste(ob.window(), 60, 26)
    c.paste(ob.plant(), 98, 46)
    c.paste(ob.shelf(70), 120, 90)
    c.paste(ob.shelf(70), 120, 120)
    c.rect(40, COUNTER, 112, 5, 'y')
    c.hline(40, COUNTER, 112, 'w')
    c.hline(40, COUNTER + 4, 112, 'Y')
    c.hline(40, COUNTER - 1, 112, 'o')
    c.hline(40, COUNTER + 5, 112, 'o')
    c.rect(40, COUNTER + 6, 112, FLOOR - COUNTER - 6, 'p')
    for x in range(40, 152, 28):
        c.rframe(x + 2, COUNTER + 8, 24, FLOOR - COUNTER - 11, 'P', r=1)
        c.rect(x + 12, COUNTER + 12, 4, 2, 'Y')
        c.vline(x, COUNTER + 6, FLOOR - COUNTER - 6, 'P')
    c.paste(ob.fridge(), 2, FLOOR - 72 + 2)
    st = ob.stove()
    c.paste(st, 152, FLOOR - st.h + 2)
    c.paste(ob.pot(), 156, FLOOR - st.h - 5)
    c.paste(ob.steam(), 162, FLOOR - st.h - 19)
    if reward:
        c.paste(rug(), 66, FLOOR + 6)
        p = ob.plant()
        c.paste(p, 14, FLOOR - 72 - p.h + 3)
    return c


if __name__ == '__main__':
    import os
    from zappy_led import body, zappy, FACES, app_icon
    D = 'out/proto'
    os.makedirs(D, exist_ok=True)
    kitchen().save(f'{D}/kitchen.png')
    kitchen(True).save(f'{D}/kitchen_reward.png')
    for e in FACES:
        body(e).save(f'{D}/zappy_body_{e}.png')
        zappy(e).save(f'{D}/zappy_{e}.png')
    app_icon().save(f'{D}/app_icon.png', 4)
    sprites = {
        'air_fryer': ob.air_fryer(), 'glass_box': ob.glass_box(), 'plates': ob.plates(), 'cpet_tray': ob.cpet_tray(),
        'pp_cup': ob.pp_cup(), 'foam_box': ob.foam_box(), 'pet_clam': pet_clam(), 'deli_tub': deli_tub(), 'pot': ob.pot(),
        'stove': ob.stove(), 'sparkle': ob.sparkle(),
        'product_mac': product('r', (('y', 'Y'), ('M', None), ('E', None))),
        'product_teriyaki': product('E', (('N', 'n'), ('c', None), ('M', None))),
        'product_bites': product('Y', (('n', 'N'), ('n', 'N'), ('M', None))),
    }
    for k, v in sprites.items():
        v.save(f'{D}/{k}.png')
    from icons import ICONS
    for k, f in ICONS.items():
        f().save(f'{D}/icon_{k}.png')
    # kitchen tab icon in LED style
    ic = Canvas(16, 16)
    ic.rrect(1, 4, 14, 10, 'p', r=2, round=True)
    ic.hline(3, 5, 10, 'l')
    ic.rrect(3, 6, 7, 6, 'k', r=1, round=True)
    ic.pts([(4, 8), (8, 8), (5, 10), (6, 10), (7, 10)], 'm')
    ic.rect(11, 7, 2, 2, 'm')
    ic.outline('o')
    ic.save(f'{D}/icon_kitchen.png')
    from logo import wordmark
    wordmark().save(f'{D}/wordmark.png')
    print({k: (v.w, v.h) for k, v in sprites.items()}, body('neutral').w, zappy('neutral').w, zappy('neutral').h)
