# Prints the strings in a GameMaker Studio data.win (STRG chunk), optionally only those matching a regex.
import re, struct, sys
d = open(sys.argv[1], 'rb').read()
pat = re.compile(sys.argv[2], re.I) if len(sys.argv) > 2 else None
pos, end = 8, 8 + struct.unpack_from('<I', d, 4)[0]
while pos < end:
    name, size = d[pos:pos + 4].decode(), struct.unpack_from('<I', d, pos + 4)[0]
    if name == 'STRG':
        b = pos + 8
        for i in range(struct.unpack_from('<I', d, b)[0]):
            off = struct.unpack_from('<I', d, b + 4 + 4 * i)[0]
            s = d[off + 4:off + 4 + struct.unpack_from('<I', d, off)[0]].decode('utf-8', 'replace')
            if pat is None or pat.search(s):
                print(i, repr(s))
    pos += 8 + size
