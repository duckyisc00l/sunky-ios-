# Draws the all-in-one menu in a 2016 fangame / MS Paint style ("SUNKY COLECTION!!!"), at 3x.
# Usage: python3 ci/menu2016.py <Part 1 info dir (sprites/SunkyStand)> <game icons dir> ios/App/Controls
import random, sys
from PIL import Image, ImageDraw, ImageFont
p1, icons, out = sys.argv[1:4]
COMIC = '/usr/share/fonts/truetype/google-fonts/ofl/comicrelief/ComicRelief-Bold.ttf'
S = 3  # drawn at 3x points
games = ['p1', 'p2', 'p3', 'mpeg', 'tiff', 'g2']
labels = ['Part 1', 'Part 2', 'Part 3', 'Sunky.MPEG', 'Silly.TIFF', 'Sunky 2']
colours = [(255, 80, 80), (255, 170, 40), (255, 222, 0), (200, 0, 0), (255, 120, 200), (80, 160, 255)]

def text(t, size, fill, stroke=0):
    f = ImageFont.truetype(COMIC, size * S)
    b = f.getbbox(t, stroke_width=stroke * S)
    im = Image.new('RGBA', (b[2] + 8 * S, b[3] + 8 * S))
    ImageDraw.Draw(im).text((4 * S, 4 * S), t, font=f, fill=fill, stroke_width=stroke * S, stroke_fill=(0, 0, 0, 255))
    return im.crop(im.getbbox())

# background: flat MS Paint sky with blobby outlined clouds and a grass strip (2.3:1, cropped to fit)
random.seed(5)
W, H = 905 * S, 393 * S
bg = Image.new('RGBA', (W, H), (110, 190, 255, 255)); d = ImageDraw.Draw(bg)
grass = int(H * 0.82)
d.rectangle((0, grass, W, H), fill=(60, 200, 60, 255)); d.line((0, grass, W, grass), fill=(0, 0, 0), width=4 * S)
for cx, cy in [(60, 70), (250, 40), (470, 75), (690, 45), (860, 80)]:
    blobs = [(random.randint(-42, 42), random.randint(-11, 12)) for _ in range(5)]
    for ox, oy in blobs:
        d.ellipse(((cx + ox - 40) * S, (cy + oy - 23) * S, (cx + ox + 40) * S, (cy + oy + 23) * S), fill=(255, 255, 255), outline=(0, 0, 0), width=3 * S)
    for ox, oy in blobs:
        d.ellipse(((cx + ox - 36) * S, (cy + oy - 19) * S, (cx + ox + 36) * S, (cy + oy + 19) * S), fill=(255, 255, 255))
bg.convert('RGB').save(f'{out}/m16_bg.png')

title = text('SUNKY COLECTION!!!', 46, (255, 240, 0, 255), 4).rotate(3, expand=True, resample=Image.BICUBIC)
title.save(f'{out}/m16_title.png')
text('(all of them)', 19, (255, 255, 255, 255), 3).save(f'{out}/m16_sub.png')

# buttons: wonky rounded box, the game's icon and its name; a focused version with a thick yellow edge
BW, BH = 176 * S, 94 * S
for g, label, col in zip(games, labels, colours):
    for focus in (False, True):
        im = Image.new('RGBA', (BW + 12 * S, BH + 12 * S)); bd = ImageDraw.Draw(im)
        if focus:
            bd.rounded_rectangle((0, 0, BW + 11 * S, BH + 11 * S), 18 * S, fill=(255, 255, 0, 255), outline=(0, 0, 0), width=3 * S)
        bd.rounded_rectangle((6 * S, 6 * S, BW + 5 * S, BH + 5 * S), 14 * S, fill=col + (255,), outline=(0, 0, 0), width=4 * S)
        ic = Image.open(f'{icons}/{g}.png').convert('RGBA').resize((62 * S, 62 * S), Image.LANCZOS)
        im.alpha_composite(ic, (16 * S, (BH + 12 * S - ic.height) // 2))
        t = text(label, 22 if len(label) < 8 else 17, (255, 255, 255, 255), 3)
        room = BW - 96 * S
        if t.width > room: t = t.resize((room, int(t.height * room / t.width)), Image.LANCZOS)
        im.alpha_composite(t, (86 * S + (room - t.width) // 2, (BH + 12 * S - t.height) // 2))
        im.save(f'{out}/m16_btn_{g}{"_focus" if focus else ""}.png')

text('DONE!', 18, (0, 220, 0, 255), 3).rotate(-8, expand=True, resample=Image.BICUBIC).save(f'{out}/m16_done.png')

def bubble(msg, name):
    t = text(msg, 17, (0, 0, 0, 255))
    w, h = t.width + 24 * S, t.height + 20 * S
    im = Image.new('RGBA', (w + 4 * S, h + 22 * S)); bd = ImageDraw.Draw(im)
    bd.rounded_rectangle((2 * S, 2 * S, w, h), 12 * S, fill=(255, 255, 255), outline=(0, 0, 0), width=3 * S)
    tail = [(w - 46 * S, h - 3 * S), (w - 22 * S, h - 3 * S), (w - 30 * S, h + 19 * S)]
    bd.polygon(tail, fill=(255, 255, 255)); bd.line([tail[0], tail[2], tail[1]], fill=(0, 0, 0), width=3 * S)
    im.alpha_composite(t, (13 * S, 12 * S))
    im.save(f'{out}/{name}.png')
bubble('pick 1 i guess', 'm16_bubble')
bubble('u beat all of them!!', 'm16_bubble_all')

Image.open(f'{p1}/sprites/SunkyStand_0_128x128.png').convert('RGBA').save(f'{out}/m16_sunky.png')
