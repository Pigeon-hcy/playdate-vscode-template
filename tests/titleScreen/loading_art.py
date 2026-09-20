#!/usr/bin/env python3
"""Verify dissolve pixels stay fixed and switch only once per transition."""
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[2]
assets = root / 'source/resource/loading'
system = root / 'source/SystemAssets'


def pixels(path):
    image = Image.open(path)
    assert image.size == (400, 240) and image.mode == '1', path
    return {i for i, value in enumerate(image.convert('L').tobytes()) if value}


original = pixels(system / 'launchImage.png')
previous_in, previous_out = set(), original
for index in range(1, 14):
    appearing = pixels(assets / f'in-table-{index}.png')
    disappearing = pixels(assets / f'out-table-{index}.png')
    assert previous_in <= appearing <= original
    assert disappearing <= previous_out
    assert not appearing & disappearing and appearing | disappearing == original
    assert appearing == pixels(system / 'launchImages' / f'{index}.png')
    if index == 1:
        assert not appearing and disappearing == original
    if index == 7:
        mean_in_x = sum(i % 400 for i in appearing) / len(appearing)
        mean_out_x = sum(i % 400 for i in disappearing) / len(disappearing)
        assert mean_in_x < mean_out_x, 'dissolve must travel left to right'
    previous_in, previous_out = appearing, disappearing
assert previous_in == original and not previous_out
print('PASS: 400x240 opaque loading frames, fixed pixels, left-to-right dissolve and exact endpoints')
