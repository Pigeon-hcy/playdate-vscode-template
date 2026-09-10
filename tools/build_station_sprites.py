#!/usr/bin/env python3
"""Derive the grill and grinder sprites from the 1-bit art in source/resource.

    python3 tools/build_station_sprites.py

The station art is authored 160 px wide to match the ingredient sprites, not
at its size relative to the machines, so patties and meat are shrunk here.
Shrinking a dithered image by sampling (as Playdate's scaledImage does)
collapses the pattern into solid blocks, so this box-filters the 1-bit art
back to grey, resizes, and dithers again at the final size.

Grill: the grate behind the patties is dense black bars, so a black outline
alone vanishes into it; a white halo outside the outline is what separates a
patty from the grill. The ring pads the canvas evenly, so the grill's slot
anchors are centre points.

Grinder: the meat is stood on end and shrunk to feed down into the hopper
(turned in grey, so its dither is laid fresh in screen orientation like every
other sprite), and every fully opaque 4x4
cell of it is packed into an image table, so each mince particle is a real
crumb of that meat. The crank is pre-rendered at every rotation step:
drawRotated resamples the thin dithered arm into a broken string of dots at
most angles, where each frame here is rotated smoothly in grey and dithered
fresh, and costs only a plain blit at runtime. It sweeps across the dithered
machine body for half a turn, so it takes the same outline and halo as the
patties.
"""
import argparse
import os

from PIL import Image, ImageChops

SOURCE = "source/resource"
GRILL_OUTPUT = "source/resource/grill"
GRINDER_OUTPUT = "source/resource/grinder"
PATTIES = ["RawPatty", "CookedPatty", "BurntPatty"]
MINCE_CELL = 4

# Measured on GrinderCrank.png; the hub in GENERATED_ASSETS.md is 19 px off.
CRANK_HUB = (133, 53)
# Farthest crank pixel from the hub, so no rotation clips.
CRANK_REACH = 104
CRANK_COLUMNS = 12

BAYER = [
    [0, 32, 8, 40, 2, 34, 10, 42], [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38], [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41], [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37], [63, 31, 55, 23, 61, 29, 53, 21],
]


def to_grey(image):
    alpha = image.getchannel("A")
    grey = Image.new("L", image.size, 255)
    grey.paste(image.convert("L"), (0, 0), alpha)
    return grey, alpha


def dither(grey, alpha):
    width, height = grey.size
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    source, mask, target = grey.load(), alpha.load(), out.load()

    for y in range(height):
        for x in range(width):
            if mask[x, y] <= 127:
                continue
            threshold = (BAYER[y % 8][x % 8] + 0.5) / 64.0 * 255.0
            v = 255 if source[x, y] > threshold else 0
            target[x, y] = (v, v, v, 255)

    return out


def shrink(path, scale, turn=None):
    image = Image.open(path).convert("RGBA")
    if turn is not None:
        image = image.transpose(turn)
    size = (round(image.width * scale), round(image.height * scale))
    grey, alpha = to_grey(image)
    return dither(grey.resize(size, Image.BOX), alpha.resize(size, Image.BOX))


def dilate(mask, radius):
    """Grow a mask by a disk. The canvas is padded by at least the radius, so
    offset's wrap-around only ever moves empty border onto empty border."""
    out = mask
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if (dx or dy) and dx * dx + dy * dy <= radius * radius:
                out = ImageChops.lighter(out, ImageChops.offset(mask, dx, dy))
    return out


def ring(sprite, outline, halo):
    pad = outline + halo
    width, height = sprite.width + 2 * pad, sprite.height + 2 * pad
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    out.alpha_composite(sprite, (pad, pad))

    solid = out.getchannel("A").point(lambda v: 255 if v > 127 else 0)
    inner = dilate(solid, outline)
    outer = dilate(solid, pad)
    black = ImageChops.subtract(inner, solid)
    white = ImageChops.subtract(outer, inner)

    out.paste((255, 255, 255, 255), (0, 0), white)
    out.paste((0, 0, 0, 255), (0, 0), black)
    return out


def mince_cells(meat):
    """Every fully opaque cell of the meat, so no crumb comes out ragged."""
    pixels = meat.load()
    cells = []

    for top in range(0, meat.height - MINCE_CELL + 1, MINCE_CELL):
        for left in range(0, meat.width - MINCE_CELL + 1, MINCE_CELL):
            if all(pixels[left + dx, top + dy][3] > 127
                   for dy in range(MINCE_CELL) for dx in range(MINCE_CELL)):
                cells.append(meat.crop(
                    (left, top, left + MINCE_CELL, top + MINCE_CELL)))

    return cells


def build_grill(scale, outline, halo):
    os.makedirs(GRILL_OUTPUT, exist_ok=True)

    for name in PATTIES:
        sprite = shrink(os.path.join(SOURCE, name + ".png"), scale)
        sprite = ring(sprite, outline, halo)
        sprite.save(os.path.join(GRILL_OUTPUT, name + ".png"))
        print(f"  grill/{name:<12} {sprite.width}x{sprite.height}")


def build_grinder(scale):
    os.makedirs(GRINDER_OUTPUT, exist_ok=True)

    meat = shrink(os.path.join(SOURCE, "RawMeat.png"), scale, Image.ROTATE_90)
    meat.save(os.path.join(GRINDER_OUTPUT, "RawMeat.png"))
    print(f"  grinder/RawMeat      {meat.width}x{meat.height}")

    # One row, so the table's cell count is exactly the number of crumbs.
    cells = mince_cells(meat)
    strip = Image.new(
        "RGBA", (MINCE_CELL * len(cells), MINCE_CELL), (0, 0, 0, 0))

    for index, cell in enumerate(cells):
        strip.paste(cell, (index * MINCE_CELL, 0))

    name = f"mince-table-{MINCE_CELL}-{MINCE_CELL}.png"
    strip.save(os.path.join(GRINDER_OUTPUT, name))
    print(f"  grinder/{name}  {len(cells)} crumbs")


def build_crank(scale, frames, outline, halo):
    if frames % CRANK_COLUMNS:
        raise SystemExit(f"--crank-frames must be a multiple of {CRANK_COLUMNS}")

    crank = Image.open(os.path.join(SOURCE, "GrinderCrank.png")).convert("RGBA")

    # Hub at the exact centre, so every frame turns about it.
    canvas = CRANK_REACH * 2 + 1
    centred = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    centred.alpha_composite(
        crank, (CRANK_REACH - CRANK_HUB[0], CRANK_REACH - CRANK_HUB[1]))
    grey, alpha = to_grey(centred)

    size = round(CRANK_REACH * scale) * 2 + 1
    cell = size + 2 * (outline + halo)
    rows = frames // CRANK_COLUMNS
    sheet = Image.new(
        "RGBA", (cell * CRANK_COLUMNS, cell * rows), (0, 0, 0, 0))

    # Frame n is turned n steps clockwise from the art as drawn.
    for index in range(frames):
        degrees = index * 360 / frames
        frame = ring(dither(
            grey.rotate(-degrees, Image.BICUBIC, fillcolor=255)
                .resize((size, size), Image.BOX),
            alpha.rotate(-degrees, Image.BICUBIC)
                .resize((size, size), Image.BOX)), outline, halo)
        column, row = index % CRANK_COLUMNS, index // CRANK_COLUMNS
        sheet.paste(frame, (column * cell, row * cell))

    name = f"crank-table-{cell}-{cell}.png"
    sheet.save(os.path.join(GRINDER_OUTPUT, name))
    print(f"  grinder/{name}  {frames} frames of {cell}x{cell}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--patty-scale", type=float, default=0.5)
    parser.add_argument("--outline", type=int, default=1)
    parser.add_argument("--halo", type=int, default=1)
    parser.add_argument("--meat-scale", type=float, default=0.5)
    parser.add_argument("--crank-scale", type=float, default=0.65)
    parser.add_argument("--crank-frames", type=int, default=72)
    args = parser.parse_args()

    build_grill(args.patty_scale, args.outline, args.halo)
    build_grinder(args.meat_scale)
    build_crank(args.crank_scale, args.crank_frames, args.outline, args.halo)


if __name__ == "__main__":
    main()
