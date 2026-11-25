# RA2 美术产物（Step B）—— 由 `ra2pipe/` 离线管线生成，**请勿手改**

本目录是 **Step B（美术管线）** 的产物：把 `refs/ra2pack/full/` 里原版红警2 的 MIX 归档
解开，取出 SHP/VXL + PAL，转成 PNG。

## 数据来源（原版 RA2，无尤里复仇）

| 内容 | MIX 位置 | 调色板 |
|---|---|---|
| 建造图标 cameo（简中，60×48） | `LANGUAGE.MIX > CAMEO.MIX` | `CAMEO.PAL` |
| 步兵/飞机 SHP 精灵 | `RA2.MIX > CONQUER.MIX` | `UNITTEM.PAL` |
| 建筑 SHP 精灵（含建造动画/损毁帧） | `RA2.MIX > SNOW.MIX`（+`TEMPERAT/URBAN/GENERIC/CONQUER`、扁平索引兜底） | `UNITTEM.PAL` |
| 载具 VXL 体素模型（+`HVA` 动画） | `RA2.MIX > CONQUER.MIX` / `LOCAL.MIX` | `UNITTEM.PAL` |
| 调色板 | `RA2.MIX` 内的调色板子 MIX（42 项） | — |

- `RA2.MIX` / `LANGUAGE.MIX` 是 **Blowfish 加密**（flags `0x00030000`）；`CAMEOMIX`/`CONQUER.MIX` 等子 MIX 为明文。
- ⚠️ **调色板口径（实测）**：建筑 SHP 用 **`UNITTEM.PAL`**，**不是** `TEMPERAT.PAL`/`SNOW.PAL`（后两者字节相同、且会把建筑渲染成噪点）。
- ⚠️ **子 MIX 命名反直觉**：建筑 SHP 实际存放在名为 `SNOW.MIX` 的子 MIX 里（`TEMPERAT.MIX`/`URBAN.MIX` 里没有这些名字）。

## 目录结构

```
assets/ra2/
├─ cameo/<CAMEO>.png      # 建造图标，60×48，RGBA，文件名 = art.ini 的 Cameo 字段值
├─ shp/<id>.png           # 精灵表（索引 PNG-8，256 色 + 索引 0 透明）
├─ shp/<id>.json          # 精灵表索引：{ id, image, source, palette, cell:[w,h], cols, count, rects[] }
├─ vxl/<id>.png           # 载具体素渲染表：8 朝向横排
├─ vxl/<id>.json          # { id, image, vxl, source, facings:8, frameW, frameH }
└─ ra2_art_index.json     # 汇总清单（计数 + 未解析项）
```

- `<id>` 为 RA2 的 rules 段名（如 `GAPILE`、`MTNK`），与 `data/ra2/buildings.json` / `units.json` 的 `id` 对齐，
  并直接对应各自条目里的 `cameo` / `image` / `voxel` 字段。
- 精灵表 `cell` = SHP 声明的画布尺寸；`rects[i]` = 第 i 帧在表内的 (x,y,w,h)，绘制时把帧贴到格子左上角即可。
- 载具精灵表每行一朝向：帧序 0..7 = 朝向 0..7 各一帧（`frameW × frameH` 为单帧尺寸）。

## 计数（本次生成）

| 类别 | 数量 | 体积 |
|---|---:|---:|
| cameo | 91 | ~0.5 MB |
| shp 精灵表 | 324 | ~9.2 MB |
| vxl 车辆 | 59 | ~2.0 MB |
| **合计** | **434** | **~12 MB** |

`ra2_art_index.json` 的 `missing_shp` / `missing_vxl` 记录未解析项（约 20 个民用/装饰 id）。
载具 `vxl` **0 缺失**。

## 已知口径 / 待办

- 体素渲染为**自研软件光栅**（2:1 等距，仰角 30°，法线光照；法线表取自 `refs/ts-ra2/src/data/vxl/normals.ts`）。
  未做 HVA 逐帧姿态（用静态 0 帧），未做「房屋色（house color）」重映射——当前索引 16..31 显示为基础
  调色板里的红色，RA2 运行时会被替换成玩家阵营色（后续 Step C/D 处理）。
- cameo 的简中文字是**原图自带**（来自 `LANGUAGE.MIX`），非二次绘制。

## 复现命令（沙箱根，须用真身 node）

```
& "C:\Users\admin\AppData\Local\Author Software\nvm\.nodejs\node.exe" ra2pipe\art_build.mjs all
& "C:\Users\admin\AppData\Local\Author Software\nvm\.nodejs\node.exe" ra2pipe\art_preview.mjs
```

管线脚本（`ra2pipe/`，不进工程）：
- `art_lib.mjs` —— MIX 解析/具名子 MIX 寻址、SHP 解码（Format1/2/3）、PAL 解码、PNG 编码（RGBA + 索引 PNG-8）、拼图。
- `vxl_lib.mjs` —— VXL/HVA 解析 + 体素等距渲染器（`normals.ts` 运行时解析）。
- `art_build.mjs` —— 产出管线（`cameo` / `shp` / `vxl` / `all`）。
- 侦察/调试：`art_recon`、`art_locate`、`art_find`、`art_names`、`art_theater*`、`art_pal`、`art_cmp`、`vxl_check`、`vxl_dbg*`。
