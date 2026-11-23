# Draws the pixel-art menu pieces (same style as the controls): a pixel font in white and banded
# gold, the sky-and-checker background, card frames, a star and a toggle switch.
# Usage: python3 ci/menu_art.py ios/App/Controls
import os, sys
from PIL import Image

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

BLACK = (12, 12, 28, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
# the banded gold of "PRESS START" (LooneyDude's title lettering): top to bottom
GOLD_BANDS = [(200, 138, 55), (255, 166, 0), (255, 255, 0), (255, 255, 255), (255, 255, 0), (255, 166, 0), (200, 138, 55)]

# 5x7 font, ASCII 32..95 (space, punctuation, digits, capitals)
F = {
' ': ["00000"]*7,
'!': ["00100","00100","00100","00100","00100","00000","00100"],
"'": ["00100","00100","01000","00000","00000","00000","00000"],
'(': ["00010","00100","01000","01000","01000","00100","00010"],
')': ["01000","00100","00010","00010","00010","00100","01000"],
',': ["00000","00000","00000","00000","00110","00100","01000"],
'-': ["00000","00000","00000","11111","00000","00000","00000"],
'.': ["00000","00000","00000","00000","00000","01100","01100"],
'/': ["00001","00010","00010","00100","01000","01000","10000"],
'0': ["01110","10001","10011","10101","11001","10001","01110"],
'1': ["00100","01100","00100","00100","00100","00100","01110"],
'2': ["01110","10001","00001","00110","01000","10000","11111"],
'3': ["11110","00001","00001","01110","00001","00001","11110"],
'4': ["00010","00110","01010","10010","11111","00010","00010"],
'5': ["11111","10000","11110","00001","00001","10001","01110"],
'6': ["00110","01000","10000","11110","10001","10001","01110"],
'7': ["11111","00001","00010","00100","01000","01000","01000"],
'8': ["01110","10001","10001","01110","10001","10001","01110"],
'9': ["01110","10001","10001","01111","00001","00010","01100"],
':': ["00000","01100","01100","00000","01100","01100","00000"],
'?': ["01110","10001","00001","00110","00100","00000","00100"],
'A': ["01110","10001","10001","11111","10001","10001","10001"],
'B': ["11110","10001","10001","11110","10001","10001","11110"],
'C': ["01110","10001","10000","10000","10000","10001","01110"],
'D': ["11100","10010","10001","10001","10001","10010","11100"],
'E': ["11111","10000","10000","11110","10000","10000","11111"],
'F': ["11111","10000","10000","11110","10000","10000","10000"],
'G': ["01110","10001","10000","10111","10001","10001","01111"],
'H': ["10001","10001","10001","11111","10001","10001","10001"],
'I': ["01110","00100","00100","00100","00100","00100","01110"],
'J': ["00111","00010","00010","00010","00010","10010","01100"],
'K': ["10001","10010","10100","11000","10100","10010","10001"],
'L': ["10000","10000","10000","10000","10000","10000","11111"],
'M': ["10001","11011","10101","10101","10001","10001","10001"],
'N': ["10001","11001","10101","10011","10001","10001","10001"],
'O': ["01110","10001","10001","10001","10001","10001","01110"],
'P': ["11110","10001","10001","11110","10000","10000","10000"],
'Q': ["01110","10001","10001","10001","10101","10010","01101"],
'R': ["11110","10001","10001","11110","10100","10010","10001"],
'S': ["01111","10000","10000","01110","00001","00001","11110"],
'T': ["11111","00100","00100","00100","00100","00100","00100"],
'U': ["10001","10001","10001","10001","10001","10001","01110"],
'V': ["10001","10001","10001","10001","10001","01010","00100"],
'W': ["10001","10001","10001","10101","10101","10101","01010"],
'X': ["10001","10001","01010","00100","01010","10001","10001"],
'Y': ["10001","10001","01010","00100","00100","00100","00100"],
'Z': ["11111","00001","00010","00100","01000","10000","11111"],
}

def font(colour_fn, name):
    """A strip of 64 glyph cells (ASCII 32..95), each 7x9: 5x7 letter + 1px outline."""
    strip = Image.new('RGBA', (64 * 7, 9), CLEAR)
    for code in range(32, 96):
        g = F.get(chr(code))
        if not g:
            continue
        ox = (code - 32) * 7
        pts = {(c, r) for r, row in enumerate(g) for c, b in enumerate(row) if b == '1'}
        for (c, r) in pts:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (c + dx, r + dy)
                    if q not in pts:
                        strip.putpixel((ox + 1 + q[0], 1 + q[1]), BLACK)
        for (c, r) in pts:
            strip.putpixel((ox + 1 + c, 1 + r), colour_fn(r))
    strip.save(os.path.join(out, name))

font(lambda r: WHITE, 'font_white.png')
font(lambda r: GOLD_BANDS[r] + (255,), 'font_gold.png')

# ---- background: banded Sonic sky, puffy clouds, checkered hill ground ----
W, H = 240, 135
bg = Image.new('RGBA', (W, H), (0, 0, 0, 255))
sky = [(16, 40, 140), (24, 60, 176), (36, 88, 210), (56, 120, 236), (88, 156, 252), (128, 188, 255)]
band_h = 13
for y in range(H):
    c = sky[min(len(sky) - 1, y // band_h)]
    for x in range(W):
        bg.putpixel((x, y), c + (255,))
import math
def cloud(cx, cy, s):
    for y in range(cy - s, cy + s):
        for x in range(cx - 3 * s, cx + 3 * s):
            if 0 <= x < W and 0 <= y < H:
                d = min(math.hypot((x - (cx + k * s)) / s, (y - cy) / (s * 0.8)) for k in (-2, -1, 0, 1, 2))
                if d < 1:
                    bg.putpixel((x, y), (235, 245, 255, 255) if y < cy else (196, 220, 255, 255))
for (cx, cy, s) in [(40, 22, 5), (130, 14, 4), (205, 30, 6), (90, 44, 3)]:
    cloud(cx, cy, s)
# hills: checkered brown ground (Green Hill style) with a green top edge
for x in range(W):
    top = int(100 + 8 * math.sin(x / 19.0) + 4 * math.sin(x / 7.0))
    for y in range(top, H):
        if y < top + 3:
            c = (40, 176, 56) if y < top + 2 else (24, 120, 40)
        else:
            c = (196, 112, 40) if ((x // 8) + ((y - top) // 8)) % 2 == 0 else (150, 76, 24)
        bg.putpixel((x, y), c + (255,))
bg.save(os.path.join(out, 'menu_bg.png'))

# ---- card frame (9-slice: 6px corners) ----
def panel(fill, light, dark, edge):
    S = 18
    im = Image.new('RGBA', (S, S), CLEAR)
    for y in range(S):
        for x in range(S):
            corner = (x in (0, S - 1)) and (y in (0, S - 1))
            if corner:
                continue
            if x in (0, S - 1) or y in (0, S - 1):
                c = edge
            elif x == 1 or y == 1 or x == 2 or y == 2:
                c = light
            elif x >= S - 3 or y >= S - 3:
                c = dark
            else:
                c = fill
            im.putpixel((x, y), c)
    return im
panel((24, 52, 170, 235), (86, 132, 255, 255), (12, 30, 110, 255), BLACK).save(os.path.join(out, 'panel.png'))
panel((48, 80, 200, 245), (255, 246, 150, 255), (230, 130, 0, 255), BLACK).save(os.path.join(out, 'panel_on.png'))
panel((20, 110, 40, 240), (120, 230, 120, 255), (10, 60, 20, 255), BLACK).save(os.path.join(out, 'panel_done.png'))

# ---- star (finished) ----
S = 15
star = Image.new('RGBA', (S, S), CLEAR)
pts = []
cx, cy = 7, 7.5
for y in range(S):
    for x in range(S):
        a = math.atan2(y - cy, x - cx)
        r = math.hypot(x - cx, y - cy)
        k = (math.cos(5 * (a + math.pi / 2)) + 1) / 2
        lim = 3.2 + 4.0 * k
        if r <= lim:
            pts.append((x, y))
for (x, y) in pts:
    edge = any((x + dx, y + dy) not in pts for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    star.putpixel((x, y), BLACK if edge else ((255, 246, 150, 255) if y < 7 else (255, 214, 0, 255)))
star.save(os.path.join(out, 'star.png'))

# ---- toggle switch ----
def toggle(on):
    w, h = 22, 11
    im = Image.new('RGBA', (w, h), CLEAR)
    r = h // 2
    for y in range(h):
        for x in range(w):
            cxp = min(max(x, r), w - 1 - r)
            d = math.hypot(x - cxp, y - r)
            if d <= r + 0.2:
                im.putpixel((x, y), BLACK if d > r - 0.8 else ((40, 176, 56, 255) if on else (70, 70, 90, 255)))
    kx = w - 1 - r if on else r
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - kx, y - r)
            if d <= r - 1.2:
                im.putpixel((x, y), BLACK if d > r - 2.2 else ((255, 214, 0, 255) if on else (220, 220, 220, 255)))
    return im
toggle(True).save(os.path.join(out, 'toggle_on.png'))
toggle(False).save(os.path.join(out, 'toggle_off.png'))

# preview
pv = bg.copy().convert('RGBA')
pv = pv.resize((W * 4, H * 4), Image.NEAREST)
def text(img, s, x, y, strip, scale):
    fs = Image.open(os.path.join(out, strip))
    for i, ch in enumerate(s):
        code = ord(ch) - 32
        g = fs.crop((code * 7, 0, code * 7 + 7, 9)).resize((7 * scale, 9 * scale), Image.NEAREST)
        img.alpha_composite(g, (x + i * 6 * scale, y))
text(pv, 'SUNKY', 40, 30, 'font_gold.png', 9)
text(pv, 'PICK A GAME', 44, 120, 'font_white.png', 3)
pn = Image.open(os.path.join(out, 'panel.png')).resize((18 * 10, 18 * 12), Image.NEAREST)
pv.alpha_composite(pn, (60, 200)); pv.alpha_composite(Image.open(os.path.join(out, 'panel_done.png')).resize((180, 216), Image.NEAREST), (270, 200))
pv.alpha_composite(star.resize((60, 60), Image.NEAREST), (390, 210))
pv.alpha_composite(toggle(True).resize((88, 44), Image.NEAREST), (800, 40))
pv.save('/tmp/menu-preview.png')
