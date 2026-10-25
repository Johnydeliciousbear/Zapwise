"""Ten simplified Zappy candidates. Fewer parts, bigger features, readable at 32 px."""
from pix import Canvas
from sprites import deco

BOLT_S = [".yy", "yy.", ".yy", "yy."]
BOLT_M = ["..yy", ".yy.", "yyyy", ".yy.", "yy.."]


def body(c, x, y, w, h, fill='p', r=3, hl='l', sh='P'):
    c.rrect(x, y, w, h, fill, r=r, round=True)
    if hl:
        c.hline(x + r, y + 1, w - 2 * r, hl)
    if sh:
        c.hline(x + r, y + h - 2, w - 2 * r, sh)


def eyes(c, x1, x2, y, col='w', w=2, h=2):
    c.rect(x1, y, w, h, col)
    c.rect(x2, y, w, h, col)


def smile(c, x, y, col='l', w=4):
    c.set(x, y, col); c.set(x + w + 1, y, col)
    c.hline(x + 1, y + 1, w, col)


def dial(c, x, y, col='w'):
    c.rect(x, y, 3, 3, col)
    c.set(x + 1, y + 1, 'o')


def a_minimal():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.rrect(4, 5, 16, 13, 'd', r=2, round=True)
    eyes(c, 8, 14, 9)
    smile(c, 9, 13, w=4)
    dial(c, 23, 8)
    c.rect(23, 13, 3, 2, 'l')
    return c.outline('o').trim()


def b_glasses():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.rrect(4, 5, 16, 13, 'd', r=2, round=True)
    c.ascii(5, 7, [".YYY..YYY.", "Y.wwYYww.Y", "Y.ww..ww.Y", ".YYY..YYY."][:4])
    c.ascii(5, 7, [".YYYY..YYYY", "Y.ww.YY.ww.Y"[:11], "Y.ww.Y..ww.", ".YYYY..YYYY"])
    smile(c, 9, 13, w=4)
    dial(c, 23, 8)
    c.rect(23, 13, 3, 2, 'l')
    return c.outline('o').trim()


def b_glasses_clean():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.rrect(4, 5, 16, 13, 'd', r=2, round=True)
    # two round lenses 5x5 with a bridge
    ring = [".YYY.", "Y...Y", "Y...Y", "Y...Y", ".YYY."]
    c.ascii(5, 6, ring)
    c.ascii(13, 6, ring)
    c.hline(10, 7, 3, 'Y')
    c.rect(7, 8, 1, 2, 'w'); c.rect(15, 8, 1, 2, 'w')
    c.rect(6, 8, 1, 2, 'w'); c.rect(14, 8, 1, 2, 'w')
    smile(c, 9, 13, w=4)
    dial(c, 23, 8)
    c.rect(23, 13, 3, 2, 'l')
    return c.outline('o').trim()


def c_bolt_tuft():
    c = Canvas(32, 30)
    body(c, 1, 6, 28, 20)
    c.rrect(4, 9, 16, 13, 'd', r=2, round=True)
    eyes(c, 8, 14, 13)
    smile(c, 9, 17, w=4)
    dial(c, 23, 12)
    c.rect(23, 17, 3, 2, 'l')
    c.outline('o')
    c.paste(deco(BOLT_M), 11, 0)
    return c.trim()


def d_led():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.rrect(4, 5, 16, 13, 'k', r=2, round=True)
    c.ascii(6, 8, [".mm....mm.", "mmmm..mmmm", "mm.m..m.mm"][:2])
    c.ascii(9, 13, ["m....m"[:6], ".mmmm."])
    c.rect(23, 7, 3, 3, 'm')
    c.rect(23, 12, 3, 2, 'l')
    return c.outline('o').trim()


def e_round_retro():
    c = Canvas(30, 26)
    body(c, 1, 2, 26, 20, r=7)
    c.rrect(4, 6, 14, 12, 'c', r=3, round=True)
    eyes(c, 7, 13, 9, col='o', w=2, h=2)
    c.pts([(6, 13), (16, 13)], 'p')
    c.hline(9, 14, 4, 'o')
    c.disc(22, 10, 2, 'Y')
    c.set(22, 10, 'o')
    c.rect(21, 15, 3, 2, 'l')
    return c.outline('o').trim()


def f_chibi():
    c = Canvas(28, 28)
    body(c, 1, 2, 23, 21, r=5)
    c.rrect(3, 5, 14, 12, 'd', r=2, round=True)
    c.rect(6, 8, 2, 3, 'w'); c.rect(12, 8, 2, 3, 'w')
    c.pts([(5, 12), (14, 12)], 'r')
    smile(c, 8, 12, w=2)
    dial(c, 19, 7)
    c.rect(19, 12, 3, 2, 'l')
    c.rect(4, 23, 3, 2, 'O'); c.rect(17, 23, 3, 2, 'O')
    return c.outline('o').trim()


def g_flat():
    c = Canvas(32, 26)
    c.rrect(1, 2, 28, 20, 'p', r=3, round=True)
    c.rrect(4, 5, 16, 13, 'd', r=2, round=True)
    eyes(c, 8, 14, 10)
    c.ascii(22, 8, [".yy", "yy.", ".yy", "yy."][:4])
    return c.outline('o').trim()


def h_square_glasses():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.rrect(4, 5, 16, 13, 'd', r=2, round=True)
    c.frame(6, 8, 5, 4, 'Y'); c.frame(13, 8, 5, 4, 'Y')
    c.hline(11, 9, 2, 'Y')
    c.rect(8, 9, 2, 2, 'w'); c.rect(15, 9, 2, 2, 'w')
    c.hline(10, 14, 4, 'l')
    c.vline(21, 6, 11, 'P')
    dial(c, 23, 8)
    return c.outline('o').trim()


def i_white_body():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20, fill='c', hl='w', sh='g')
    c.rrect(3, 4, 18, 15, 'p', r=2, round=True)
    c.rrect(5, 6, 14, 11, 'd', r=2, round=True)
    eyes(c, 8, 13, 9)
    smile(c, 8, 13, w=4)
    dial(c, 23, 8, col='p')
    c.rect(23, 13, 3, 2, 'l')
    return c.outline('o').trim()


def j_porthole_eyes():
    c = Canvas(32, 26)
    body(c, 1, 2, 28, 20)
    c.disc(8, 11, 4, 'Y')
    c.disc(18, 11, 4, 'Y')
    c.disc(8, 11, 3, 'd')
    c.disc(18, 11, 3, 'd')
    c.hline(12, 10, 3, 'Y')
    c.rect(8, 10, 2, 2, 'w'); c.rect(18, 10, 2, 2, 'w')
    c.hline(11, 17, 4, 'P')
    c.rect(24, 6, 3, 3, 'w'); c.set(25, 7, 'o')
    return c.outline('o').trim()


VARIANTS = [
    ('A', 'Minimal', '창 하나, 점 눈, 다이얼 하나', a_minimal),
    ('B', 'Round glasses', 'A에 둥근 안경만 더함', b_glasses_clean),
    ('C', 'Bolt tuft', 'A에 번개 머리 장식', c_bolt_tuft),
    ('D', 'LED face', '검은 화면에 민트색 LED 표정', d_led),
    ('E', 'Round retro', '둥근 몸체, 밝은 창, 코코아 눈', e_round_retro),
    ('F', 'Chibi', '정사각에 가까운 비율, 큰 눈, 볼터치', f_chibi),
    ('G', 'Flat icon', '음영 없음, 눈만, 번개 버튼', g_flat),
    ('H', 'Square glasses', '네모 안경과 문 손잡이', h_square_glasses),
    ('I', 'White body', '흰 몸체에 분홍 문틀', i_white_body),
    ('J', 'Porthole eyes', '둥근 창 두 개가 곧 안경과 눈', j_porthole_eyes),
]

if __name__ == '__main__':
    import os
    from PIL import Image, ImageDraw, ImageFont
    os.makedirs('out/mascot_v2', exist_ok=True)
    for k, name, desc, fn in VARIANTS:
        s = fn()
        s.save(f'out/mascot_v2/{k}_{name.replace(" ", "_").lower()}.png')
        s.save(f'out/mascot_v2/{k}_{name.replace(" ", "_").lower()}@8x.png', 8)
    print('ok', [(k, fn().w, fn().h) for k, _, _, fn in VARIANTS])
