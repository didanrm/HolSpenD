#!/usr/bin/env python3
"""Regenerates every launcher/splash bitmap from docs/brand/icon-mark.png.

    python3 tool/make_icons.py

The mark is the only hand-drawn asset; the teal tile, the rounded corners and
all the density buckets below are derived, so padding stays consistent instead
of drifting per file. Re-run after touching the artwork and commit the output.

Padding is the whole point of the ratios: an adaptive icon's foreground is a
108dp canvas of which the launcher only ever shows the middle 72dp (66%) and
may mask that into a circle. Drawing the mark at the full 66% makes it touch
the mask edge, which is what it used to do.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MARK = ROOT / "docs/brand/icon-mark.png"
RES = ROOT / "android/app/src/main/res"

# Fractions of the canvas the mark is allowed to occupy.
FG_RATIO = 0.52  # adaptive foreground: well inside the 66% mask
TILE_RATIO = 0.62  # inside the teal tile (legacy icon, splash, in-app logo)
CORNER_RATIO = 0.22  # tile corner radius

# Bottom-left -> top-right, same stops as drawable/ic_launcher_background.xml.
GRADIENT = ((6, 89, 99), (12, 123, 114), (93, 192, 139))

# dp -> px multiplier per density bucket.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

SS = 4  # supersampling factor for the rounded corners


def load_mark() -> Image.Image:
    """The mark, cropped to its own ink so the ratios below mean something."""
    mark = Image.open(MARK).convert("RGBA")
    return mark.crop(mark.split()[3].getbbox())


def centered(mark: Image.Image, size: int, ratio: float) -> Image.Image:
    """The mark scaled to `ratio` of a transparent `size` canvas, centred."""
    box = size * ratio
    scale = min(box / mark.width, box / mark.height)
    scaled = mark.resize(
        (max(1, round(mark.width * scale)), max(1, round(mark.height * scale))),
        Image.LANCZOS,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(
        scaled, ((size - scaled.width) // 2, (size - scaled.height) // 2)
    )
    return canvas


def gradient_tile(size: int) -> Image.Image:
    """Rounded square filled with the brand gradient, bottom-left to top-right."""
    big = size * SS
    grad = Image.new("RGBA", (big, big))
    pixels = grad.load()
    start, mid, end = GRADIENT
    for y in range(big):
        for x in range(big):
            # Projection onto the bottom-left -> top-right diagonal, 0..1.
            t = (x + (big - 1 - y)) / (2 * (big - 1))
            if t < 0.5:
                a, b, u = start, mid, t * 2
            else:
                a, b, u = mid, end, (t - 0.5) * 2
            pixels[x, y] = (
                round(a[0] + (b[0] - a[0]) * u),
                round(a[1] + (b[1] - a[1]) * u),
                round(a[2] + (b[2] - a[2]) * u),
                255,
            )

    mask = Image.new("L", (big, big), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, big - 1, big - 1), radius=round(big * CORNER_RATIO), fill=255
    )
    grad.putalpha(mask)
    return grad.resize((size, size), Image.LANCZOS)


def tile_icon(mark: Image.Image, size: int) -> Image.Image:
    tile = gradient_tile(size)
    tile.alpha_composite(centered(mark, size, TILE_RATIO))
    return tile


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}  {image.width}x{image.height}")


def main() -> None:
    mark = load_mark()

    print("adaptive foreground + legacy launcher icon")
    for bucket, factor in DENSITIES.items():
        save(
            centered(mark, round(108 * factor), FG_RATIO),
            RES / f"mipmap-{bucket}/ic_launcher_foreground.png",
        )
        save(
            tile_icon(mark, round(48 * factor)),
            RES / f"mipmap-{bucket}/ic_launcher.png",
        )

    print("splash + in-app logo")
    # nodpi: launch_background sizes it in dp itself, and the Android 12
    # splash API wants one density-independent bitmap.
    save(tile_icon(mark, 512), RES / "drawable-nodpi/splash_logo.png")

    # Android 12+ clips windowSplashScreenAnimatedIcon to a circle of 2/3 the
    # canvas, so the tile is inset to the largest square that fits that circle
    # (side = 0.707 * diameter) instead of losing its corners.
    splash_icon = Image.new("RGBA", (576, 576), (0, 0, 0, 0))
    tile = tile_icon(mark, round(576 * (2 / 3) * 0.707))
    splash_icon.alpha_composite(tile, ((576 - tile.width) // 2,) * 2)
    save(splash_icon, RES / "drawable-nodpi/splash_icon.png")

    save(tile_icon(mark, 512), ROOT / "assets/logo.png")
    save(tile_icon(mark, 1024), ROOT / "docs/brand/logo-full.png")

    stale = RES / "drawable/splash_logo.png"
    if stale.exists():
        stale.unlink()
        print(f"  removed {stale.relative_to(ROOT)} (moved to drawable-nodpi)")


if __name__ == "__main__":
    main()
