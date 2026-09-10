# 加工站素材（简化版）

本目录的 7 张 PNG 已按用户的反馈简化：使用完整轮廓和少量大块明暗，去掉细碎肉纹、裂纹、螺丝与反光细节。全部采用透明背景、横向 2D 视角和纯黑白点阵。

| 文件 | 内容 | 尺寸 |
| --- | --- | --- |
| RawMeat.png | 生肉块 | 160×80 |
| RawPatty.png | 生肉饼 | 160×60 |
| CookedPatty.png | 熟肉饼 | 160×60 |
| BurntPatty.png | 烤焦肉饼 | 160×60 |
| GrillTray.png | 双区烤盘 | 160×80 |
| GrinderBody.png | 绞肉机机体 | 160×128 |
| GrinderCrank.png | 独立摇杆（含握把） | 160×128 |

三种肉饼的画布与 ingredients/Patty.png 相同，均为 160×60；可见区域对齐到约 x=18..136。生、熟、焦主要以亮度区分，同时保留少量状态特征。

## 摇杆安装

以下是本次简化版的坐标，以 PNG 左上角为原点（0-based）。

- GrinderBody.png 的安装孔中心约为 (34,79)。
- GrinderCrank.png 的轴心约为 (137,53)。
- 两张图均为 160×128；透明留白不同，需要对齐轴心，不能按左上角直接叠放。
- 使用 Playdate drawRotated 时，摇杆 centerX=137/160、centerY=53/128；绘制位置为机体左上角偏移 (34,79)。

## 生成与导出

使用内置 image_gen 生成简化灰度原图。最终缩放到游戏尺寸后，采用项目已有的 Bayer 8×8 规则点阵，避免缩小已经点阵化的细节产生杂纹。非常暗的区域保持纯黑，alpha 按 128 阈值二值化。已经检查所有素材的尺寸、真实透明通道和黑白像素，并与现有 Patty、TopBread、Bacon 并排检查。

## 本版最终生成提示词

### RawMeat

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify to one boneless raw meat chunk with softly squared ends, one broad pale fat band, and only TWO broad internal marbling shapes. No web of veins, no striated muscle grain. A medium gray body with a simple darker underside. Keep horizontal 2:1 silhouette.
Canvas aspect ratio 160:80. One object only.

### RawPatty

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify to one squat oval raw hamburger patty, shaped like a simple squashed oval. Use a pale gray top with only THREE small darker irregular patches and a medium gray front edge. No grain, no individual mince chunks, no grill stripes, no pores. Slightly irregular outer edge, not a perfectly machined puck.
Canvas aspect ratio 160:60. One object only.

### CookedPatty

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify to one squat oval cooked hamburger patty shaped like a simple squashed oval. Medium-dark gray top and darker front edge. Only TWO subtle short broad darker sear marks and TWO broad lighter irregular patches. Eliminate ALL small meat grain. Compact plain silhouette matching raw patty.
Canvas aspect ratio 160:60. One object only.

### BurntPatty

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify to one squat oval burnt hamburger patty with the same outline as a simple squashed oval. Nearly black top and black side, with only TWO muted dark-gray irregular patches. NO network of cracks, NO ash flecks, NO white speckling, no smoke. The darkest of the three cooking states.
Canvas aspect ratio 160:60. One object only.

### GrillTray

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify the empty double-zone grill tray drastically: a low rectangular tray, one center divider, and only FIVE broad horizontal grate bars per zone, a plain short back lip, two very simple front handles. Broad flat mid-gray metal frame, dark grates. Remove screws, rivets, bevel detailing, tiny slots, tiny highlights and decorative border lines. Keep shallow side/front 2D view, no tall stove cabinet.
Canvas aspect ratio 160:80. One object only.

### GrinderBody

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify the fixed meat grinder body: one plain funnel on upper left, one horizontal short cylinder with a plain outlet collar at right, two plain stubby feet. Keep side view. Keep crank mounting hole at same position as described, approximately (45,72) in final 160x128 canvas. Make mounting hub a SMALL simple dark circle, no flange bolts or concentric ornamentation. Outlet has just THREE big dark holes at most. NO screws, NO textured metal, NO layered rim rings, NO tiny highlight glints. NO crank arm or crank grip attached. Three flat matte gray regions suffice.
Canvas aspect ratio 160:128. One object only.

### GrinderCrank

Generate one transparent PNG game sprite. Use actual alpha transparency around the object. Flat 2D side view. Very simple rounded silhouette with a dark outline and only 3 matte grayscale regions. Very low detail, broad plain surfaces. No texture, no grain, no stippling, no hatching, no glossy highlights. These are small cooking game sprites that will be converted into 1-bit Bayer dithering at final 160px width. Keep shapes very clear and plain. No words. No scene. No cast shadow. Background must be entirely transparent.
Subject: Simplify ONLY the separate crank: a single plain L-shaped arm, one simple dark capsule grip, and a SMALL round axle cap on the right. Remove mounting flange, all bolt details, concentric rings and reflective stripes. At final 160x128 canvas keep right axle center at about (114,63); retain the same offset placement and arm length as described. All remaining canvas transparent. The machine itself must not appear. Plain medium-gray arm with a dark outline.
Canvas aspect ratio 160:128. One object only.
