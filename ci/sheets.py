# Joins the room sweep's screenshots into one contact sheet per game (rows = rooms, columns = times).
import glob, os, re, sys
from PIL import Image, ImageDraw
d = sys.argv[1]
shots = {}
for f in glob.glob(f'{d}/*-*-*.png'):
    m = re.match(r'(\w+)-(\d+)-(\d+)\.png', os.path.basename(f))
    if m: shots.setdefault(m.group(1), {}).setdefault(int(m.group(2)), {})[int(m.group(3))] = f
for g, rooms in shots.items():
    tw, th = 346, 160
    rs = sorted(rooms)
    for part in range(0, len(rs), 12):
        chunk = rs[part:part + 12]
        sheet = Image.new('RGB', (60 + 4 * (tw + 4), len(chunk) * (th + 4)), (40, 40, 40))
        dr = ImageDraw.Draw(sheet)
        for row, r in enumerate(chunk):
            dr.text((4, row * (th + 4) + 4), str(r), fill=(255, 255, 0))
            for col, t in enumerate(sorted(rooms[r])):
                im = Image.open(rooms[r][t]).convert('RGB'); im.thumbnail((tw, th))
                sheet.paste(im, (60 + col * (tw + 4), row * (th + 4)))
        sheet.save(f'{d}/sheet-{g}-{part // 12}.png')
