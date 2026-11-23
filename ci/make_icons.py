# Builds the menu pictures and app icons from sprites in the games (ci/art/icon_<game>.png).
# Usage: python3 ci/make_icons.py <Games dir for menu pictures> <icon sets dir>
#   writes <Games>/<game>.png, and <icon sets>/<name>/AppIcon.appiconset for "all" and each game.
import json, os, sys
from PIL import Image

ART = os.path.join(os.path.dirname(__file__), 'art')
games_dir, sets_dir = sys.argv[1], sys.argv[2]
GAMES = {  # sprite, background colour, number badge
    'p1': ((13, 31, 115), '1'),
    'p2': ((13, 31, 115), '2'),
    'p3': ((13, 31, 115), '3'),
    'mpeg': ((110, 0, 0), None),
    'tiff': ((88, 30, 130), None),
    'g2': ((92, 148, 252), '2'),   # Super Mario sky, it's a Mario parody
}
DIGITS = {
    '1': ["0110", "1110", "0110", "0110", "0110", "0110", "1111"],
    '2': ["1110", "0001", "0001", "0110", "1000", "1000", "1111"],
    '3': ["1110", "0001", "0001", "0110", "0001", "0001", "1110"],
}

def trimmed(name):
    im = Image.open(os.path.join(ART, f'icon_{name}.png')).convert('RGBA')
    return im.crop(im.getbbox())

def badge(icon, digit):
    """Big gold pixel number, bottom right, black outline."""
    rows = DIGITS[digit]
    px = 36
    w, h = len(rows[0]) * px, len(rows) * px
    x0, y0 = 1024 - w - 70, 1024 - h - 60
    def put(x, y, col):
        for yy in range(y, y + px):
            for xx in range(x, x + px):
                icon.putpixel((xx, yy), col)
    for o in range(-2, 3):  # outline
        for r, row in enumerate(rows):
            for c, b in enumerate(row):
                if b == '1':
                    for dx, dy in ((o, 0), (0, o), (o, o), (o, -o)):
                        x, y = x0 + c * px + dx * 12, y0 + r * px + dy * 12
                        if 0 <= x and x + px <= 1024 and 0 <= y and y + px <= 1024:
                            put(x, y, (0, 0, 0, 255))
    for r, row in enumerate(rows):
        for c, b in enumerate(row):
            if b == '1':
                put(x0 + c * px, y0 + r * px, (255, 214, 0, 255) if r < 4 else (255, 160, 0, 255))

def icon(sprite, bg, digit):
    im = Image.new('RGBA', (1024, 1024), bg + (255,))
    scale = max(1, min(860 // sprite.width, 860 // sprite.height))
    big = sprite.resize((sprite.width * scale, sprite.height * scale), Image.NEAREST)
    im.alpha_composite(big, ((1024 - big.width) // 2, (1024 - big.height) // 2 + 20))
    if digit:
        badge(im, digit)
    return im.convert('RGB')

def write_set(name, im):
    d = os.path.join(sets_dir, name, 'AppIcon.appiconset')
    os.makedirs(d, exist_ok=True)
    im.save(os.path.join(d, 'icon-1024.png'))
    json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
               "info": {"author": "xcode", "version": 1}}, open(os.path.join(d, 'Contents.json'), 'w'))

os.makedirs(games_dir, exist_ok=True)
for g, (bg, digit) in GAMES.items():
    sp = trimmed(g)
    sp.save(os.path.join(games_dir, g + '.png'))        # menu card picture
    write_set(g, icon(sp, bg, digit))                     # single-game app icon
write_set('all', icon(trimmed('p1'), GAMES['p1'][0], None))  # the all-in-one app

# preview
prev = Image.new('RGB', (7 * 180, 180), (30, 30, 30))
for i, n in enumerate(['all', 'p1', 'p2', 'p3', 'mpeg', 'tiff', 'g2']):
    prev.paste(Image.open(os.path.join(sets_dir, n, 'AppIcon.appiconset', 'icon-1024.png')).resize((170, 170)), (i * 180 + 5, 5))
prev.save('/tmp/icons-preview.png')
