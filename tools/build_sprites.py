#!/usr/bin/env python3
"""Turn the greyscale ingredient art into 1-bit Playdate sprites.

    python3 tools/build_sprites.py [--width 160] [--outline 2]

Reads the greyscale originals, resamples them to the target size, dithers at
that final resolution (never scale an already-dithered image -- the pattern
moires), then rings the silhouette with a solid outline so stacked layers stay
readable where they overlap.
"""
import argparse
import os
import sys

from PIL import Image

SOURCE = os.path.expanduser("~/Documents/Arts/playdate")
OUTPUT = "source/resource/ingredients"

# Bayer 8x8: screen-aligned inside each sprite, so flat greys resolve to clean
# regular patterns rather than noise.
BAYER = [
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
]


def disk(radius):
    return [(dx, dy)
            for dy in range(-radius, radius + 1)
            for dx in range(-radius, radius + 1)
            if dx * dx + dy * dy <= radius * radius]


def build(path, width, height, outline):
    image = Image.open(path).convert("RGBA").resize(
        (width, height), Image.BICUBIC)
    pixels = image.load()

    solid = [[False] * width for _ in range(height)]
    value = [[0] * width for _ in range(height)]

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a <= 127:
                continue
            solid[y][x] = True
            luminance = 0.299 * r + 0.587 * g + 0.114 * b
            threshold = (BAYER[y % 8][x % 8] + 0.5) / 64.0 * 255.0
            value[y][x] = 255 if luminance > threshold else 0

    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    target = out.load()

    if outline > 0:
        kernel = disk(outline)
        for y in range(height):
            for x in range(width):
                if solid[y][x]:
                    continue
                for dx, dy in kernel:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and solid[ny][nx]:
                        target[x, y] = (0, 0, 0, 255)
                        break

    for y in range(height):
        for x in range(width):
            if solid[y][x]:
                v = value[y][x]
                target[x, y] = (v, v, v, 255)

    # Trim vertically to the drawn content. The originals pad each ingredient
    # differently inside the canvas, so stacking by canvas edge reveals far
    # more than the intended offset. Full width is kept, leaving the artist's
    # horizontal placement untouched.
    bounds = out.getchannel("A").point(lambda v: 255 if v > 127 else 0).getbbox()
    if bounds is not None:
        out = out.crop((0, bounds[1], width, bounds[3]))

    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--width", type=int, default=160)
    parser.add_argument("--outline", type=int, default=2)
    parser.add_argument("--source", default=SOURCE)
    parser.add_argument("--output", default=OUTPUT)
    args = parser.parse_args()

    names = sorted(f for f in os.listdir(args.source) if f.endswith(".png"))
    if not names:
        sys.exit(f"no PNGs in {args.source}")

    os.makedirs(args.output, exist_ok=True)
    tallest = 0

    for name in names:
        path = os.path.join(args.source, name)
        source_width, source_height = Image.open(path).size
        height = round(args.width * source_height / source_width)
        sprite = build(path, args.width, height, args.outline)
        sprite.save(os.path.join(args.output, name))
        tallest = max(tallest, sprite.height)
        print(f"  {name:<14} {sprite.width}x{sprite.height}")

    print(f"{len(names)} sprites -> {args.output} at width {args.width}, "
          f"outline {args.outline}px, tallest {tallest}px")
    print("Set spriteWidth/maxSpriteHeight in "
          "source/assemblyWorkstation.lua to match.")


if __name__ == "__main__":
    main()
