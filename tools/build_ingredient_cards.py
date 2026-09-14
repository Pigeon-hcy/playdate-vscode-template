#!/usr/bin/env python3
"""Bake native 1-bit ingredient cards from generated pictograms and Lua labels.

Run from any directory with Python + Pillow. Original generated art and prompts
are retained in art/ingredient-cards. All typography is deterministic pixel art;
the generative model only supplies the separate ingredient pictograms.
"""
from pathlib import Path
import json
import re

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps
from build_sprites import BAYER

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art/ingredient-cards"
OUTPUT = ROOT / "source/resource/ingredient-cards"
CONFIG = (ROOT / "source/playerConfig.lua").read_text()

# Compact 5x7 lettering. Tight glyph bounds save room for full cheese names,
# while large mnemonics use the same glyphs at an integer 3x scale.
FONT = {
    "A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
    "B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"],
    "C": ["01111", "10000", "10000", "10000", "10000", "10000", "01111"],
    "D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
    "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
    "F": ["11111", "10000", "10000", "11110", "10000", "10000", "10000"],
    "G": ["01111", "10000", "10000", "10111", "10001", "10001", "01111"],
    "H": ["10001", "10001", "10001", "11111", "10001", "10001", "10001"],
    "I": ["01110", "00100", "00100", "00100", "00100", "00100", "01110"],
    "J": ["00111", "00010", "00010", "00010", "10010", "10010", "01100"],
    "K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"],
    "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
    "M": ["10001", "11011", "10101", "10101", "10001", "10001", "10001"],
    "N": ["10001", "11001", "11001", "10101", "10011", "10011", "10001"],
    "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
    "P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
    "Q": ["01110", "10001", "10001", "10001", "10101", "10010", "01101"],
    "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
    "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
    "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
    "U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
    "V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
    "W": ["10001", "10001", "10001", "10101", "10101", "10101", "01010"],
    "X": ["10001", "10001", "01010", "00100", "01010", "10001", "10001"],
    "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"],
    "Z": ["11111", "00001", "00010", "00100", "01000", "10000", "11111"],
    ".": ["00000", "00000", "00000", "00000", "00000", "00000", "00100"],
}


def string_table(key):
    body = re.search(r"\b" + key + r"\s*=\s*\{([^}]+)\}", CONFIG).group(1)
    return dict(re.findall(r'(\w+)\s*=\s*"([^"]+)"', body))


def card_dimension(key):
    body = CONFIG.split("ingredientCards = {", 1)[1].split("abbreviations", 1)[0]
    return int(re.search(r"\b" + key + r"\s*=\s*(\d+)", body).group(1))


def glyph_mask(character):
    if character == " ":
        return Image.new("L", (3, 7), 0)
    rows = FONT[character]
    mask = Image.new("L", (5, 7), 0)
    for y, row in enumerate(rows):
        for x, pixel in enumerate(row):
            if pixel == "1":
                mask.putpixel((x, y), 255)
    left, _, right, _ = mask.getbbox()
    return mask.crop((left, 0, right, 7))


def text_mask(text, large=False):
    height = 21 if large else 7
    glyphs = []
    for character in text:
        glyph = glyph_mask(character)
        if large:
            if character == ".":
                glyph = Image.new("L", (2, 21), 0)
                ImageDraw.Draw(glyph).rectangle((0, 19, 1, 20), fill=255)
            else:
                glyph = glyph.resize((glyph.width * 3, 21), Image.Resampling.NEAREST)
        glyphs.append(glyph)
    mask = Image.new("L", (sum(g.width for g in glyphs) + len(glyphs) - 1, height), 0)
    x = 0
    for glyph in glyphs:
        mask.paste(glyph, (x, 0))
        x += glyph.width + 1
    return mask


def export_icon(name):
    original = Image.open(ART / "generated" / f"{name}.png").convert("RGBA")
    white = Image.new("RGBA", original.size, "white")
    white.alpha_composite(original)
    gray = white.convert("L")
    bounds = gray.point(lambda v: 255 if v < 128 else 0).getbbox()
    assert bounds, f"{name}: pictogram is empty"
    icon = ImageOps.contain(gray.crop(bounds), (28, 28), Image.Resampling.LANCZOS)
    # Recover the enclosed silhouette from the white-background source. A
    # final one-pixel rim keeps pale cheese/egg outlines from dissolving when
    # their large source contours become narrower than one display pixel.
    contour_source = gray.crop(bounds).resize(
        (icon.width * 8, icon.height * 8), Image.Resampling.LANCZOS)
    ink = contour_source.point(lambda v: 255 if v < 180 else 0)
    ink = ImageOps.expand(ink, border=3, fill=0)
    # Close subpixel breaks in the generated stippled contour before filling.
    ink = ink.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    enclosed = ImageOps.invert(ink)
    ImageDraw.floodfill(enclosed, (0, 0), 128)
    silhouette = enclosed.point(lambda v: 0 if v == 128 else 255).crop(
        (3, 3, enclosed.width - 3, enclosed.height - 3))
    silhouette = silhouette.resize(icon.size, Image.Resampling.LANCZOS).point(
        lambda v: 255 if v >= 128 else 0)
    padded = ImageOps.expand(silhouette, border=1, fill=0)
    inside = padded.filter(ImageFilter.MinFilter(3)).crop(
        (1, 1, silhouette.width + 1, silhouette.height + 1))
    rim = ImageChops.subtract(silhouette, inside)
    # Match the game's food export: resize before dithering so tiny pictograms
    # keep one-pixel ink texture instead of aliasing a large stipple pattern.
    binary = Image.new("1", icon.size, 1)
    for y in range(icon.height):
        for x in range(icon.width):
            threshold = (BAYER[y % 8][x % 8] + 0.5) / 64.0 * 255
            binary.putpixel((x, y), 255 if icon.getpixel((x, y)) > threshold else 0)
    binary.paste(0, (0, 0), rim)
    binary.save(ART / "icons" / f"{name}.png")
    return binary


def card_art(name, size):
    """Enlarge the source's left half, fading into paper from the card quarter."""
    width, _ = size
    original = Image.open(ART / "generated" / f"{name}.png").convert("RGBA")
    white = Image.new("RGBA", original.size, "white")
    white.alpha_composite(original)
    gray = white.convert("L")
    bounds = gray.point(lambda v: 255 if v < 128 else 0).getbbox()
    assert bounds, f"{name}: pictogram is empty"
    subject = gray.crop(bounds)
    left_half = subject.crop((0, 0, (subject.width + 1) // 2, subject.height))
    start = width // 4
    end = width - 2
    # Enlarge without losing all silhouette to an extreme texture close-up.
    # The right card edge cuts at the object's midpoint; excess height crops
    # centrally. Source proportions and the entire left-half width are kept.
    detail = ImageOps.contain(left_half, (width - 1 - start, 52),
                             Image.Resampling.LANCZOS)
    left = width - 1 - detail.width
    top = (35 - detail.height) // 2
    result = Image.new("1", (width, 35), 1)
    for y in range(detail.height):
        for x in range(detail.width):
            card_x, card_y = left + x, top + y
            if card_y < 1 or card_y >= 34:
                continue
            opacity = min(1, max(0, (card_x - start) / (end - start)))
            opacity = opacity * opacity * (3 - 2 * opacity)
            value = 255 - (255 - detail.getpixel((x, y))) * opacity
            threshold = (BAYER[card_y % 8][card_x % 8] + .5) / 64 * 255
            result.putpixel((card_x, card_y), 255 if value > threshold else 0)
    return result


def make_card(code, abbreviation, name, artwork, selected, size):
    width, height = size
    card = Image.new("1", size, 1)
    draw = ImageDraw.Draw(card)
    card.paste(artwork, (0, 0))
    # The food dissolves into the letter area; only the full-name row is ruled.
    # Both states keep black lettering on white, with selection on the border.
    draw.rectangle((0, 0, width - 1, height - 1), outline=0, width=2 if selected else 1)
    draw.line((1, 35, width - 2, 35), fill=0)
    mnemonic = text_mask(abbreviation, large=True)
    label = text_mask(name)
    assert mnemonic.width <= 39, f"{code}: abbreviation exceeds left zone"
    assert label.width <= width - 6, f"{code}: full name does not fit ({label.width}px)"
    letter_x = (43 - mnemonic.width) // 2
    # A one-pixel paper halo keeps long cheese mnemonics legible through the
    # dissolve without putting them on a rectangular backing plate.
    halo = ImageOps.expand(mnemonic, border=1, fill=0).filter(ImageFilter.MaxFilter(3))
    card.paste(1, (letter_x - 1, 6), halo)
    card.paste(0, (letter_x, 7), mnemonic)
    card.paste(0, ((width - label.width) // 2, 39), label)
    return card


def make_initials(codes, abbreviations, selected, width):
    """All ten mnemonics remain visible, including while their cards scroll."""
    image = Image.new("1", (width, card_dimension("initialsHeight")), 1)
    draw = ImageDraw.Draw(image)
    cell_width = width // 5
    for index, code in enumerate(codes):
        x = 1 + index % 5 * cell_width
        y = index // 5 * 12
        glyph = text_mask(abbreviations[code])
        assert glyph.width <= cell_width - 2
        image.paste(0, (x + (cell_width - glyph.width) // 2, y + 2), glyph)
        if code == selected:
            draw.rectangle((x, y, x + cell_width - 1, y + 10), outline=0)
    return image


def wheel_preview(cards, codes, initials):
    """Static right-panel crop using the actual wheel bounds, not a screenshot."""
    source = (ROOT / "source/assemblyWorkstation.lua").read_text()

    def constant(name):
        return int(re.search(r"\b" + name + r"\s*<const>\s*=\s*(\d+)", source).group(1))

    left = constant("ingredientPanelLeft")
    right = constant("wheelCardRight")
    center = constant("wheelCenterY")
    clip_y = constant("wheelClipY")
    clip_height = constant("wheelClipHeight")
    width, height = card_dimension("width"), card_dimension("height")
    spacing = card_dimension("spacing")
    sheet = Image.new("RGB", ((400 - left) * 3, 240), "white")
    for column, selected in enumerate(("M", "B", "A")):
        panel = Image.new("1", (400 - left, 240), 1)
        draw = ImageDraw.Draw(panel)
        draw.line((0, 0, 0, 210), fill=0)
        panel.paste(0, (8, 7), text_mask("ITEMS"))
        contents = Image.new("1", panel.size, 1)
        for relative in range(-3, 4):
            code = codes[(codes.index(selected) + relative) % len(codes)]
            y = center + relative * spacing - height // 2
            contents.paste(cards[(code, relative == 0)], (right - left - width, y))
        region = contents.crop((1, clip_y, panel.width, clip_y + clip_height))
        panel.paste(region, (1, clip_y))
        panel.paste(initials[selected], (right - left - width, card_dimension("initialsY")))
        sheet.paste(panel, (column * panel.width, 0))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(
        ART / "wheel-preview-2x.png")


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (ART / "icons").mkdir(parents=True, exist_ok=True)
    (ART / "cards").mkdir(parents=True, exist_ok=True)
    size = (card_dimension("width"), card_dimension("height"))
    names = string_table("names")
    abbreviations = string_table("abbreviations")
    sprites = string_table("ingredientSprites")
    assert names.keys() == abbreviations.keys() == sprites.keys()
    assert len(set(abbreviations.values())) == len(abbreviations)
    code_block = re.search(r'ingredientCodes\s*=\s*\{([^}]+)\}', CONFIG).group(1)
    codes = re.findall(r'"([^"]+)"', code_block)
    assert set(codes) == names.keys() and len(codes) == len(names)
    cards = {}
    atlas = Image.new("1", (size[0] * 2, size[1] * len(codes)), 1)
    for index, code in enumerate(codes):
        name = names[code]
        export_icon(sprites[code])
        artwork = card_art(sprites[code], size)
        for selected in (False, True):
            card = make_card(code, abbreviations[code], name, artwork, selected, size)
            suffix = "-selected" if selected else ""
            card.save(ART / "cards" / f"{code}{suffix}.png")
            cards[(code, selected)] = card
            atlas.paste(card, (int(selected) * size[0], index * size[1]))

    atlas.save(OUTPUT / f"cards-table-{size[0]}-{size[1]}.png")
    initials = {}
    rail_height = card_dimension("initialsHeight")
    rail_atlas = Image.new("1", (size[0], rail_height * len(codes)), 1)
    for index, code in enumerate(codes):
        initials[code] = make_initials(codes, abbreviations, code, size[0])
        rail_atlas.paste(initials[code], (0, index * rail_height))
    rail_atlas.save(OUTPUT / f"initials-table-{size[0]}-{rail_height}.png")
    # Retire only the old exports owned by this generator. Review copies now
    # live outside source/, so pdc ships one table instead of 30 loose assets.
    for code in codes:
        for suffix in ("", "-selected"):
            (OUTPUT / f"{code}{suffix}.png").unlink(missing_ok=True)
        (OUTPUT / "icons" / f"{sprites[code]}.png").unlink(missing_ok=True)
    old_icons = OUTPUT / "icons"
    if old_icons.exists() and not any(old_icons.iterdir()):
        old_icons.rmdir()

    # Each ingredient has normal/selected variants one above the other.
    sheet = Image.new("RGB", (5 * 102, 2 * 116), "#dddddd")
    for index, code in enumerate(names):
        x, y = index % 5 * 102 + 5, index // 5 * 116 + 5
        for selected in (False, True):
            sheet.paste(cards[(code, selected)], (x, y + int(selected) * 54))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.Resampling.NEAREST).save(
        ART / "cards-preview-2x.png")
    wheel_preview(cards, codes, initials)
    manifest = {
        "size": size,
        "artCrop": "left half of visible subject, aspect-preserving, vertically centered",
        "artFadeStartFraction": 0.25,
        "selectedStyle": "thicker border, black mnemonic on white",
        "cards": [{"code": c, "abbreviation": abbreviations[c], "name": names[c],
                   "icon": sprites[c], "normalFrame": i * 2 + 1,
                   "selectedFrame": i * 2 + 2} for i, c in enumerate(codes)],
    }
    (ART / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Built {len(names)} ingredient cards in two states at {size[0]}x{size[1]}; all full names fit.")


if __name__ == "__main__":
    main()
