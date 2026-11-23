# Converts the raw sprite dumps from gm8info (name_frame_WxH.raw, BGRA) to PNG.
import glob, os, re, sys
from PIL import Image
for f in glob.glob(os.path.join(sys.argv[1], '**', '*.raw'), recursive=True):
    w, h = map(int, re.search(r'_(\d+)x(\d+)\.raw$', f).groups())
    data = open(f, 'rb').read()
    if len(data) != w * h * 4:
        print('size mismatch', f); continue
    Image.frombytes('RGBA', (w, h), data, 'raw', 'BGRA').save(f[:-4] + '.png')
    os.remove(f)
