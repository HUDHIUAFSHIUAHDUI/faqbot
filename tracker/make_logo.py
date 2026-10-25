"""Draw the tracker's NCC emblem (no text) as logo.svg.

A dark disc with gold rings and four small shields, and a detailed gold tree
with branching limbs, leaf clusters and spreading roots, after the team logo.
Seeded so the drawing is the same every build.
"""
import math
import pathlib
import random

rng = random.Random(7)
CX, GROUND = 60.0, 80.0
branches, leaves, roots = [], [], []


def f(v):
    return ('%.1f' % v).rstrip('0').rstrip('.')


def limb(x, y, ang, length, width, depth):
    x2 = x + math.cos(ang) * length
    y2 = y - math.sin(ang) * length
    # slight curve: control point pushed sideways
    mx, my = (x + x2) / 2, (y + y2) / 2
    bend = rng.uniform(-0.18, 0.18) * length
    cx, cy = mx + math.cos(ang + math.pi / 2) * bend, my - math.sin(ang + math.pi / 2) * bend
    branches.append((width, 'M%s %sQ%s %s %s %s' % (f(x), f(y), f(cx), f(cy), f(x2), f(y2))))
    if depth == 0 or length < 1.8:
        for _ in range(rng.randint(2, 3)):
            r = rng.uniform(0.8, 2.2)
            a = rng.uniform(0, 2 * math.pi)
            leaves.append((x2 + math.cos(a) * r, y2 - math.sin(a) * r, rng.uniform(0.55, 0.95), rng.random()))
        return
    n = 2 if depth > 3 else rng.choice([2, 2, 3])
    spread = rng.uniform(0.45, 0.7)
    for i in range(n):
        t = (i / (n - 1) - 0.5) if n > 1 else 0
        na = ang + t * 2 * spread + rng.uniform(-0.12, 0.12)
        limb(x2, y2, na, length * rng.uniform(0.7, 0.8), width * 0.62, depth - 1)


def root(x, y, ang, length, width, depth):
    x2 = x + math.cos(ang) * length
    y2 = y + math.sin(ang) * length * 0.45
    mx, my = (x + x2) / 2, (y + y2) / 2 + length * 0.12
    roots.append((width, 'M%s %sQ%s %s %s %s' % (f(x), f(y), f(mx), f(my), f(x2), f(y2))))
    if depth == 0:
        return
    for d in (-0.4, 0.35):
        root(x2, y2, ang + d + rng.uniform(-0.1, 0.1), length * 0.64, width * 0.6, depth - 1)


# Draw the left half of the tree, then mirror it so the tree is balanced like the logo.
for ang, ln in ((math.pi / 2 + 0.12, 10), (math.pi / 2 + 0.7, 11), (math.pi / 2 + 1.2, 9.5)):
    limb(CX, 58, ang, ln, 1.9, 6)
for ang in (math.pi - 0.05, math.pi - 0.35, math.pi - 0.75):
    root(CX, GROUND + 1, ang, 12, 1.4, 3)

def mirror(d):
    nums = d.replace('M', ' M ').replace('Q', ' Q ').split()
    out, k = [], 0
    for t in nums:
        if t in ('M', 'Q'):
            out.append(t); k = 0; continue
        out.append(f(120 - float(t)) if k % 2 == 0 else t); k += 1
    return ''.join(x if x in ('M', 'Q') else x + ' ' for x in out).replace(' Q', 'Q').strip()

branches += [(w, mirror(d)) for w, d in branches]
roots += [(w, mirror(d)) for w, d in roots]
leaves += [(120 - x, y, r, sh) for x, y, r, sh in leaves]
branches.insert(0, (3.2, 'M%s %sC%s %s %s %s %s %s' % (f(CX), f(GROUND + 2), f(CX - 1.2), f(70), f(CX + 1.2), f(64), f(CX), f(57))))

# round canopy, inside the inner circle
leaves = [l for l in leaves if math.hypot(l[0] - 60, (l[1] - 43) * 1.15) < 33 and math.hypot(l[0] - 60, l[1] - 60) < 44]

out = ['<svg class="logo" viewBox="0 0 120 120" role="img" aria-label="National Closers Collective">',
       '<defs><linearGradient id="ncc-gold" x1="0" y1="0" x2="1" y2="1">'
       '<stop offset="0" stop-color="#f3d98a"/><stop offset=".55" stop-color="#c99a3b"/><stop offset="1" stop-color="#7f5c1d"/></linearGradient>'
       '<radialGradient id="ncc-glow" cx=".5" cy=".42" r=".55"><stop offset="0" stop-color="#2a2318"/><stop offset="1" stop-color="#110f0c"/></radialGradient></defs>',
       '<circle cx="60" cy="60" r="58" fill="#0b0a08" stroke="url(#ncc-gold)" stroke-width="2"/>',
       '<circle cx="60" cy="60" r="55" fill="none" stroke="url(#ncc-gold)" stroke-width=".7" opacity=".8"/>',
       '<circle cx="60" cy="60" r="47" fill="url(#ncc-glow)" stroke="url(#ncc-gold)" stroke-width="1.4"/>']
# four small shields in the band, like the team logo
for deg in (-50, 50, 130, 230):
    a = math.radians(deg - 90)
    x, y = 60 + math.cos(a) * 51.2, 60 + math.sin(a) * 51.2
    out.append('<path transform="translate(%s %s)" d="M-2.2-2.4h4.4v2.2c0 1.8-1.2 2.9-2.2 3.4-1-.5-2.2-1.6-2.2-3.4z" fill="none" stroke="#c99a3b" stroke-width=".6"/>' % (f(x), f(y)))
out.append('<g fill="none" stroke="url(#ncc-gold)" stroke-linecap="round">')
for w, d in roots + branches:
    out.append('<path d="%s" stroke-width="%s"/>' % (d, f(max(w, 0.35))))
out.append('</g><g>')
for x, y, r, shade in leaves:
    color = '#f0d27c' if shade > 0.66 else '#c99a3b' if shade > 0.3 else '#94702a'
    out.append('<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (f(x), f(y), f(r), color))
out.append('</g>')
out.append('<path d="M38 %sh44" stroke="url(#ncc-gold)" stroke-width=".7" opacity=".5"/>' % f(GROUND + 1))
out.append('</svg>')

here = pathlib.Path(__file__).parent
svg = ''.join(out)
(here / 'logo.svg').write_text(svg, encoding='utf-8')
print('logo.svg', len(svg), 'bytes,', len(branches), 'limbs,', len(leaves), 'leaves,', len(roots), 'roots')
