# RA2 数据管线（Step A）— 生成物说明

本目录下所有 `*.json` 均为**脚本自动生成**，请勿手改；改生成逻辑后重新跑管线。

## 来源（离线，只读）

| 来源 | 路径 | 说明 |
|---|---|---|
| `rules.ini` | `extracted/rules.ini` | 从原版 RA2 `ini.mix` 解出（541,915 B） |
| `art.ini` | `extracted/art.ini` | 从原版 RA2 `ini.mix` 解出（245,825 B） |
| `general.csf` | `refs/ts-ra2/public/general.csf` | 官方简中字符串表（283,411 B） |

## 重新生成

```
# 真身 node（不要用包装过的 node）
$NODE = "C:\Users\admin\AppData\Local\Author Software\nvm\.nodejs\node.exe"
& $NODE ra2pipe\build.mjs      # 产出本目录 JSON
& $NODE ra2pipe\validate.mjs   # 断言：期望 RA2_SUMMARY ok=50 fail=0
```

## 生成物

| 文件 | 大小 | 内容 |
|---|---|---|
| `meta.json` | ~0.9 KB | 出处哈希 / 各类计数 / `armor_order` / `unresolved`（声明但无 section 的 id） |
| `localization.json` | ~271 KB | `general.csf` 全量 `LABEL -> 文本`（简中），键为**大写**标签 |
| `units.json` | ~212 KB | 步兵 45 / 载具 55 / 飞机 8，`{ infantry, vehicles, aircraft }` 按 id 索引 |
| `buildings.json` | ~371 KB | 建筑 295 |
| `weapons.json` | ~70 KB | 武器（`Damage`/`ROF`/`Range` 齐全的 section + 被引用者） |
| `warheads.json` | ~54 KB | 弹头，含 `Verses` 解出的 11 项护甲倍率表 |
| `factions.json` | ~4 KB | 阵营（allied/soviet）国家名册、国家列表、按阵营的可造清单 |
| `tech_tree.json` | ~145 KB | 每个实体的 `{ kind, cost, tech_level, prerequisites, owner, sides, build_cat, factory, image, cameo }` |

## 字段口径（要点）

- **护甲顺序**（`Verses` 的 11 槽，全局常量 `armor_order`）：
  `none, flak, plate, light, medium, heavy, wood, steel, concrete, special_1, special_2`
- **本地化名**：`UIName=Name:E1` → 取冒号后标签 `E1` → 查 `localization.json` 的 `NAME:E1` → `美国大兵`。
- **美术**：`art.ini` 段以 `Image=` 命名（无 `Image` 则回退用 id）；已并入 `cameo` / `alt_cameo` / `voxel` / `sequence` / `foundation` / `buildup`。`Cameo` 指向 RA2.MIX 内的 SHP（Step B 用）。
- **阵营**：`Owner=` 里的国家名映射到 `allied` / `soviet`（来自 `[Sides]` 的 `GDI` / `Nod`）。
- **`extra`**：未进精选字段的原始键值，保留完整性。`prerequisites` 由 `Prerequisite=` 逗号拆分。

## 已知事实 / 坑

- **CSF 字符串值是 `XOR 0xFF` 后再 UTF-16LE 解码**（非裸 UTF-16）。见 `ra2pipe/lib/csf.mjs`。
- `general.csf` 头部声明语言为 0(EnglishUS)，但内容是**简中**（`THEME:INTRO=开场`）。
- 声明于类型列表但**无 rules section** 的 id（原版缺失）：飞机 `APACHE`；建筑 `NAWAST, GARADR, NAHPAD, CAEURO01, CAIRSFGL`。已记入 `meta.unresolved`，管线跳过。
- 本批数据来自**原版 RA2（无尤里复仇）**；后续需要 yuri 版时重跑管线指向对应 MIX 即可。

## 许可

`refs/ts-ra2` 为 **GPL-3.0**，仅作为算法/转换参考。本目录 JSON 由**原版 RA2 数据**转出，供本项目自用。
