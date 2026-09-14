"""Export imagegen's 4x2 animation sheets to Playdate 1-bit image tables.

Only uniform cell extraction, sizing and palette/alpha conversion happen here;
the eight animation poses are authored in the source art, not synthesized.
Run from any directory with Python + Pillow.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/frying-effects"
OUTPUT = ROOT / "source/resource/grill"


def pack(name, size, vertical_crop=(0, 1)):
    source = Image.open(ART / f"{name}-source.png").convert("RGBA")
    sheet = Image.new("RGBA", (size[0] * 4, size[1] * 2))
    for index in range(8):
        col, row = index % 4, index // 4
        # Fractional boundaries also handle generated canvases not divisible by 4.
        left, right = round(col * source.width / 4), round((col + 1) * source.width / 4)
        top = round((row + vertical_crop[0]) * source.height / 2)
        bottom = round((row + vertical_crop[1]) * source.height / 2)
        frame = source.crop((left, top, right, bottom)).resize(size, Image.Resampling.LANCZOS)
        alpha = frame.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
        monochrome = frame.convert("L").point(lambda value: 255 if value >= 128 else 0)
        frame = Image.merge("RGBA", (monochrome, monochrome, monochrome, alpha))
        sheet.paste(frame, (col * size[0], row * size[1]))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{name}-table-{size[0]}-{size[1]}.png"
    sheet.save(path)
    print(f"{path.relative_to(ROOT)}: 8 frames, {size[0]}x{size[1]}, black/white/transparent")


if __name__ == "__main__":
    pack("flame", (64, 56))
    # Identical crop for all frames preserves the ring's anchor and splash travel.
    pack("oil-bubbles", (84, 42), (0.25, 0.75))
