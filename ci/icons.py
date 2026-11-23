# Makes the menu pictures (Games/<name>.png) and the app icon from the games' own .ico files.
# Usage: python3 ci/icons.py <info dir> <Games dir> <AppIcon.appiconset dir>
import json, os, sys
from PIL import Image

info, games_dir, iconset = sys.argv[1:4]
os.makedirs(games_dir, exist_ok=True)
os.makedirs(iconset, exist_ok=True)

def biggest(path):
    ico = Image.open(path)
    sizes = sorted(ico.info.get('sizes', [ico.size]), key=lambda s: s[0] * s[1])
    ico.size = sizes[-1]
    return ico.convert('RGBA')

app_icon = None
for name in sorted(os.listdir(info)):
    p = os.path.join(info, name, 'icon.ico')
    if not os.path.isfile(p):
        continue
    try:
        im = biggest(p)
    except Exception as e:
        print('icon failed', name, e); continue
    im.save(os.path.join(games_dir, name + '.png'))
    print(name, im.size)
    if name == 'p1':
        app_icon = im

if app_icon is None:
    app_icon = Image.new('RGBA', (64, 64), (255, 255, 255, 0))
# Opaque 1024 icon: the game's icon, scaled with hard pixels, on Sunky blue
bg = Image.new('RGBA', (1024, 1024), (13, 31, 115, 255))
scale = max(1, 820 // max(app_icon.size))
big = app_icon.resize((app_icon.size[0] * scale, app_icon.size[1] * scale), Image.NEAREST)
bg.alpha_composite(big, ((1024 - big.size[0]) // 2, (1024 - big.size[1]) // 2))
bg.convert('RGB').save(os.path.join(iconset, 'icon-1024.png'))
json.dump({"images": [{"filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
           "info": {"author": "xcode", "version": 1}}, open(os.path.join(iconset, 'Contents.json'), 'w'))
