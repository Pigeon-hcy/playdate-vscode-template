#!/usr/bin/env python3
"""Export the generated transparent order artwork as tiny 1-bit game sprites.

    python3 tools/build_order_sprites.py

Original art and prompts live in art/orders. Crop only transparent margins,
resize once at build time, and quantize color/alpha for crisp SDK plain blits.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "source/resource/orders"


def export(name, size):
    image = Image.open(ROOT / "art/orders" / f"{name}-generated.png").convert("RGBA")
    mask = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    bounds = mask.getbbox()
    assert bounds, "generated image must contain opaque artwork"
    image = image.crop(bounds).resize(size, Image.Resampling.LANCZOS)
    gray = image.convert("L").point(lambda v: 255 if v >= 128 else 0)
    alpha = image.getchannel("A").point(lambda a: 255 if a >= 128 else 0)
    output = Image.merge("RGBA", (gray, gray, gray, alpha))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT / f"{name}.png")


if __name__ == "__main__":
    export("Holder", (168, 10))
    export("Receipt", (22, 28))
