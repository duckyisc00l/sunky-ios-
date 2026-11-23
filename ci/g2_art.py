# Makes Sunky the Game 2's on-screen text talk about the phone instead of the keyboard, by editing
# its texture pages (Butterscotch loads <Art>/txtr/<page>.png in their place):
#   - warning screen: drops "To switch to full screen, press space, got it?" (it's always full screen)
#     and keeps LooneyDude's "Okay, cool." centred on its line
#   - "PUSH ANY KEY" -> "PRESS START", built from the game's own letters (every copy on every page)
#   - the SHIFT/X and CTRL/Z sign -> JUMP and RUN
# Usage: python3 ci/g2_art.py <dir with extracted pages 0.png..> <out dir>   (writes out/txtr/<n>.png)
import glob, os, sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
os.makedirs(os.path.join(out, 'txtr'), exist_ok=True)
pages = {int(os.path.basename(f)[:-4]): Image.open(f).convert('RGBA') for f in glob.glob(os.path.join(src, '*.png'))}
changed = set()

# ---------- warning screen (page 2) ----------
p = pages[2]
def is_gray(c):
    r, g, b, a = c
    return a > 0 and abs(r - g) < 12 and abs(g - b) < 12 and r > 20
def erase_text(img, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if is_gray(img.getpixel((x, y))):
                img.putpixel((x, y), (0, 0, 0, 255))
# "To" at the end of line 3, and line 4 up to "Okay,"
erase_text(p, (1785, 886, 1803, 900))
okay = p.crop((1692, 902, 1764, 917))
erase_text(p, (1420, 902, 1764, 917))
cx = (1389 + 1795) // 2
nx = cx - okay.width // 2
for y in range(okay.height):
    for x in range(okay.width):
        c = okay.getpixel((x, y))
        if is_gray(c):
            p.putpixel((nx + x, 902 + y), c)
changed.add(2)

# ---------- "PUSH ANY KEY" -> "PRESS START" ----------
# The game's 8x8 letters, from page 2's curtain screen
BG = (33, 0, 49, 255)
def cell(x, y):
    return pages[2].crop((x, y, x + 8, y + 8))
letters = {
    'P': cell(1680, 676), 'U': cell(1688, 676), 'S': cell(1696, 676), 'H': cell(1704, 676),
    'A': cell(1720, 676), 'N': cell(1728, 676), 'Y': cell(1736, 676),
    'E': cell(1672, 628), 'X': cell(1680, 628), 'T': cell(1688, 628), 'R': cell(1696, 628),
}
def text_pixels(img):
    return [(x, y, img.getpixel((x, y))) for y in range(img.height) for x in range(img.width)
            if img.getpixel((x, y))[:3] != BG[:3] and img.getpixel((x, y))[3] > 0]
push_any = pages[2].crop((1680, 676, 1744, 684))
key_row = pages[2].crop((1704, 684, 1728, 692))
tp_push = text_pixels(push_any)
tp_key = text_pixels(key_row)

def find(img, tp, w, h):
    hits = []
    px = img.load()
    first = tp[0]
    for y in range(0, img.height - h):
        for x in range(0, img.width - w):
            if px[x + first[0], y + first[1]] != first[2]:
                continue
            if all(px[x + a, y + b] == c for a, b, c in tp):
                hits.append((x, y))
    return hits

def write(img, word, x, y, bgcol):
    for i, ch in enumerate(word):
        g = letters[ch]
        for yy in range(8):
            for xx in range(8):
                c = g.getpixel((xx, yy))
                img.putpixel((x + i * 8 + xx, y + yy), bgcol if c[:3] == BG[:3] else c)

def blank(img, x0, y0, w, h, tp_cells):
    """Paints the letters' pixels (not the background art) with the colour around them."""
    for a, b, c in tp_cells:
        img.putpixel((x0 + a, y0 + b), img.getpixel((x0 - 1, y0 + b)))

for n, img in pages.items():
    for (x, y) in find(img, tp_push, 64, 8):
        bgcol = img.getpixel((x - 1, y + 3))
        blank(img, x, y, 64, 8, tp_push)
        key_hit = (x + 24, y + 8)
        if all(img.getpixel((key_hit[0] + a, key_hit[1] + b)) == c for a, b, c in tp_key):
            blank(img, key_hit[0], key_hit[1], 24, 8, tp_key)
        centre = x + 32
        write(img, 'PRESS', centre - 20, y, bgcol)
        write(img, 'START', centre - 20, y + 8, bgcol)
        print('PRESS START on page', n, 'at', x, y)
        changed.add(n)

# ---------- the SHIFT/X CTRL/Z sign (page 1) ----------
sign = pages[1]
WHITE = sign.getpixel((1835, 30))
INK = (0, 0, 0, 255)
FONT = {  # 5x7 letters, drawn bold (2px wide strokes) and stretched to 10px tall like the sign's hand lettering
    'J': ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'N': ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
}
ROWS = [0, 0, 1, 2, 2, 3, 4, 4, 5, 6]  # 7 rows stretched to 10
def ink_word(img, word, x0, y0):
    x = x0
    for ch in word:
        g = FONT[ch]
        for yy, r in enumerate(ROWS):
            for xx in range(5):
                if g[r][xx] == '1':
                    img.putpixel((x + xx, y0 + yy), INK)
                    img.putpixel((x + xx + 1, y0 + yy), INK)
        x += 8
def wipe(img, box):
    x0, y0, x1, y1 = box
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c = img.getpixel((x, y))
            if c[0] < 90 and c[1] < 90 and c[2] < 90 and c[3] > 0:  # black ink only
                img.putpixel((x, y), WHITE)
wipe(sign, (1829, 10, 1866, 23))   # SHIFT
wipe(sign, (1841, 43, 1856, 58))   # X
wipe(sign, (1877, 9, 1906, 22))    # CTRL
wipe(sign, (1884, 44, 1900, 59))   # Z
ink_word(sign, 'JUMP', 1832, 12)
ink_word(sign, 'RUN', 1880, 11)
changed.add(1)

for n in sorted(changed):
    pages[n].save(os.path.join(out, 'txtr', f'{n}.png'))
print('wrote pages', sorted(changed))
