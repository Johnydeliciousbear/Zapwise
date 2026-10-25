"""Compose the ZapWise pixel kitchen (home screen scene)."""
from pix import Canvas
import objects as ob
from sprites import zappy, deco, SPARK

W, H = 196, 216
FLOOR = 194
COUNTER = 154


def kitchen(expr='neutral', hotspots=True):
    c = Canvas(W, H)
    # wall with dots
    c.rect(0, 0, W, FLOOR, 'b')
    for j in range(4, FLOOR, 10):
        for i in range((j // 10) % 2 * 5 + 2, W, 10):
            c.set(i, j, 'l')
    # backsplash tiles behind the counter run
    c.rect(40, 98, 112, COUNTER - 98, 'c')
    for j in range(98, COUNTER, 7):
        c.hline(40, j, 112, 'l')
        off = 0 if (j // 7) % 2 else 6
        for i in range(40 + off, 152, 12):
            c.vline(i, j, 7, 'l')
    # floor
    c.rect(0, FLOOR, W, H - FLOOR, 'c')
    for j in range(FLOOR, H, 6):
        for i in range(0, W, 12):
            if ((i // 12) + (j - FLOOR) // 6) % 2 == 0:
                c.rect(i, j, 12, 6, 'l')
    c.hline(0, FLOOR, W, 'P')
    # ceiling lamp and clock
    c.paste(ob.lamp(), 128, 0)
    c.paste(ob.wall_clock(), 16, 22)
    # window and plant
    c.paste(ob.window(), 60, 26)
    c.paste(ob.plant(), 98, 46)
    # shelves with containers
    c.paste(ob.shelf(70), 120, 90)
    c.paste(ob.glass_box(), 124, 78)
    c.paste(ob.pp_cup(), 148, 76)
    c.paste(ob.foam_box(), 166, 78)
    c.paste(ob.shelf(70), 120, 120)
    c.paste(ob.plates(), 124, 111)
    c.paste(ob.cpet_tray(), 158, 112)
    # counter and cabinets
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
    # appliances on the counter
    c.paste(zappy(expr), 46, COUNTER - 34)
    c.paste(ob.air_fryer(), 88, COUNTER - 25)
    slot = Canvas(28, 22)
    for i in range(0, 28, 3):
        slot.set(i, 0, 'P'); slot.set(i, 21, 'P')
    for j in range(0, 22, 3):
        slot.set(0, j, 'P'); slot.set(27, j, 'P')
    slot.rect(12, 6, 4, 10, 'P')
    slot.rect(9, 9, 10, 4, 'P')
    c.paste(slot, 117, COUNTER - 23)
    # fridge and stove stand on the floor
    c.paste(ob.fridge(), 2, FLOOR - 72 + 2)
    st = ob.stove()
    c.paste(st, 152, FLOOR - st.h + 2)
    c.paste(ob.pot(), 156, FLOOR - st.h - 5)
    c.paste(ob.steam(), 162, FLOOR - st.h - 19)
    if hotspots:
        for x, y in ((40, 112), (106, 122), (186, 70), (22, 116), (182, 140)):
            c.paste(ob.sparkle(), x, y)
    return c


HOTSPOTS = {
    # name: (x, y, w, h) in scene pixels, used by the mockup overlays
    'zappy': (46, COUNTER - 34, 34, 34),
    'air_fryer': (88, COUNTER - 25, 22, 25),
    'shelf': (120, 74, 72, 56),
    'fridge': (2, FLOOR - 70, 38, 72),
    'stove': (152, FLOOR - 38, 34, 38),
    'add_slot': (117, COUNTER - 23, 28, 22),
}

if __name__ == '__main__':
    import os
    os.makedirs('out/scene', exist_ok=True)
    k = kitchen()
    k.save('out/scene/kitchen.png')
    k.save('out/scene/kitchen@2x.png', 2)
    k.save('out/scene/kitchen@4x.png', 4)
    kitchen(hotspots=False).save('out/scene/kitchen_clean@4x.png', 4)
    k.svg('out/scene/kitchen.svg')
    print('ok')
