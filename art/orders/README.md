# Order UI assets

Generated using the built-in image_gen tool. Original transparent outputs are
`Holder-generated.png` and `Receipt-generated.png` in this folder.

Run `python3 tools/build_order_sprites.py` from the repository root to trim
transparent margins and export black/white RGBA sprites at their runtime sizes:

- `source/resource/orders/Holder.png`: 168 x 10.
- `source/resource/orders/Receipt.png`: 22 x 28.

The game draws these at 1:1 using plain blits, without runtime resizing.
The holder is flipped vertically once on load to hang from the screen top.
The source art stays outside `source` to avoid bundling it.

## Holder prompt

Use case: ui-mockup. Asset type: transparent raster game UI sprite for a Playdate black-and-white pixel-art burger cooking game. Generate ONE simple EMPTY concave U-shaped receipt holder, viewed straight from the front, orthographic 2D. Very wide horizontal base strip with two short raised end walls, like a shallow open-top trough; the long open central recess and all space above it must be TRANSPARENT. No paper inside. Intended final sprite is 168 pixels wide and 10 pixels tall, so the actual object's width to height ratio should be roughly 17:1 even if surrounded by generous transparent margins on a square canvas. Solid black outline, white interior on the base/end walls, one simple black inner groove, bold minimal geometry, no fussy details. Black and white only, crisp silhouette, no lighting, no perspective, no gradients, no text, no watermark. Actual transparent alpha around the object and through its open center. Center the entire isolated object fully inside the canvas.

## Receipt prompt

Use case: ui-mockup. Asset type: transparent raster game UI sprite for a Playdate black-and-white pixel-art burger cooking game. Generate ONE small narrow upright order receipt, viewed straight from the front, orthographic 2D. White paper with solid black outline, flat straight top and sides, a very simple serrated bottom with three large teeth. Inside the paper ONLY three short thick horizontal black print marks with generous spacing, NO letters, NO numbers, NO specific burger type, NO symbols. Intended final sprite is 22 pixels wide and 28 pixels tall: every detail must remain legible at that tiny size. Flat monochrome black and white only. No shadow, fold, curl, texture, gradients, perspective, holder, scenery or watermark. Actual transparent alpha surrounding the paper. Center one isolated receipt on canvas.
