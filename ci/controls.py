# Draws the retro (Sonic-style) on-screen controls as small pixel-art PNGs.
# The app scales them up with hard pixels. Usage: python3 ci/controls.py ios/App/Controls
import os, sys
from PIL import Image

out = sys.argv[1]
os.makedirs(out, exist_ok=True)

BLACK = (12, 12, 28, 255)
BLUE = (28, 64, 214, 255)
BLUE_LIGHT = (86, 132, 255, 255)
BLUE_DARK = (12, 34, 130, 255)
YELLOW = (255, 214, 0, 255)
YELLOW_LIGHT = (255, 246, 150, 255)
ORANGE = (230, 130, 0, 255)
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

# 5x7 pixel font for the few letters needed
FONT = {
    'A': ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    'S': ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    'T': ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    'R': ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    'J': ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
    'U': ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    'M': ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    'P': ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    'X': ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    'N': ["10001", "11001", "10101", "10011", "10001", "10001", "10001"],
}

def text(im, s, x, y, colour, outline=BLACK):
    """Draws text with a 1px outline."""
    pts = []
    cx = x
    for ch in s:
        for r, row in enumerate(FONT[ch]):
            for c, bit in enumerate(row):
                if bit == '1':
                    pts.append((cx + c, y + r))
        cx += 6
    for (px, py) in pts:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                q = (px + dx, py + dy)
                if 0 <= q[0] < im.width and 0 <= q[1] < im.height and q not in pts:
                    im.putpixel(q, outline)
    for p in pts:
        im.putpixel(p, colour)

def text_width(s):
    return len(s) * 6 - 1

# ---- D-pad: a 33x33 cross, arms 11 wide ----
N, ARM = 33, 11
def in_cross(x, y):
    return (ARM <= x < 2 * ARM) or (ARM <= y < 2 * ARM)

def dpad(lit=None):
    im = Image.new('RGBA', (N, N), CLEAR)
    for y in range(N):
        for x in range(N):
            if not in_cross(x, y):
                continue
            edge = any(not (0 <= x + dx < N and 0 <= y + dy < N and in_cross(x + dx, y + dy))
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            arm = None
            if ARM <= x < 2 * ARM and y < ARM: arm = 'up'
            elif ARM <= x < 2 * ARM and y >= 2 * ARM: arm = 'down'
            elif x < ARM and ARM <= y < 2 * ARM: arm = 'left'
            elif x >= 2 * ARM and ARM <= y < 2 * ARM: arm = 'right'
            hot = arm is not None and arm == lit
            if edge:
                c = BLACK
            else:
                # bevel: light top-left, dark bottom-right
                left_edge = not in_cross(x - 2, y) or not in_cross(x, y - 2)
                right_edge = not in_cross(x + 2, y) or not in_cross(x, y + 2)
                if hot:
                    c = YELLOW_LIGHT if left_edge else ORANGE if right_edge else YELLOW
                else:
                    c = BLUE_LIGHT if left_edge else BLUE_DARK if right_edge else BLUE
            im.putpixel((x, y), c)
    # centre dimple
    for y in range(14, 19):
        for x in range(14, 19):
            im.putpixel((x, y), BLUE_DARK)
    # arrows (white, outlined)
    def tri(cx, cy, d):
        hot = (d == lit)
        rim = ORANGE if hot else BLUE_DARK
        pts = []
        for i in range(3):
            for j in range(-i, i + 1):
                if d == 'up': pts.append((cx + j, cy - 2 + i))
                if d == 'down': pts.append((cx + j, cy + 2 - i))
                if d == 'left': pts.append((cx - 2 + i, cy + j))
                if d == 'right': pts.append((cx + 2 - i, cy + j))
        for (px, py) in pts:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (px + dx, py + dy)
                    if q not in pts and im.getpixel(q)[3] and im.getpixel(q) != BLACK:
                        im.putpixel(q, rim)
        for p in pts:
            im.putpixel(p, WHITE)
    tri(16, 6, 'up'); tri(16, 26, 'down'); tri(6, 16, 'left'); tri(26, 16, 'right')
    return im

# (the D-pad above is kept for reference; the app uses the joystick below)

# ---- JUMP: a gold Sonic ring with JUMP inside ----
def ring(pressed, label='JUMP'):
    S = 31
    im = Image.new('RGBA', (S, S), CLEAR)
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= 15.2:
                if d > 14.2: col = BLACK
                elif d > 10.8:
                    # gold band, light upper-left, orange lower-right
                    shade = (x - c) + (y - c)
                    col = YELLOW_LIGHT if shade < -10 else ORANGE if shade > 9 else YELLOW
                    if pressed: col = WHITE if shade < -10 else YELLOW
                elif d > 9.8: col = BLACK
                else: col = BLUE_DARK if pressed else BLUE
                im.putpixel((x, y), col)
    # sparkle
    for p in ((7, 6), (6, 7), (7, 7), (8, 7), (7, 8)):
        im.putpixel(p, WHITE)
    text(im, label, (S - text_width(label)) // 2, 12, WHITE)
    return im

ring(False).save(os.path.join(out, 'jump.png'))
ring(True).save(os.path.join(out, 'jump_on.png'))
ring(False, 'RUN').save(os.path.join(out, 'run.png'))
ring(True, 'RUN').save(os.path.join(out, 'run_on.png'))

# ---- START: a small blue pill ----
def pill(label, pressed, w=39, h=13):
    im = Image.new('RGBA', (w, h), CLEAR)
    r = h // 2
    for y in range(h):
        for x in range(w):
            cx = min(max(x, r), w - 1 - r)
            d = ((x - cx) ** 2 + (y - r) ** 2) ** 0.5
            if d <= r + 0.2:
                if d > r - 0.8: col = BLACK
                else:
                    col = (YELLOW if pressed else BLUE) if y > 2 else (YELLOW_LIGHT if pressed else BLUE_LIGHT)
                    if y >= h - 3: col = ORANGE if pressed else BLUE_DARK
                im.putpixel((x, y), col)
    text(im, label, (w - text_width(label)) // 2, 3, WHITE)
    return im

pill('START', False).save(os.path.join(out, 'start.png'))
pill('START', True).save(os.path.join(out, 'start_on.png'))

# ---- close: small blue square with an X ----
def close():
    im = Image.new('RGBA', (13, 13), CLEAR)
    for y in range(13):
        for x in range(13):
            edge = x in (0, 12) or y in (0, 12)
            corner = (x in (0, 12)) and (y in (0, 12))
            if corner: continue
            im.putpixel((x, y), BLACK if edge else (BLUE_LIGHT if y < 3 else BLUE))
    text(im, 'X', 4, 3, WHITE)
    return im

close().save(os.path.join(out, 'close.png'))

# preview sheet for checking
sheet = Image.new('RGBA', (200, 60), (60, 60, 60, 255))
for i, n in enumerate(['jump', 'jump_on']):
    sheet.alpha_composite(Image.open(os.path.join(out, n + '.png')), (i * 36 + 2, 2))
sheet.alpha_composite(Image.open(os.path.join(out, 'start.png')), (150, 5))
sheet.alpha_composite(Image.open(os.path.join(out, 'start_on.png')), (150, 22))
sheet.alpha_composite(Image.open(os.path.join(out, 'close.png')), (150, 40))
sheet.resize((800, 240), Image.NEAREST).save('/tmp/controls-preview.png')

# ---- Joystick: a round blue base and a gold ball that follows the thumb ----
def joystick_base():
    S = 41
    im = Image.new('RGBA', (S, S), CLEAR)
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= 20.2:
                if d > 19.2: col = BLACK
                elif d > 16.5:
                    shade = (x - c) + (y - c)
                    col = BLUE_LIGHT if shade < -12 else BLUE_DARK if shade > 12 else BLUE
                elif d > 15.5: col = BLACK
                else: col = (16, 40, 150, 255)  # well
                im.putpixel((x, y), col)
    # small arrow ticks on the rim
    for (px, py) in [(20, 2), (19, 3), (20, 3), (21, 3), (20, 38), (19, 37), (20, 37), (21, 37),
                     (2, 20), (3, 19), (3, 20), (3, 21), (38, 20), (37, 19), (37, 20), (37, 21)]:
        im.putpixel((px, py), WHITE)
    return im

def joystick_knob(pressed):
    S = 19
    im = Image.new('RGBA', (S, S), CLEAR)
    c = (S - 1) / 2
    for y in range(S):
        for x in range(S):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= 9.2:
                if d > 8.2: col = BLACK
                else:
                    shade = (x - c) + (y - c)
                    col = YELLOW_LIGHT if shade < -6 else ORANGE if shade > 5 else YELLOW
                    if pressed and shade >= -6: col = YELLOW_LIGHT if shade < 0 else YELLOW
                im.putpixel((x, y), col)
    for p in ((5, 5), (6, 5), (5, 6)):
        im.putpixel(p, WHITE)
    return im

joystick_base().save(os.path.join(out, 'stick_base.png'))
joystick_knob(False).save(os.path.join(out, 'stick_knob.png'))
joystick_knob(True).save(os.path.join(out, 'stick_knob_on.png'))
prev = Image.new('RGBA', (90, 45), (60, 60, 60, 255))
prev.alpha_composite(joystick_base(), (2, 2)); prev.alpha_composite(joystick_knob(False), (13, 13))
prev.alpha_composite(joystick_base(), (46, 2)); prev.alpha_composite(joystick_knob(True), (63, 9))
prev.resize((540, 270), Image.NEAREST).save('/tmp/stick-preview.png')
