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
