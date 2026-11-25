# Draws the "minimal outlines" on-screen controls (style D, chosen by Jordan): thin white rings and
# labels that barely cover the game, with a faint dark edge so they still show on white screens.
# Drawn at 3x the size they appear (in points), so they stay sharp. Usage: python3 ci/controls_minimal.py ios/App/Controls
import os, sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

out = sys.argv[1]
S = 3  # pixels per point
FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

def canvas(w, h):
    return Image.new('RGBA', (w * S, h * S), (0, 0, 0, 0))

def shadowed(draw_fn, w, h):
    # the shape in white, over a soft dark copy so it shows on bright screens too
    shape = canvas(w, h); draw_fn(ImageDraw.Draw(shape), (255, 255, 255))
    dark = canvas(w, h); draw_fn(ImageDraw.Draw(dark), (0, 0, 0))
    dark = dark.filter(ImageFilter.GaussianBlur(2.5 * S))
    a = dark.split()[3].point(lambda v: v * 0.35)
    dark.putalpha(a)
    return Image.alpha_composite(dark, shape)

def ring(d, c, box, width, alpha, fill_alpha=0):
    if fill_alpha:
        d.ellipse(box, fill=c + (fill_alpha,))
    d.ellipse(box, outline=c + (alpha,), width=width)

def label(d, c, text, cx, cy, size, alpha):
    f = ImageFont.truetype(FONT, size)
    l, t, r, b = d.textbbox((0, 0), text, font=f)
    d.text((cx - (r - l) / 2 - l, cy - (b - t) / 2 - t), text, font=f, fill=c + (alpha,))

def save(img, name):
    img.save(os.path.join(out, name + '.png'))

# joystick well: 148 pt
W = 148
save(shadowed(lambda d, c: ring(d, c, (4 * S, 4 * S, (W - 4) * S, (W - 4) * S), int(2.5 * S), 120), W, W), 'stick_base')
# knob: 64 pt, a little brighter while pushed
K = 64
save(shadowed(lambda d, c: ring(d, c, (3 * S, 3 * S, (K - 3) * S, (K - 3) * S), 2 * S, 160, 70), K, K), 'stick_knob')
save(shadowed(lambda d, c: ring(d, c, (3 * S, 3 * S, (K - 3) * S, (K - 3) * S), 2 * S, 220, 120), K, K), 'stick_knob_on')
# round buttons: 92 pt
B = 92
for name, text in [('jump', 'JUMP'), ('run', 'RUN')]:
    for on in (False, True):
        def draw(d, c, text=text, on=on):
            ring(d, c, (4 * S, 4 * S, (B - 4) * S, (B - 4) * S), int(2.5 * S), 220 if on else 135, 70 if on else 0)
            label(d, c, text, B * S / 2, B * S / 2, 19 * S, 235 if on else 175)
        save(shadowed(draw, B, B), name + ('_on' if on else ''))
# START: a pill, 104 x 34 pt
PW, PH = 104, 34
for on in (False, True):
    def draw(d, c, on=on):
        d.rounded_rectangle((3 * S, 3 * S, (PW - 3) * S, (PH - 3) * S), radius=(PH - 6) * S // 2,
                            outline=c + (210 if on else 115,), width=2 * S, fill=c + (60,) if on else None)
        label(d, c, 'START', PW * S / 2, PH * S / 2, 15 * S, 230 if on else 165)
    save(shadowed(draw, PW, PH), 'start' + ('_on' if on else ''))
