# The all-in-one menu dresses up as the next game you haven't finished: its title logo and its
# background. Draws theme_<game>_bg.png (1280x480) and theme_<game>_logo.png from each game's art.
# Usage: python3 ci/menu_themes.py <lab info dir> <g2 txtr dir> ios/App/Controls
import sys
from PIL import Image, ImageDraw, ImageFilter
info, g2txtr, out = sys.argv[1:4]
W, H = 1280, 480

def bg(g, n): return Image.open(f'{info}/{g}/backgrounds/{n}.png').convert('RGBA')
def sp(g, n): return Image.open(f'{info}/{g}/sprites/{n}.png').convert('RGBA')
def tile(im, w=W, h=H, y=0):
    c = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for x in range(0, w, im.width): c.alpha_composite(im, (x, y))
    return c
def cover(im, w=W, h=H):
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))
def sky(top, bottom):
    c = Image.new('RGBA', (W, H)); d = ImageDraw.Draw(c)
    for y in range(H):
        t = min(1, y / (H * 0.6))
        d.line((0, y, W, y), fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    return c
def emblem(g, inner, at=(145, -115)):
    e = bg(g, 'Emblem_0_590x370')
    c = Image.new('RGBA', (590, 485), (0, 0, 0, 0))
    c.alpha_composite(e, (0, 115))
    c.alpha_composite(inner, at)
    c.alpha_composite(e.crop((0, 185, 590, 370)), (0, 300))  # the ribbon goes over the character
    return c.crop(c.getbbox())
def save(g, back, logo):
    back.convert('RGB').save(f'{out}/theme_{g}_bg.png')
    logo.save(f'{out}/theme_{g}_logo.png')

# Part 1: blue sky, clouds and mountains; thumbs-up Sunky in the emblem
b = sky((40, 120, 230), (110, 190, 255))
b.alpha_composite(tile(bg('p1', 'Clouds_0_352x194'), y=10))
b.alpha_composite(tile(bg('p1', 'Mountains_0_640x600'), y=-90))
save('p1', b, emblem('p1', sp('p1', 'Title_55_300x300'), (145, -30)))

# Part 2: the same hills at sunset; the big Sunky pose in the emblem
b = sky((255, 120, 60), (255, 200, 120))
b.alpha_composite(tile(bg('p2', 'Clouds_2_0_352x194'), y=10))
b.alpha_composite(tile(bg('p2', 'Mountains_0_640x600'), y=-90))
big = bg('p2', 'Sunky_0_369x356').resize((300, 289), Image.LANCZOS)
save('p2', b, emblem('p2', big, (145, 10)))

# Part 3: the night palms and stars; the flaming FINAL LEVEL title
b = tile(bg('p3', 'BG_2_0_640x480'))
fl = bg('p3', 'Final_Title_Card_0_640x480')
title = fl.crop((60, 0, 580, 110))
px = title.load()  # the lettering sits on black: make the black see-through
for y in range(title.height):
    for x in range(title.width):
        r, g_, b_, a = px[x, y]
        m = max(r, g_, b_)
        if m < 60: px[x, y] = (r, g_, b_, max(0, (m - 20) * 6))
logo = Image.new('RGBA', (560, 400), (0, 0, 0, 0))
e = emblem('p1', sp('p1', 'Title_55_300x300'), (145, -30)).resize((440, 339), Image.LANCZOS)
logo.alpha_composite(e, (60, 0)); logo.alpha_composite(title.resize((540, 114)), (10, 290))
save('p3', b, logo.crop(logo.getbbox()))

# Sunky.MPEG: SUNKY THE EVIL on the purple dark
b = cover(bg('mpeg', 'Dark_0_1709x800'))
evil = sp('mpeg', 'SUNKY____0_640x480')
m = Image.new('L', evil.size, 0); ImageDraw.Draw(m).rounded_rectangle((0, 0, evil.width - 1, evil.height - 1), 18, fill=255)
evil.putalpha(m)
fr = Image.new('RGBA', (evil.width + 16, evil.height + 16), (0, 0, 0, 0))
ImageDraw.Draw(fr).rounded_rectangle((0, 0, fr.width - 1, fr.height - 1), 24, fill=(150, 0, 0, 255))
fr.alpha_composite(evil, (8, 8))
save('mpeg', b, fr)

# Silly.TIFF: pink sky and the Silly.TIFF emblem with Amy
b = sky((255, 140, 200), (255, 210, 235))
b.alpha_composite(tile(bg('tiff', 'Clouds_0_352x194'), y=10))
b.alpha_composite(tile(bg('tiff', 'Mountains_0_640x600'), y=-90))
save('tiff', b, emblem('tiff', sp('tiff', 'Title_10_300x300'), (145, -30)))

# Sunky the Game 2: red curtain glow and its own title card
pg = Image.open(f'{g2txtr}/2.png').convert('RGBA')
b = Image.new('RGBA', (W, H), (120, 0, 0, 255)); d = ImageDraw.Draw(b)
for i in range(H // 2):
    d.rectangle((i * 2, i, W - 1 - i * 2, H - 1 - i), outline=(90 + min(i, 60) * 2, 0, 0, 255))
save('g2', b, pg.crop((990, 550, 1282, 766)))
