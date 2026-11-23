# Saves the texture pages (PNG) of a GameMaker Studio data.win as <out>/<page>.png
import os, struct, sys
d = open(sys.argv[1], 'rb').read()
out = sys.argv[2]; os.makedirs(out, exist_ok=True)
pos, end = 8, 8 + struct.unpack_from('<I', d, 4)[0]
while pos < end:
    name, size = d[pos:pos + 4].decode(), struct.unpack_from('<I', d, pos + 4)[0]
    if name == 'TXTR':
        chunk = d[pos + 8:pos + 8 + size]
        i, page = 0, 0
        while True:
            i = chunk.find(b'\x89PNG\r\n\x1a\n', i)
            if i < 0: break
            j = chunk.find(b'IEND', i) + 8
            open(os.path.join(out, f'{page}.png'), 'wb').write(chunk[i:j])
            page += 1; i = j
        print(page, 'pages')
    pos += 8 + size
