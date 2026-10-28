"""Measure text-vs-background contrast in a rendered widget image.

Two things make this fiddly:
  - the card fill is a horizontal gradient, so the background differs per
    column; within a column it is constant, so a per-column mode is correct;
  - glyphs are anti-aliased, so the faintest edge pixels would otherwise
    dominate a worst-case reading. Only columns carrying solid glyph coverage
    are considered.
"""
import sys
from collections import Counter
from PIL import Image

def lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

def lum(rgb):
    return 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2])

def ratio(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

def check(img, label, x0, x1, y0, y1, quiet=False):
    # Every pixel, paired with the background of its own column.
    samples = []
    for x in range(x0, x1):
        col = [img.getpixel((x, y))[:3] for y in range(y0, y1)]
        bg = Counter(col).most_common(1)[0][0]
        for px in col:
            samples.append((bg, px, abs(lum(px) - lum(bg))))

    peak = max(s[2] for s in samples) if samples else 0
    if peak < 0.02:
        if not quiet:
            print(f"  {label:<22} no glyphs found")
        return None

    # Only pixels at near-full stroke strength are glyph cores; anything
    # fainter is an anti-aliased edge and would understate the real contrast.
    cores = [s for s in samples if s[2] >= 0.9 * peak]
    worst = min(cores, key=lambda s: ratio(s[0], s[1]))
    r = ratio(worst[0], worst[1])
    verdict = "PASS" if r >= 4.5 else ("weak" if r >= 3.0 else "FAIL")
    if not quiet:
        print(f"  {label:<22} bg=rgb{worst[0]} ink=rgb{worst[1]}"
              f"  contrast={r:5.2f}  {verdict}")
    return r

BANDS = [
    ("Living room name", 70, 88), ("Living room sub", 88, 100),
    ("Ceiling row",     160, 178), ("Floor lamp row",  196, 214),
    ("TV backlight row",232, 250), ("Bedroom name",    278, 296),
    ("Kitchen name",    342, 360), ("Kitchen sub",     360, 372),
    ("Office name",     404, 422),
]

# Icon column of each card, in a render with no room expanded. Icons are a
# solid shape rather than text, so they are measured as a block.
ICON_BANDS = [
    ("Living room icon", 26, 43, 75, 93),
    ("Bedroom icon",     26, 43, 139, 157),
    ("Kitchen icon",     26, 43, 203, 221),
    ("Office icon (off)", 26, 43, 267, 285),
]


def measure_icons(path, quiet=False):
    """Contrast of each card's icon against the card behind it.

    Guards a bug where bundled SVGs rendered as black silhouettes, invisible
    on a dark card, because Kirigami.Icon ignores `color` for file sources.
    """
    img = Image.open(path).convert("RGB")
    rows = []
    for name, x0, x1, y0, y1 in ICON_BANDS:
        px = [img.getpixel((x, y)) for x in range(x0, x1) for y in range(y0, y1)]
        base = Counter(px).most_common(1)[0][0]
        far = max(px, key=lambda p: abs(lum(p) - lum(base)))
        r = ratio(base, far)
        rows.append((name, r))
        if not quiet:
            verdict = "PASS" if r >= 4.5 else ("weak" if r >= 3.0 else "FAIL")
            print(f"  {name:<20} contrast={r:5.2f}  {verdict}")
    return (min(r for _, r in rows) if rows else None), rows


def measure(path, quiet=False):
    """Return (worst_ratio, [(label, ratio), ...]) for a rendered widget."""
    img = Image.open(path).convert("RGB")
    if not quiet:
        print(f"{path}  ({img.width}x{img.height})")
    rows = []
    for name, y0, y1 in BANDS:
        r = check(img, name, 45, 300, y0, y1, quiet=quiet)
        if r is not None:
            rows.append((name, r))
    return (min(r for _, r in rows) if rows else None), rows


if __name__ == "__main__":
    worst, _ = measure(sys.argv[1])
    print(f"  --> worst overall: {worst:.2f}")
