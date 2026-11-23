# Draws the "finished" menu card for each game in that game's own style, from its own ending art.
# Usage: python3 ci/finished_cards.py <lab info dir with p1..tiff exports> <g2 txtr dir> ios/App/Controls
# Writes done_<game>.png (300x420, shown at 150x210 points).
import os, sys
from PIL import Image, ImageDraw, ImageFilter
info, g2txtr, out = sys.argv[1:4]
CW, CH = 300, 420
C = out + '/'

def text(t, colour, sc):
    f = Image.open(C + 'font_white.png').convert('RGBA'); cw = f.width // 64
    im = Image.new('RGBA', (len(t) * cw, f.height))
    for i, c in enumerate(t):
        o = ord(c) - 32
        if 0 <= o < 64: im.paste(f.crop((o * cw, 0, o * cw + cw, f.height)), (i * cw, 0))
    p = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = p[x, y]
            if a and r + g + b > 300: p[x, y] = colour
    return im.resize((round(im.width * sc), round(im.height * sc)), Image.NEAREST)

def bgart(g, name):
    return Image.open(f'{info}/{g}/backgrounds/{name}.png').convert('RGBA')

def fit(im, w, h):  # cover-crop to w x h
    s = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
    x, y = (im.width - w) // 2, (im.height - h) // 2
    return im.crop((x, y, x + w, y + h))

def card(fill, frame, pic, name, colour, extra=None, picbox=None, reserve=0):
    c = Image.new('RGBA', (CW, CH), fill if isinstance(fill, tuple) else (0, 0, 0, 255))
    if not isinstance(fill, tuple): c.alpha_composite(fit(fill, CW, CH))
    d = ImageDraw.Draw(c)
    # whole picture, never cropped: as wide as the card allows, height from its shape
    pw = CW - 40; ph = min(CW - 40, round(pw * pic.height / pic.width))
    if ph == CW - 40: pw = round(ph * pic.width / pic.height)
    top = 20 + (CW - 40 - ph) // 2
    bx = picbox or ((CW - pw) // 2, top, (CW - pw) // 2 + pw, top + ph)
    d.rectangle((bx[0] - 4, bx[1] - 4, bx[2] + 3, bx[3] + 3), fill=frame)
    c.alpha_composite(fit(pic, bx[2] - bx[0], bx[3] - bx[1]), (bx[0], bx[1]))
    sc = min(3, (CW - 30) / (len(name) * 7))
    t = text(name, colour, sc)
    c.alpha_composite(t, ((CW - t.width) // 2, (bx[3] + CH - reserve) // 2 - t.height // 2 - 14))
    t2 = text('FINISHED', colour, 2)
    c.alpha_composite(t2, ((CW - t2.width) // 2, (bx[3] + CH - reserve) // 2 + 22))
    if extra: extra(c)
    return c

BLACK = (0, 0, 0, 255)
# Part 1: its "Continued in part 2" screen, black and white with blue lettering
p1 = bgart('p1', 'End_0_640x480').crop((0, 0, 640, 240))
card(BLACK, (255, 255, 255, 255), p1, 'PART 1', (130, 170, 255, 255)).save(C + 'done_p1.png')
# Part 2: "Continued in part 3!" with the grinning faces, yellow
p2 = bgart('p2', 'End_0_640x480').crop((0, 0, 640, 480))
card(BLACK, (255, 220, 0, 255), p2, 'PART 2', (255, 230, 60, 255)).save(C + 'done_p2.png')
# Part 3: THANKS for PLAYING, under the spotlight
p3 = bgart('p3', 'End_0_640x480').crop((0, 0, 640, 480))
fire = bgart('p3', 'Final_Title_Card_0_640x480').crop((0, 200, 640, 480))
card(fire, (255, 200, 0, 255), p3, 'PART 3', (255, 255, 255, 255)).save(C + 'done_p3.png')
# Sunky.MPEG: the stare, red on black with scanlines
def scan(c):
    d = ImageDraw.Draw(c)
    for y in range(0, CH, 4): d.line((0, y, CW, y), fill=(0, 0, 0, 90))
mp = bgart('mpeg', 'Stare_0_640x480').crop((120, 60, 520, 460))
card(BLACK, (170, 0, 0, 255), mp, 'SUNKY.MPEG', (230, 20, 20, 255), scan).save(C + 'done_mpeg.png')
# Silly.TIFF: the pink hearts and its love note
hearts = bgart('tiff', 'Hearts_and_Thangz_Boi_0_1300x1300').crop((0, 0, 600, 840))
tf = bgart('tiff', 'Sunky_0_896x504').crop((0, 150, 896, 350))
card(hearts, (255, 255, 255, 255), tf, 'SILLY.TIFF', (255, 120, 190, 255)).save(C + 'done_tiff.png')
# Sunky the Game 2: its red title border and the APRIL STOOLS! joke
pg = Image.open(f'{g2txtr}/2.png').convert('RGBA')
red = Image.new('RGBA', (CW, CH), (205, 0, 0, 255))
rd = ImageDraw.Draw(red)
for i in range(40): rd.rectangle((i, i, CW - 1 - i, CH - 1 - i), outline=(85 + i * 3, 0, 40 - i, 255))
stools = pg.crop((4, 1690, 430, 1800))
base = Image.new('RGBA', stools.size, (255, 255, 255, 255)); base.alpha_composite(stools); stools = base
title = pg.crop((912, 522, 1362, 782))
def joke(c):
    j = stools.resize((200, round(200 * stools.height / stools.width)), Image.LANCZOS)
    c.alpha_composite(j, ((CW - j.width) // 2, CH - j.height - 22))
card(red, (255, 220, 60, 255), title, 'SUNKY 2', (255, 220, 60, 255), joke, reserve=80).save(C + 'done_g2.png')
