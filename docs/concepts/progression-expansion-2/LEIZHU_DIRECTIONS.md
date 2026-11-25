# 雷铸「铜冕雷炉」方向图

2026-11-18，内置 `image_gen.imagegen` 生成，透明背景；未使用 CLI/API 后备方式。参考为已认可的 `thunder-copper-v1.png`。本次采用两张4×4方向图；未采用首次名为32向、实际只有28格的候选，也未采用后续重新生成的边缘清理稿。

源文件：[基础16向](leizhu-directions-base-v1.png)、[相邻16向](leizhu-directions-offset-v1.png)。对应生成文件 `exec-7765a019-6f1e-49f4-a1b2-2ff1faad4dc9.png` 与 `exec-1a108b76-c7e1-4e8f-ab89-52ac47948838.png`。源图均1254×1254，不能按整数313尺寸连续偏移切图；每格边界分别取整。

运行资源为 `iron_tide/assets/cosmetics/heroes/leizhu_copper_32.webp` 和同名JSON。32个独立192×192格，8×4排布，WebP质量95，430692字节；Godot导入开启mipmap，线性采样。没有镜像或相邻方向混合。`tools/pack_leizhu_directions.gd` 可从两张源图重建小图、可见边界、地面枢轴及炉芯/线圈挂点，源SHA256记录在JSON中。打包只做标准资源切片、尺寸和编码转换，保留源文件。

枢轴由上半部琥珀炉芯位置及固定模型高度标定；缩放按八个基准方向的原生TTNK平均可见宽度计算，避免每个方向单独缩放引起大小跳变。实际方向和外形已作制作检查，但这不是精确三维模型的一致性证明；转向观感仍需使用者试玩确认。

### 透明预览的纠正

工具预览里醒目的红色杂边不能直接判作实色残渣。本次直接读取RGBA：基础图的高红低绿蓝像素620个、相邻图6359个，alpha均只有1～2/255，alpha≥20者均为0。后续所谓清理稿反而改变了模型细节，不予采用。实际Godot渲染已核对一次；不能通过不断重新生成来修复仅在工具预览中被放大的透明像素。游隼连续扇区候选也得到相同alpha1～2结果；其方向超出要求仍是拒用依据。

## 基础16向提示词

```text
Use case: stylized-concept. A CLEAN production RTS sprite sheet based on the reference Tesla tank concept. Exactly SIXTEEN separate tank sprites in a precise FOUR-COLUMN by FOUR-ROW square grid. All equal cells, one complete tank per cell, generous transparent gutters. ONE coherent tank rotates clockwise in 22.5 degree increments for a full360 degree turn. Each row spans only one quadrant: row1 fronts point RIGHT, right/down22.5, down-right45, mostly-down67.5; row2 DOWN90, down/left112.5, down-left135, mostly-left157.5; row3 LEFT180, left/up202.5, up-left225, mostly-up247.5; row4 UP270, up/right292.5, up-right315, mostly-right337.5. Frame1 shows right-facing side profile; frame5 shows front armor and white star head-on; frame9 left-facing side profile; frame13 shows rear cable reel and exhaust grille head-on. Front is the sloped hood with white star, REAR is big cable reel. Do not duplicate directions or reverse front/back. Fixed elevated orthographic camera at35degrees looking down; rigid3D yaw, NOT flat rotation, NOT perspective camera orbit. Preserve exact reference design: low rounded dark-red and gunmetal chassis with two continuous heavy tracks; copper circular crown coil around amber reactor; white ceramic insulators; large rear cable spool. Same number of parts, same silhouette and mass-center in every cell. No barrels or legs. Crisp modern 3D prerendered sprites, fine panels but readable at128pixels, no pixel art, no voxel blocks. Transparent background; edges perfectly clean and neutral, ABSOLUTELY NO bright red or yellow fringe, no colored outline, no halos. No floor, no ground shadow, no drop shadow, no effects, no lightning, no labels or grid lines. Soft warm amber light only inside the reactor glass. Produce a square image.
```

## 相邻16向提示词

输入仅为基础16向图，保持外形和光照。

```text
Use case: stylized-concept. Generate a NEW companion directional animation sheet for the exact Tesla tank shown in reference image1. Reference image1 is an identity/scale/lighting/layout reference, NOT an edit target. Exactly16 tank sprites, FOUR COLUMNS by FOUR ROWS, square image, same generous transparent margins. This sheet contains ONLY the INTERMEDIATE views halfway BETWEEN each pair of views in the reference. Do not copy its cardinal or diagonal angles. Rotate every corresponding reference-cell tank clockwise by11.25degrees. The16 yaw angles in row-major order are11.25,33.75,56.25,78.75;101.25,123.75,146.25,168.75;191.25,213.75,236.25,258.75;281.25,303.75,326.25,348.75. At0degrees the front sloped hood with white star points screen right;90degrees points down towards viewer;180left;270up away. Thus first cell is slightly down of right, fifth cell slightly LEFT of down, ninth slightly UP of left, thirteenth slightly RIGHT of up. Last cell in each row approaches the next cardinal direction but stops11.25degrees short. Physically rigid3D model yaw, not flat rotation. SAME fixed elevated orthographic camera35degrees and upper-left illumination, same absolute size as reference. Preserve exact chassis length,2tracks, roadwheel counts, rear cable reel, two copper rings, central amber reactor and ceramic insulators in every angle. Show the correct back surface when rotated away. Modern crisp highly detailed3D game asset, not pixel or voxel. Fully transparent alpha, no floor, shadows, grid, titles, UI, lightning, effects, cables or borders. Clean neutral antialiased edge; no red/yellow edge spill or isolated pixels. All16poses must be new intermediate angles, never a repeat of reference views.
```
