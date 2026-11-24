# Lists the rooms (with a camera) that place an object showing a full-screen picture: cutscenes,
# fades and overlays, where widescreen has to step aside. Reads gm8info's dump.
# Usage: python3 ci/cutscene_rooms.py <info dir> <game>   ->  "room name" lines
import re, sys, glob
info, g = sys.argv[1], sys.argv[2]
summ = open(f'{info}/{g}/summary.txt', errors='ignore').read()
big = {int(i) for i, w, h in re.findall(r'^SPRITE (\d+) .+? frames \d+ (\d+)x(\d+)', summ, re.M)
       if int(w) >= 600 and int(h) >= 440}
objs = {}
for f in glob.glob(f'{info}/{g}/code/obj_*.gml'):
    m = re.match(r'// object (.+?) sprite (-?\d+)', open(f, errors='ignore').readline())
    oid = int(re.search(r'obj_(\d+)_', f).group(1))
    if m and int(m.group(2)) in big: objs[oid] = m.group(1)
views = {int(r): n for r, n in re.findall(r'^ROOM (\d+) (.+?) \d+x\d+ speed \d+ views true', summ, re.M)}
seen = set()
for r, o in re.findall(r'INST room (\d+) obj (\d+)', summ):
    r, o = int(r), int(o)
    if r in views and o in objs and r not in seen:
        seen.add(r)
        print(r, views[r].replace(' ', '_'), objs[o].replace(' ', '_'))
