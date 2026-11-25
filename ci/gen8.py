# Prints the chunks and GEN8 header of a GameMaker Studio data.win
import struct, sys
d = open(sys.argv[1], 'rb').read()
assert d[:4] == b'FORM', 'not a FORM file'
pos, end = 8, 8 + struct.unpack_from('<I', d, 4)[0]
while pos < end:
    name, size = d[pos:pos+4].decode(), struct.unpack_from('<I', d, pos + 4)[0]
    print(name, size)
    if name == 'GEN8':
        b = pos + 8
        dbg, bc = d[b], d[b+1]
        ver = struct.unpack_from('<4I', d, b + 0x2c)
        w, h = struct.unpack_from('<2I', d, b + 0x3c)
        print(f'  bytecode {bc} debug {dbg} version_field {ver} window {w}x{h}')
    pos += 8 + size

# Rooms (GameMaker: Studio 1): size, views and backgrounds, for widescreen checks
def s(p):
    if p == 0: return ''
    n = struct.unpack_from('<I', d, p - 4)[0]
    return d[p:p+n].decode('utf-8', 'replace')
def u(p): return struct.unpack_from('<I', d, p)[0]
def i(p): return struct.unpack_from('<i', d, p)[0]
pos = 8
while pos < end:
    name, size = d[pos:pos+4].decode(), u(pos + 4)
    if name == 'ROOM':
        n = u(pos + 8)
        for k in range(n):
            r = u(pos + 12 + 4 * k)
            w, h = u(r + 8), u(r + 12)
            colour, flags = u(r + 24), u(r + 36)
            bgl, vwl = u(r + 40), u(r + 44)
            bgs = []
            for j in range(u(bgl)):
                b = u(bgl + 4 + 4 * j)
                en, fg, idx, x, y, tx, ty, sx, sy, st = struct.unpack_from('<IIiiiIIiiI', d, b)
                if en: bgs.append(f'bg{idx}{" fg" if fg else ""} at {x},{y}{" tileX" if tx else ""}{" tileY" if ty else ""}{" stretch" if st else ""}{f" speed {sx},{sy}" if sx or sy else ""}')
            views = []
            for j in range(u(vwl)):
                v = u(vwl + 4 + 4 * j)
                en, vx, vy, vw, vh = struct.unpack_from('<Iiiii', d, v)
                if en: views.append(f'{vw}x{vh}')
            print(f'room {k} {s(u(r))} {w}x{h} views {",".join(views) or "-"} colour {colour:08x} {"; ".join(bgs)}')
    pos += 8 + size
