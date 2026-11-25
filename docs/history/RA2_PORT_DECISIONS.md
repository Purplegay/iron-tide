# Iron Tide —— 「选项性抉择」清单 v1

> 生成时间：2026-10-10
> 用途：把后续所有需要你拍板的分叉**一次性列全**，你只需要按编号回 `D1=B, D2=C, D3=A …`，我就按你的选择开工，不再来回问。
> 配套文档：`iron_tide/RA2_PORT_ROADMAP.md`（长期路线图）、`iron_tide/CHANGELOG_ra2_*.md`（历次改动）

---

## 0. 先说你要的：游戏工程目录

**工程根（Godot 项目根，`project.godot` 所在）：**

```
C:\Users\admin\AppData\Local\Temp\chatbox-sandbox\2d2b633f-f7d3-4f49-9f74-b1dd9f539295\iron_tide
```

**Godot 可执行文件（4.7.2 stable）：**

```
C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe      # 推荐，带 stdout/stderr
C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64.exe              # 无控制台版
```

**工程根内部结构：**

```
iron_tide/
├─ project.godot          # 主场景 res://scenes/main.tscn，GL Compatibility，1600x900
├─ icon.svg
├─ README.md  RA2_SOURCE_PLAN.md  RA2_PORT_ROADMAP.md  CHANGELOG_ra2_*.md
├─ scenes/                # main.tscn / battle.tscn / lobby / meta / admin …
├─ scripts/
│  ├─ autoload/           # UiTheme Events GameData MetaProgress GM BattleRequest
│  ├─ core/               # iso.gd  effects.gd  ra2_art.gd  ui_kit.gd
│  ├─ world/              # battle.gd  path_service.gd  flow_field.gd  placement.gd  resource_node.gd
│  ├─ units/              # unit.gd
│  ├─ buildings/          # building.gd
│  ├─ ui/                 # hud.gd  ra3_skin.gd  hp_bar.gd  hp_bar_control.gd  unit_icon.gd
│  ├─ screens/            # battle_screen.gd  lobby.gd  meta_screen.gd  hud_main_menu.gd
│  └─ admin/              # admin.gd  data_compiler.gd
├─ data/                  # units/combat/factions/meta/cards/skills/waves/ra2_allied.json
│  └─ ra2/                # buildings/factions/localization/tech_tree/units/warheads/weapons.json（管线生成，禁手改）
├─ assets/ra2/            # shp(419) / vxl(129) / cameo / bldanim   共 639 张 PNG≈15.5MB
└─ .godot/                # 导入缓存
```

**⚠️ 重要提醒**：这个路径在 **Chatbox 会话沙箱**里（`...\Temp\chatbox-sandbox\<session-id>\`）。会话沙箱重置时可能被清空。
如果你要拿去给别的 AI 长期用，建议我把工程打包成 `iron_tide.zip` 交付（我可以现在就做），你解压到自己的固定目录（例如 `D:\dev\iron_tide`）再用。

---

## 1. 这份清单怎么用

- 每项给 **选项 A/B/C…**、**代价**、**我的推荐**、**验收标准**。
- 你可以只回 **第 6 节「懒人默认包」** 一个词（"全按默认"），我也能直接开工。
- 我推荐 **A/B 两类并行**：颜色/UI/卡池（写代码，我这边做）与 音效素材/美术（需要你给文件）不冲突。

---

## 2. 抉择总表（一眼版）

| # | 议题 | 关键选项 | 我的推荐 |
|---|---|---|---|
| D1 | 阵营颜色自选的**形态** | A 固定色板 / B 色板+自由取色 / C 只改 UI 强调色 | **A**（RA2 房色就是固定 8 色） |
| D2 | 颜色**技术实现** | A 构建期多套色板 / B 运行时 shader 重映射 / C 混合 / D 只改 UI 与程序化部分 | **C**（shader 为主 + UI 变量） |
| D3 | 颜色**作用对象** | A 单位+建筑+血条+选中框+建造预览 / B 只单位建筑 / C 再加 HUD 强调色+指令甲板 | **A**（+可选 C） |
| D4 | **敌方**是否自动避让撞色 | A 自动换色 / B 不换（保持红） / C 手动指定 | **A** |
| D5 | 选择**入口位置** | A 主菜单设一页"涂装" / B 局外"档案"页 / C 战斗中设置面板 | **A**（B 作为附带） |
| D6 | 右键语义（**"太难绷"主因**） | A 右键只命令（中键/边缘/战术地图拖屏） / B 保留双用 / C 可切换 | **A** |
| D7 | 海军页签可见性 | A 常驻+空态 / B 无内容自动隐藏（RA3 式） / C 有船厂才出现 | **B** |
| D8 | 音效素材 | A 你提供 mix / B 先做字幕+事件骨架 / C 用免费音效占位 | **A+B 并行** |
| D9 | 卡池三条默认值 | 见 §7 | **照默认开工** |
| D10 | 维修厂 A4 语义 | A 进驻手动修 / B 自动回厂 / C 双模式 | **A** |
| D11 | 矿石再生 A5 | A 缓慢再生+耗尽切换 / B 不耗尽 / C 可被占点 | **A** |
| D12 | 战术地图 B3 | A 全屏战术图 / B 小地图+点击跳转 / C 都要 | **B→A 分两步** |
| D13 | 编队/选择热键 B4 | A 对齐 ts-ra2 全套 / B 只补最缺的 3 个 | **A** |
| D14 | 边缘滚屏 | A 保持现参数 / B 速度可调+可关 | **B** |
| D15 | 建造动画 A6 | A 保留脚手架+进度 / B 加真实 SHP 建造序列 | **B** |
| D16 | 局外养成重心 | A 卡池优先 / B 指挥官/皮肤优先 / C 数值升级优先 | **A** |
| D17 | 每轮交付物 | A 截图+日志+md 三件套 / B 只截图+日志 | **A** |

---

## 3. D1–D5：阵营颜色自选（本轮新增需求）

### 现状（我核查过的事实）

- 每阵营在 `data/factions.json` 里只有一个 `color` 字段：`allied #57a8ff` / `soviet #ff5b4a` / `empire #ffd24a` / `swarm #a56bff`。
- 单位与建筑都通过 `_faction_color(fid)` → `GameData.get_faction(id).get("color")` 取色，存进 `_col`，用于：程序化建模配色、受击/开火特效色、选中条图标底色。
- **但是 RA2 原图（SHP/VXL）的颜色是「烘焙进贴图」的**：`ra2pipe/art_build.mjs` 里 `SIDE_HOUSE_RGB = { allied: [0x57,0xa8,0xff] }`，把 `UNITTEM.PAL` 的 16..31 号"房屋色阶"整体重映射成盟军蓝，然后**离线生成 PNG**（SHP 是索引 PNG，VXL 是 RGBA PNG）。
  → 也就是说：**你在运行时改 `_col`，RA2 贴图不会跟着变**，会出现"程序化单位变绿、RA2 单位还是蓝"的两面派现象。
- 血条 `HpBar.faction_color(side)` 只有 `ally / enemy` 两个常量色，与阵营色**没打通**。
- 目前**没有 `shaders/` 目录**，工程里没有任何 `.gdshader`。

**结论**：阵营颜色自选不是"加个下拉框"那么简单，真正的工作量在 D2（怎么改贴图的颜色）。

### D1 颜色自选的形态

| 选项 | 内容 | 代价 | 评价 |
|---|---|---|---|
| **A 固定色板（推荐）** | 8 个 RA2 房色：蓝`#57a8ff` 红`#ff5b4a` 黄`#ffd24a` 绿`#4ade80` 紫`#a56bff` 青`#22d3ee` 橙`#ff8a3d` 灰白`#cbd5e1` | 小 | **最还原 RA2**（RA2 就是 8 房色），也最好做 shader 重映射（目标色已知） |
| B 色板 + 自由 HSV 取色 | 色板色 + 一个 Hue/Sat 滑条 | 中 | 自由度高，但 RAID 美术在某些色相下会"脏"（阴影/高光对比崩），且需要"最接近色板"兜底 |
| C 只改 UI 强调色 | 只改 HUD/图标/选中框，不动战场贴图 | 极小 | 半天能完，但战场上看不出区别，不满足"阵营色自选"的本意 |

**推荐 A**；若你都要，建议 **A 先做，B 后补**（B 落地时用"A 色板 + 微调 hue±15°"限制范围）。

### D2 颜色技术实现（**最关键的一项**）

| 选项 | 做法 | 优点 | 代价 / 风险 |
|---|---|---|---|
| A 构建期多套色板 | 扩展 `art_build.mjs` 的 `SIDE_HOUSE_RGB` 为 8 个色，`art_build.mjs --all` 生成 8 套 PNG，运行时按颜色选 `tex` | 100% 还原 RA2 房色机制；零运行时性能开销；无"误伤" | 贴图体积 **15.5MB → ~120MB**；`--import` 变慢；切色要重载贴图；存储/打包变重 |
| **B 运行时 shader 重映射（推荐作为主方案）** | 新建 `house_remap.gdshader`：因为"房色阶"是过原点的一条直线色阶（`base * lv`），shader 里判 `normalize(rgb)` 是否≈`normalize(base)`，命中就换成 `target * lv` | 零资产膨胀；**即时切换**（色板点击即刻全员变色）；一套美术走天下 | 需要按素材调容差；可能误伤同色系像素（玻璃、蓝饰、水面反光）——需要逐图目视校验 |
| C 混合（A+B） | 关键单位/建筑用烘焙色板，杂项用 shader | 质量最高 | 工作量最大，两套机制要维护 |
| D 只改 UI + 程序化部分 | 不动 RA2 贴图 | 最省事 | 两面派，不建议 |
| E 用 `modulate` 乘色 | `draw_texture_rect_region(..., modulate)` | 一行代码 | 会把整张图**整体染色/压暗**（阴影也变），完全不是 RA2 的效果 —— **不推荐** |

**推荐：B 为主**（即时、轻量），若某些图 shader 效果不理想，再对那几张图**单独用 A 烘焙**（退化成 C）。这就是我的推荐组合。

**shader 可行性说明（重要）**：SHP 源文件是索引 PNG（`PLTE+tRNS`，我查过：`shp/*.png` 都是 `ct=3`），但 **Godot 导入后会展开成 RGBA**，调色板索引丢失 → 所以**不能**按索引号重映射，只能按"颜色落在房色阶这条直线上"来判定。
`base = #57a8ff = (0.341, 0.659, 1.0)`，色阶是 `base * lv`，`lv ∈ (0.13, 1.0]`。
判定式（示意）：`abs(normalize(c) - normalize(base)) < eps`（eps≈0.03），命中后 `out = target * (max(c)/max(base))`。
这套对不同亮度的房色像素都成立，是最稳的运行时方案。

### D3 颜色作用对象

| 选项 | 覆盖范围 |
|---|---|
| **A（推荐）** | 单位贴图 + 建筑贴图 + 世界血条填充色 + 选中框/选中条图标底色 + 建造幽灵预览色 |
| B | 只单位 + 建筑 |
| C | A + HUD 强调色（指令甲板高亮、按钮描边、进度条、提示文字色）一并换成阵营色 |

**推荐 A**，C 作为"高级开关"（默认关，因为 HUD 全变成红色会很难看）。

### D4 敌方撞色处理

- **A（推荐）**：玩家选了蓝，敌方（swarm）自动避开蓝 → 走"红/紫"优先级；算法：`enemy_color = 色板里与玩家色 ΔHue 最大且未被占用的第一个`。
- B：敌方永远红（简单，但玩家选红时两边同色，战场读不出敌我）。
- C：玩家手动指定敌方色（多一层 UI）。

### D5 选择入口位置

- **A（推荐）**：主菜单（`lobby`/`hud_main_menu`）新增一页 **"涂装 / 阵营色"**，8 个色卡 + 实时预览（一个假单位剪影 + 血条 + 选中框）。
- B：局外 `meta_screen.gd` 的"档案"页里放同一个色卡组件（复用）。
- C：战斗中设置面板（不推荐，局内改色应锁死，避免"开打中途改色"）。

**推荐 A + B 复用同一个组件**；存档字段放 `MetaProgress`（`user://iron_tide_meta.json`）新增 `house_color: String = "allied"`（默认盟军蓝，向后兼容旧档）。

**D1–D5 的验收标准**
1. 切 8 色后，**同屏**拍一张单位/建筑/血条/选中框色卡对照图（我产出 png + 日志）。
2. 重进游戏后颜色仍生效（存档回读成功）。
3. 玩家选蓝时敌方不是蓝；`battle.tscn` 无头 300 帧 stderr 零 `SCRIPT ERROR`。

---

## 4. D6–D8：操作 / UI / 音效（沿用上轮待拍板项）

### D6 右键语义（我认为这是"操控难绷"的第一主因）
- **A（推荐，红警2 语义）**：**右键=纯命令**（移动/攻击/采集/进驻）；拖屏只用 中键拖动 / 屏幕边缘 / 战术地图。→ 手感立刻接近 RA2。
- B：保留现状双用（右键拖屏 + 右键命令），只把"拖屏阈值"调大减少误触。
- C：做一个开关（`设置 → 右键行为`），默认按 A。

**推荐 A**（C 可后补）。改动点：`battle.gd::_input/_unhandled_input`（我还没细读这段，开工时先定位）、`hud.gd` 右键命令派发。
**代价**：需要把"中键拖动"实现出来，否则用户没法拖屏。

### D7 海军页签可见性
- A：现状（6 页常驻，海军空态提示）。
- **B（推荐，RA3 式）**：该阵营 `data/ra2_allied.json` 里没有 naval 条目 / 场上没有船厂时，海军页自动隐藏；有内容再出现。

### D8 音效（**卡在素材**）
现状事实：`extracted/` 里只有 `ai.ini / art.ini / eva.ini / rules.ini`，**沙箱内零音频文件**。
- **A**：你把 RA2 的 `speech.mix / audio.mix / sounds.mix`（或 `refs/ts-ra2` 的音频目录）放进沙箱任意位置并告我路径 → 我做真实音频移植（解 mix → 转 ogg/wav → `Sfx` autoload + 音频总线 SFX/EVA/BGM）。
- **B**：先做骨架（EVA 字幕 + 事件提示 + 音效触发点埋好，`extracted/eva.ini` 已有事件→台词映射），素材到位后只换 clip。
- **C**：用免费音效包占位。
**推荐 A+B 并行**（B 现在就能做，不阻塞）。

---

## 5. D10–D17：其余内容项（都要你点头才动，避免走错方向）

### D10 维修厂 `GADEPT`（tag=repair）语义 —— Phase A4
- **A（推荐，RA2 手动词）**：把残血载具**右键**到维修厂 → 进驻修理，按住才算钱，修满自动弹出。
- B：载具残血自动回厂排队（更自动化，但和 RA2 语义有偏差）。
- C：A + 全局"自动维修"开关。
**验收**：修一辆 `MTNK` 从 40% → 100%，扣费日志正确。

### D11 矿石再生 / 矿点耗尽 —— Phase A5
- **A（推荐）**：画面上每个 `resource_node` 有 `amount/max_amount=6000`；采空后**变暗并原地缓慢再生**（速度可配 `data/meta.json` 或 `combat.json`）；矿车自动切换最近未空矿点；矿点**不可被占点**但可被矿车覆盖停放。
- B：永采不空（省事，但经济无张力）。
- C：可被建筑占点（RA2 的 "ore purifier" 玩法）。

### D12 战术地图 —— Phase B3
- **A**：全屏战术图（`TAB` 或按钮），左键跳转视角、右键画视野框。
- **B（推荐先做）**：右下小地图（红警2 有），点击/拖动跳转 + 敌方红点 + 雷达事件闪烁。
- **C**：A+B 都做（先 B 后 A）。

### D13 编队与选择热键 —— Phase B4
现工程已有：`1–9,0` 编队、`T` 选同型、`P` 全选、`H` 回主基地、`M/N` 上下一单位、`C` 居中。
- **A（推荐）**：按 `refs/ts-ra2/src/gui/screen/game/worldInteraction/keyboard/KeyBinds.ts` **逐条对齐**（含 `Ctrl+数字`建队、双击居中、双击同类全选、`Tab` 循环同类）。
- B：只补最缺的 3–5 个。

### D14 边缘滚屏 —— Phase B2
- A：保持现参数（`_edge_margin 3~4px` + 角部扩展，已对齐 `MapScrollHandler`）。
- **B（推荐）**：加"滚屏速度"滑条 + 可关闭（RA2 里也能关）。
- C：加"中键拖动 / 空格拖动"并存。

### D15 建造动画 —— Phase A6
- A：保留现在的脚手架 + 进度擦除（已实现）。
- **B（推荐）**：接真实 `bldanim` SHP 建造序列（资产在 `assets/ra2/bldanim`，还没用起来）。
- C：只对大型建筑（`WEAP/GAREFN/NAYARD`）做。

### D16 局外养成重心（原创增量）
- **A（推荐）**：卡池优先（`data/cards.json` v2 → MetaProgress 存档 → 局内三选一 → 卡组/流派页）。
- B：指挥官 / 皮肤 / 涂装（正好和 D1 阵营色联动，可作卡池的"外观奖励"）。
- C：数值升级线（现 `meta.json` 已有档位/升级框架，加内容即可）。

### D17 每轮交付物
- **A（推荐）**：`改动 md + 实测日志 txt + 有头截图 png` 三件套（和本轮一致，便于你复核）。
- B：只截图 + 日志。

---

## 6. 懒人默认包（你若回"全按默认"，我就按这套开工）

```
D1=A 8 色固定色板        D2=B 运行时 shader（不满意再烘焙）   D3=A（C 做开关，默认关）
D4=A 敌方自动避让        D5=A 主菜单"涂装"页 + 局外复用组件   D6=A 右键只命令
D7=B 海军页动态隐藏      D8=A+B 并行（先骨架）                D9=照默认（见 §7）
D10=A 手动进厂修         D11=A 缓慢再生+耗尽切换              D12=B 小地图 → A 全屏
D13=A 对齐 ts-ra2 全套   D14=B 速度可调+可关                  D15=B 接 bldanim SHP
D16=A 卡池优先           D17=A 三件套交付
```

---

## 7. D9：卡池三条默认值（沿用上轮，等你确认）

1. **卡的语义**：只做「全局 buff + 经济」两类，复用现有 17 个 token（不引入新的战斗表达式语言）。
2. **局内获取**：三种全开 —— ① 波次全清后三选一 ② 任务目标达成必得 ③ 定时事件三选一。
3. **卡组**：上限 8 张；开局只让 `start:true` 的卡生效（"起始卡"）。

**现档位事实**（`data/cards.json`，未动过）：`version:1`、`enabled:false`、`pools[0]=standard 常规征召池`、`cost.credits=1500`、`pity soft 40 / hard 60`、3 个 entries（`soviet_tesla` epic / `empire_mecha` epic / `soviet_twinblade` legend）。

需要你顺带拍板的**卡池子项**（可全按默认）：
- 7a 稀有度与权重：`common 60 / rare 30 / epic 8 / legend 2`？（默认这套）
- 7b 重复卡：转成"升级点数"而不是纯丢弃？（默认：转 1 点卡等级，最多 +3）
- 7c 抽卡货币：沿用 `credits`，一次 1500？（默认沿用）
- 7d 保底是否沿用 `soft 40 / hard 60`？（默认沿用）
- 7e 卡是否影响 PvP/联机平衡？（默认：本作单机为主，不做平衡约束）

---

## 8. 交给别的 AI 的「交接包」（可直接复制粘贴）

**硬约束（必须写进对方 AI 的 system prompt）**
```
1. RA2 是规则唯一事实源：refs/ts-ra2 与 data/ra2/*.json。data/ra2/*.json 由 ra2pipe 生成，禁止手改。
2. 判定几何必须 WYSIWYG：所有占点/碰撞/选中/预览共用 Building.footprint_poly()。
3. 每一步都要可验证：无头编译自检 + 有头离屏截图 + 实测日志。
4. 不要用 _check.gd（extends SceneTree + load()，缺 autoload 会假通过）。
```

**常用命令（PowerShell）**
```powershell
$GODOT = "C:\Users\admin\AppData\Local\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe"
$PROJ  = "C:\Users\admin\AppData\Local\Temp\chatbox-sandbox\2d2b633f-f7d3-4f49-9f74-b1dd9f539295\iron_tide"

# 1) 重新扫描 import / class_name（新增 .gd 后必跑一次）
& $GODOT --headless --path $PROJ --editor --quit

# 2) 真实场景无头自检（判定编译/运行是否通过）
& $GODOT --headless --path $PROJ --quit-after 300 res://scenes/battle.tscn > $env:TEMP\o.txt 2> $env:TEMP\e.txt
Select-String -Path $env:TEMP\e.txt -Pattern "SCRIPT ERROR|ERROR"

# 3) 截图必须非 headless，且重定向用绝对路径
```

**关键文件地图（改哪儿找哪儿）**
| 要改的东西 | 文件 |
|---|---|
| 指令甲板 / 页签 / 卡面 / 队列 / 热键 | `scripts/ui/hud.gd`（2400+ 行） |
| 相机 / 缩放 / 滚屏 / 资金 / 出兵 / 建造请求 | `scripts/world/battle.gd` |
| 单位逻辑 / 矿车 / 移动 / 血条锚点 | `scripts/units/unit.gd` |
| 建筑占点 / 建造进度 / 派系色 | `scripts/buildings/building.gd` |
| 阵营定义（颜色在这里） | `data/factions.json` + `scripts/autoload/game_data.gd` |
| 局外存档 | `scripts/autoload/meta_progress.gd` → `user://iron_tide_meta.json` |
| RA2 美术生成 | `ra2pipe/art_build.mjs`（`SIDE_HOUSE_RGB` 房色在这里） |
| 数据生成/校验 | `ra2pipe/build.mjs` + `validate.mjs`（期望 `RA2_SUMMARY ok=50 fail=0`） |

**RA2 参考源码（只读）**：`refs/ts-ra2`（约 1271 个 `.ts/.tsx`）——热键表 `src/gui/screen/game/worldInteraction/keyboard/KeyBinds.ts`；相机 `.../worldInteraction/CameraPanHandler.ts`、`MapScrollHandler.ts`；侧栏卡 `src/gui/screen/game/hud/SidebarCard.ts`。

---

## 9. 我建议的排期与并行分工

| 顺序 | 内容 | 需要你 |
|---|---|---|
| 第 1 刀 | **D1–D5 阵营颜色自选**（含 shader + 涂装页 + 存档） | 回 D1–D5 选择（或"全按默认"） |
| 第 2 刀 | **D6 右键语义 + D7 海军页隐藏 + D14 滚屏可调**（操作手感三连） | 回 D6/D7/D14 |
| 第 3 刀 | **D9 卡池 Phase D**（cards.json v2 → 存档 → 局内三选一 → 卡组页） | 回"照默认"或改参数 |
| 第 4 刀 | **D10/D11 维修厂 + 矿石再生**（经济闭环补齐） | 回 D10/D11 |
| 第 5 刀 | **D8 音效**（骨架现在做；真音频等你给 mix） | 给音频文件路径 |
| 第 6 刀 | **D12/D13 小地图 + 热键对齐** | 回 D12/D13 |

---

## 10. 一句话总结

**颜色自选要不要做？——要做，且真正的工作量在"怎么让 RA2 贴图跟着变色"（我推荐运行时 shader 重映射 + 8 色 RA2 房色板）。**
**其余 16 项都是可选分叉，你回编号或回"全按默认"，我立刻开工第 1 刀。**
