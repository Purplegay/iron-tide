# CHANGELOG — 阵营涂装（house color）自选

> 本轮：实现抉择清单 **D1=A / D2=C / D3=A / D4=A / D5=A**（阵营颜色自选），
> 并顺带落 **D6=A**（右键只命令）、**D7=B**（无内容页签自动隐藏）。
> 铁律遵守：判定几何 WYSIWYG 未受影响；每步可验证（见文末验证记录）。

## 1. 一句话结论

RA2 的阵营色是**构建期烘焙**进贴图的（`ra2pipe/art_build.mjs` 把调色板 16..31 号「房色阶」
整体重映射成盟军蓝 `#57a8ff` 后离线出 PNG）。因此运行时改色只能**按颜色（色相）判定**，
不能按调色板索引号（Godot 导入 SHP 索引 PNG 后索引已丢失、展开为 RGBA）。

实现方式：一个 `canvas_item` 着色器 `shaders/house_remap.gdshader`，把「色相 = 盟军蓝」的
像素换成「目标色 × 同一亮度级」。同屏只挂玩家色与敌方色两种材质（按色缓存、共享实例）。

## 2. 判据：归一化方向匹配（不是绝对残差）

房色阶是「基准色 × lv」构成的**过原点直线**（lv ∈ {0.127 … 1.0}，16 级），方向恒定。

- ❌ 绝对残差 `distance(rgb, base*lv)`：在低亮度下残差天然趋近 0，
  实测会把深灰 `(25,25,25)`（残差 0.0635）误判成房色。**弃用。**
- ✅ 归一化方向匹配：`sim = dot(normalize(rgb), normalize(base))`。
  实测中性灰与盟军蓝夹角 ≈ 22°（sim ≈ 0.927），真房色 sim ≈ 1.000。
  取 `cos_tol = 0.995`（≈5.7°），两者之间余量极大。

## 3. 取值来源：只用 `COLOR`，**不要**再乘 `texture(TEXTURE, UV)`

实测（Godot 4.7.2 / Compatibility）：`canvas_item` 片元的 `COLOR` 输入**已经等于**
「顶点色 × 贴图采样」。

| 图元类型 | `COLOR` 输入 | `texture(TEXTURE,UV)` |
|---|---|---|
| 贴图精灵（顶点色=白） | = 贴图色 | = 贴图色 |
| 无贴图图元 `draw_rect` / `draw_circle` / `draw_line` | = 顶点色 | = 画布默认白纹理 |

诊断证据（`_diag`，GAPOWR 不透明像素）：

```
px(…) src=(196,196,220) | got R(COLOR.r)=196 G(TEX.g)=196 B(prod)=190
```

- `R = COLOR.r = 196 = src.r` → COLOR 输入 = 贴图色
- `G = texture(TEXTURE,UV).g = 196 = src.g` → 纹理采样 = 贴图色
- `B = COLOR.b * TEX.b = 190 = (220/255)² ×255` → 两者相乘 = 平方

**结论与坑：**
- 写 `COLOR = texture(TEXTURE, UV)`：无贴图图元会因采样到白纹理而**全部变白**（把血条/选中框/程序化建模刷白）。
- 写 `COLOR = COLOR * texture(TEXTURE, UV)`：贴图色被**平方**、整体变暗。
- ✅ 正解：**只用 `COLOR`**（`vec4 src = COLOR;` 判定后写回 `COLOR`），对两类图元统一正确。

## 4. 改动清单

### 新增
- `shaders/house_remap.gdshader` —— 房色重映射着色器（`base_color` / `target_color` / `cos_tol` / `min_len` / `strength`）。
- `scripts/core/house_color.gd`（`class_name HouseColor`）—— 中央工具：
  8 色色板（读 `data/factions.json` 的 `house_palette`，回落内置常量）、玩家色 `player_id`/`player_hex`、
  敌方避让 `enemy_color_for()`、按色缓存 `material_for()`、上色 `apply_to()`、`set_player()` / `sync_hp()`。
- `scripts/screens/paint_screen.gd` + `scenes/paint.tscn` —— 「涂装工房」页面（8 色色板 + 真实精灵实时预览）。
- `CHANGELOG_house_color.md`（本文）。
- 验证探针：`_shader_probe.gd/.tscn`、`_palette_sheet.gd/.tscn`、`_battle_shot.gd/.tscn`、`_paint_shot.gd/.tscn`。

### 修改
- `data/factions.json` —— 新增顶层 `house_palette`（8 色，单一事实源）。
- `scripts/autoload/meta_progress.gd` —— 新增存档字段 `house_color`（默认 `"allied"`），
  读写 + `set_house_color()`；`_ready()` 载入后同步 `HouseColor`。
- `scripts/ui/hp_bar.gd` —— 新增 `static var ally_fill/enemy_fill`，`faction_color()` 改为读它们（D3=A 血条打通）。
- `scripts/units/unit.gd` / `scripts/buildings/building.gd` —— `_col` 改由 `HouseColor.apply_to()` 决定，
  加入 `house_colored` 组，新增 `refresh_house_color()` / `_faction_hex()`。
- `scripts/screens/hud_main_menu.gd` —— 新增「涂 装」入口（D5=A），面板高度 480→540。
- `scripts/world/battle.gd` —— `right_click_scroll` 默认 `true → false`（D6=A：右键只命令，中键拖屏）。
- `scripts/ui/hud.gd` —— `_add_prod_tabs()` 增加 `_tab_available()` 过滤，无内容页签自动隐藏（D7=B，当前海军页签被隐藏）。

## 5. 覆盖范围（D3=A）与避让（D4=A）

- 单位 / 建筑：`_draw_ra2_sprite` 的贴图由节点材质重映射；程序化兜底图元的 `_col` 同步改为阵营色。
- 血条：`HpBar` 友军 / 敌军填充色跟随阵营色。
- 选中框 / 建造预览：由 `_col` 派生的蓝色图元会一并被重映射（同色相），默认色下为零变化。
- 敌方避让：若敌方阵营本色与玩家色距离 < `CLASH_DIST=0.30`，自动改取色板中离玩家最远的一色。
  实测：玩家=战火红 → 敌军=冰原青；玩家=熔岩橙 → 敌军=冰原青；玩家=盟军蓝/旭日黄/冰原青 → 敌军保留战火红。

## 6. 验证记录（每步可验证）

| 验证 | 方法 | 结果 |
|---|---|---|
| 着色器 = CPU 真值 | `_shader_probe` 对 6 张真实素材逐像素比对（建筑/坦克/步兵） | **0 mismatch**（改色像素占比 12.3%） |
| 无贴图图元不误伤 | `_shader_probe` 第 2 部分：draw_rect 画 盟军蓝 3 级 / 白 / 灰 / 红 / 青 / 黄 | **8/8 OK**（仅房色变） |
| 视觉对照 | `_palette_sheet`：8 色 × 建筑/载具/步兵 | 灰车身不变、阵营色区随色变（见交付图） |
| 战场端到端 | `_battle_shot`：玩家=丛林绿 进真实 battle.tscn | 基地整体变绿；6 个对象已挂 shader 材质 |
| 页签隐藏 | 同上截图底部页签 | 只剩 建筑/防御/步兵/载具/空军（海军隐藏） |
| 回归：点击命中 | `_verify_hit`（WYSIWYG） | 7/7 `mismatch=0` 未受影响 |
| 无头自检 | `--headless --quit-after 300 res://scenes/battle.tscn` | stderr 0、exit 0 |

## 7. 已知取舍 / 待办

- 血条改用阵营色后，若玩家选「战火红」，血量告警的红色渐变会与本体色同色、可读性下降（可后续加描边区分）。
- 建造预览 / 选中框目前靠「同色相被一并重映射」达成，未做独立着色；若要精确控制可给它们单独材质。
- 只有盟军一套烘焙美术；若将来引入其它阵营专属美术（非盟军蓝底），需给每个阵营配置对应 `base_color`。
