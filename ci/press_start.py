# Makes "PRESS START" from the games' own "PRESS ENTER" sprite: the S, T and R are LooneyDude's own
# letters, the A is drawn in the same banded colours, and everything gets the same black outline.
# Usage: python3 ci/press_start.py ci/art/press_enter_original.png <out dir for frames>
import os, sys
from PIL import Image

src = Image.open(sys.argv[1]).convert('RGBA')
out = sys.argv[2]
W, H = src.size

def colored(x, y):
    r, g, b, a = src.getpixel((x, y))
    return a > 0 and (r, g, b) != (0, 0, 0)

# letter fills in the original (x ranges of coloured pixels)
LETTERS = {'S': (59, 70), 'T': (145, 158), 'R': (182, 193)}

def fill_mask(x0, x1):
    return [[colored(x, y) for x in range(x0, x1 + 1)] for y in range(H)]

# rows -> band colour, taken from the original
band = {}
for y in range(H):
    for x in range(W):
        if colored(x, y):
            band[y] = src.getpixel((x, y)); break

def a_mask(w=15):
    m = [[False] * w for _ in range(H)]
    c = (w - 1) / 2
    for y in range(3, 29):
        t = (y - 3) / 25
        half = 1.5 + t * (w / 2 - 1.5)
        for x in range(w):
            d = abs(x - c)
            leg = half - 4.2 <= d <= half
            apex = y <= 6 and d <= half
            bar = 17 <= y <= 19 and d <= half
            if leg or apex or bar:
                m[y][x] = True
    return m

glyphs = [fill_mask(*LETTERS['S']), fill_mask(*LETTERS['T']), a_mask(), fill_mask(*LETTERS['R']), fill_mask(*LETTERS['T'])]

img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
# keep "PRESS " (everything left of the original ENTER, outline included)
for y in range(H):
    for x in range(0, 100):
        img.putpixel((x, y), src.getpixel((x, y)))

fill = [[False] * W for _ in range(H)]
x = 111
for g in glyphs:
    w = len(g[0])
    for yy in range(H):
        for xx in range(w):
            if g[yy][xx] and x + xx < W - 3:
                fill[yy][x + xx] = True
    x += w + 4

# outline: everything within ~3 px of a fill pixel turns black (rounded)
R = 3
for y in range(H):
    for xx in range(100, W):
        if fill[y][xx]:
            continue
        near = False
        for dy in range(-R, R + 1):
            for dx in range(-R, R + 1):
                if dx * dx + dy * dy <= R * R + 1:
                    yy, x2 = y + dy, xx + dx
                    if 0 <= yy < H and 0 <= x2 < W and fill[yy][x2]:
                        near = True; break
            if near: break
        if near:
            img.putpixel((xx, y), (0, 0, 0, 255))
for y in range(H):
    for xx in range(100, W):
        if fill[y][xx]:
            img.putpixel((xx, y), band.get(y, (255, 255, 255, 255)))

os.makedirs(out, exist_ok=True)
for i in range(20):  # frames 20-38 are the blank half of the blink: unchanged
    img.save(os.path.join(out, f'{i}.png'))
prev = Image.new('RGBA', (W, H * 2 + 4), (40, 90, 200, 255))
prev.alpha_composite(src, (0, 0)); prev.alpha_composite(img, (0, H + 4))
prev.resize((W * 4, (H * 2 + 4) * 4), Image.NEAREST).save('/tmp/press_start_preview.png')
