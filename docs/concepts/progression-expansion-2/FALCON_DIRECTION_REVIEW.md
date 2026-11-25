# 游隼方向图生成与检查 · 2026-11-18

后续状态（v0.30.2）：按用户新指定的英雄灰熊制作方式，已接入统一模型坐标的32向离线烘焙机身，详见[模型制作与验证](../../PEREGRINE_MODEL_BAKE.md)。下面保留早期AI候选的历史检查，不是当前游戏资源，也不再代表当前交付状态。

使用内置 image_gen.imagegen，transparent_background=true；未使用 CLI/API 后备方式。以下均是候选素材，不是已交付的 32 向游戏皮肤。当前产品仍为 0.29.31。

## 已保存的外形参考

[八视角外形参考](falcon-direction-reference-v1.png)，1536×1024 RGBA，1,879,444 字节。来源 exec-1ad47f6c-c783-49d6-bd3e-c84fa95d7bfe.png；参考输入 falcon-polar-v1.png。实际有透明通道，不能根据工具预览的灰色底就判断为不透明。每格 alpha≥20 的可见轮廓最小留白为 10～24 像素。

用途仅为后续保持白金机身、宽翼、双尾、深蓝关节的外形参考；相机、精确朝向、枢轴及尺寸尚未成为游戏资产验收依据。未接入资源加载，也未替换原生 ORCA。

### 原始提示词

```text
Use case: stylized-concept. Asset type: production RTS directional sprite sheet, not a concept presentation. Reference image is the approved aircraft design; preserve that exact aircraft identity, pearl-white layered armor, pale gold trim, dark navy joints, glass blue cockpit, two integrated engine nacelles, broad swept falcon wings and two tail fins. Generate ONE clean transparent sprite sheet, 4 columns by 2 rows, exactly EIGHT equal-sized non-overlapping cells, preferably 1536x1024 pixels. Each cell contains exactly ONE complete aircraft, same physical scale and same fixed orthographic elevated camera looking down at 35 degrees, no perspective changes. Aircraft suspended level in flight with landing gear retracted. Eight rigid-object yaw rotations in row-major order: nose points screen RIGHT; DOWN-RIGHT; DOWN toward viewer; DOWN-LEFT; LEFT; UP-LEFT; UP away from viewer; UP-RIGHT. Show physically correct different front/back/side surfaces, never mirror a previous view. Center each aircraft at its mass center in its cell, leave generous transparent gutters around all wings and tail, keep all aircraft same size; no cropped edges. Crisp modern high-detail pre-rendered 3D military vehicle sprites, smooth antialiased edges, not pixel art, no voxel blocks, no painterly softness. Keep recognizable real aircraft silhouette and coherent construction across all eight views. Four underwing missile rails remain attached, no launched missiles. Fixed soft light from screen upper left. Transparent alpha background, NO floor, NO ground shadow, NO shield, NO glow aura, NO exhaust plume, NO lightning, NO UI, NO borders, NO grid lines, NO captions, NO lettering. Engine apertures may have very small ice-blue emissive interiors; runtime effects will be added by the game. Do not reproduce the concept-sheet panels or text.
```

2026-11-18 补充纠正：后续读取RGBA证明连续扇区图预览中的高饱和红边alpha仅1～2/255，alpha≥20的此类像素为0，因此不能把预览彩边当作实色残渣。该图仍因末帧方向越过90°、未满足0～78.75°要求而未采用。见[雷铸资源检查](LEIZHU_DIRECTIONS.md)。

## 未采用的补角候选

四组补角均未接入：

- interleaved-1（5824d1bb）：与基准八方向近似重复，不能证明额外 11.25° 朝向；某格留白仅 1 像素。
- interleaved-2（e3176c22）：部分方向改变，但若干格 alpha≥20 轮廓抵到分格边界，不能按均匀网格直接切片。
- interleaved-3（30e5eb04）：留白足够，但不能与前两组组成均匀、稳定的 32 向序列。
- consecutive-quadrant-v2（6c6837cc）：实际输出1774×887，出现红黄彩边；末帧已朝向下偏左，超出指定0～78.75°扇区。未把八张不同图等同于八个正确角度。

原始候选保留在工具输出目录，不加入游戏资源。只读检测没有改图、抠图或改透明通道。数值证据：`.validation/hero-art-review-20261118/source-alpha-framing.json`，复查入口同目录 `inspect_sources.py`。这些检测只证明通道与留白，不证明方向正确、动作自然或用户视觉认可。

### interleaved-1

输入：概念图 falcon-polar-v1.png 与上述八视角参考。

```text
Use case: stylized-concept. Asset type: production RTS directional sprite sheet. Image 1 is the approved aircraft concept; image 2 is the accepted canonical eight-view sprite sheet, use as identity/camera/scale/lighting reference, NOT an edit target. Make a NEW sheet of the EXACT SAME aircraft design at eight NEW intermediate yaw angles. Preserve pearl-white layered armor, pale gold trim, navy joints, glass blue cockpit, two integrated engine nacelles, broad swept falcon wings, two tail fins and attached missile rails, same proportions at every angle. One sheet, 4 columns by 2 rows, exactly eight aircraft, one per equal cell, 1536x1024. Fixed orthographic elevated camera looking down 35 degrees, aircraft level in flight, landing gear retracted. All eight at matching size, centered at mass center in their own cells, generous fully transparent gutters. Clean modern detailed 3D prerendered game sprites, crisp readable small details and sharp antialiased edges, not pixel art. Lighting fixed from upper left. New angles in ROW-MAJOR order are specified next; rotate the physical aircraft, never mirror, and do NOT repeat the cardinal/diagonal views from the reference sheet. Preserve all structural parts. Transparent alpha background, NO ground, shadow, backdrop, aura, exhaust plume, shield, UI, labels, grid, borders, lettering or launched missiles. Tiny ice-blue engine interiors only. Interpret 0 degrees as nose pointing screen right, 90 down, 180 left, 270 up. Required yaw headings: 11.25 degrees (nose nearly right but slightly toward lower-right); 56.25 degrees (between down-right and down, closer down-right); 101.25 degrees (nearly down but slightly left); 146.25 degrees (between down-left and left); 191.25 degrees (nearly left but slightly up); 236.25 degrees (between up-left and up); 281.25 degrees (nearly up but slightly right); 326.25 degrees (between up-right and right).
```

### interleaved-2

输入：概念图 falcon-polar-v1.png 与上述八视角参考。

```text
Use case: stylized-concept. Asset type: production RTS directional sprite sheet. Image 1 is the approved aircraft concept; image 2 is the accepted canonical eight-view sprite sheet, use as identity/camera/scale/lighting reference, NOT an edit target. Make a NEW sheet of the EXACT SAME aircraft design at eight NEW intermediate yaw angles. Preserve pearl-white layered armor, pale gold trim, navy joints, glass blue cockpit, two integrated engine nacelles, broad swept falcon wings, two tail fins and attached missile rails, same proportions at every angle. One sheet, 4 columns by 2 rows, exactly eight aircraft, one per equal cell, 1536x1024. Fixed orthographic elevated camera looking down 35 degrees, aircraft level in flight, landing gear retracted. All eight at matching size, centered at mass center in their own cells, generous fully transparent gutters. Clean modern detailed 3D prerendered game sprites, crisp readable small details and sharp antialiased edges, not pixel art. Lighting fixed from upper left. New angles in ROW-MAJOR order are specified next; rotate the physical aircraft, never mirror, and do NOT repeat the cardinal/diagonal views from the reference sheet. Preserve all structural parts. Transparent alpha background, NO ground, shadow, backdrop, aura, exhaust plume, shield, UI, labels, grid, borders, lettering or launched missiles. Tiny ice-blue engine interiors only. Interpret 0 degrees as nose pointing screen right, 90 down, 180 left, 270 up. Required yaw headings: 22.5 degrees (nose halfway between right and down-right); 67.5 degrees (halfway between down-right and down); 112.5 degrees (halfway between down and down-left); 157.5 degrees (halfway between down-left and left); 202.5 degrees (halfway between left and up-left); 247.5 degrees (halfway between up-left and up); 292.5 degrees (halfway between up and up-right); 337.5 degrees (halfway between up-right and right).
```

### interleaved-3

输入：概念图 falcon-polar-v1.png 与上述八视角参考。

```text
Use case: stylized-concept. Asset type: production RTS directional sprite sheet. Image 1 is the approved aircraft concept; image 2 is the accepted canonical eight-view sprite sheet, use as identity/camera/scale/lighting reference, NOT an edit target. Make a NEW sheet of the EXACT SAME aircraft design at eight NEW intermediate yaw angles. Preserve pearl-white layered armor, pale gold trim, navy joints, glass blue cockpit, two integrated engine nacelles, broad swept falcon wings, two tail fins and attached missile rails, same proportions at every angle. One sheet, 4 columns by 2 rows, exactly eight aircraft, one per equal cell, 1536x1024. Fixed orthographic elevated camera looking down 35 degrees, aircraft level in flight, landing gear retracted. All eight at matching size, centered at mass center in their own cells, generous fully transparent gutters. Clean modern detailed 3D prerendered game sprites, crisp readable small details and sharp antialiased edges, not pixel art. Lighting fixed from upper left. New angles in ROW-MAJOR order are specified next; rotate the physical aircraft, never mirror, and do NOT repeat the cardinal/diagonal views from the reference sheet. Preserve all structural parts. Transparent alpha background, NO ground, shadow, backdrop, aura, exhaust plume, shield, UI, labels, grid, borders, lettering or launched missiles. Tiny ice-blue engine interiors only. Interpret 0 degrees as nose pointing screen right, 90 down, 180 left, 270 up. Required yaw headings: 33.75 degrees (nose almost down-right, slightly more toward right); 78.75 degrees (almost down, slightly toward down-right); 123.75 degrees (almost down-left, slightly toward down); 168.75 degrees (almost left, slightly toward down-left); 213.75 degrees (almost up-left, slightly toward left); 258.75 degrees (almost up, slightly toward up-left); 303.75 degrees (almost up-right, slightly toward up); 348.75 degrees (almost right, slightly toward up-right).
```

### consecutive-quadrant-v2

输入：上述八视角参考。

```text
Use case: stylized-concept. Generate an animation sprite sheet for the aircraft shown in the reference. This is a directional animation, NOT eight different views around the full circle. CRITICAL: all EIGHT planes face into the SAME bottom-right quadrant. Each successive cell rotates the plane clockwise by only 11.25 degrees. The complete sheet spans less than ONE QUARTER TURN, not a full turn. Reference is identity only: preserve pearl white armored fuselage, gold edges, dark navy falcon wing emblem, blue canopy, twin nacelles, twin tails, missile rails. Exactly 4 columns and 2 rows of equal cells, row-major timeline. CELL1 nose due screen RIGHT, horizontal body. CELL2 nose slightly down of right (11.25 degrees). CELL3 nose down-right at 22.5 degrees. CELL4 nose down-right at 33.75 degrees. CELL5 nose precisely DOWN-RIGHT at 45 degrees. CELL6 nose more down than right at 56.25 degrees. CELL7 nose mostly down but slightly right at 67.5 degrees. CELL8 nose almost straight DOWN, only 11.25 degrees right of down (78.75 degrees). There are NO aircraft facing left or up in this sheet! Fixed elevated orthographic camera at 35 degrees, same aircraft rig rigidly yawing, not a flat image rotation. Wings and tails must maintain the same geometry in every cell. Same scale, generous transparent margins, full aircraft uncropped. Crisp modern prerendered 3D military game sprites with sharp antialiased edges, highly readable panelwork, not pixel art. Transparent alpha background, no floor, no shadow, no background color, no text, no cell borders, no arrows, no effects, no exhaust, no shield. Landing gear retracted.
```

## 下一步仍需满足

独立32方向与一致轮廓；逐方向枢轴、原生大小标定及命中/选择同步；阵营色；运行时悬停喷流、维护下降、迫降受损与修复起飞；资源体积控制；后台渲染验证及使用者视觉确认。雷铸独特外观仍未制作。已有夜枭和猎蛛不继续改动。

## 2026-11-18 v0.29.84状态复核

本文前段的0.29.31版本及“雷铸未制作”是当时记录；雷铸随后已接入独立32向素材。游隼当前仍未接入合格完整32向机身，旧候选不满足要求，后续补角请求曾被工具安全检查拦截。本轮仅核对已有素材，不重试、不换提示或生成渠道绕过，未采用重复／融合方向；项目机身保持原生。运行时喷流、维护和迫降等既有表现不等于专属机身已完成。
