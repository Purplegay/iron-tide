# CHANGELOG —— RA2 表现力第三批：涂装 remap / 动画帧 / 建筑多帧 / 独立炮塔

## 概述
按「你看红警2怎么做就抄写就行了」的原则，本批补齐 RA2 移植中**视觉表现**的四个缺口：
阵营涂装（红→蓝）、步兵行进/开火/阵亡动画、建筑多帧与建造表现、载具独立炮塔。

未打包。冒烟基线保持 `SMOKE_SUMMARY ok=303 fail=0`（既有 1 条 `full_damage` Nil 报错与本批无关，原版同样存在）。

## 1. 阵营涂装 remap（红 → 蓝）
- RA2 的「房色」在调色板里：`UNITTEM.PAL` 索引 **16..31** 是纯红调色带（252,0,0 … 32,0,0）。
- 管线（`ra2pipe/art_build.mjs`）新增 `palFor(sides)`：`sides` 含 **allied** 的单位/建筑改用
  **盟军蓝调色板**（按亮度线性缩放到 `(0x57,0xA8,0xFF)`）重新索引取色；苏军/其他保留原红。
- 覆盖：盟军 7+ 自制单位、全部盟军 RA2 单位与建筑、盟军步兵、盟军补给建筑。
- 效果：盟军整套为蓝色涂装，苏军保持红色——阵营一眼可辨。

## 2. 步兵动画帧（art.ini 序列）
- 管线新增：读取 `extracted/art.ini` 的 `[<image>Sequence]`，导出为 `assets/ra2/shp/<id>.seq.json`。
- `ra2_art.gd` 新增 `seq(id)` / `seq_frame(seq, name, facing, phase)`：按 `start + facing*per + phase` 取实际帧号。
- `unit.gd`：步兵按状态选序列——`Walk`（移动，14fps）/ `FireUp`（开火，16fps）/ `Die1`（阵亡，13fps）；
  存在帧序时优先用帧序，否则回落站立朝向帧。
- 阵亡：有 `Die1` 帧序的步兵先播 0.6s 倒地动画再回收（`_dying` 计时），并即时移出各分组避免被选/被瞄准。
- 覆盖 13 个有帧序的步兵（E1/SHK/YURI/IVAN/DESO/FLAKT/…）。

## 3. 建筑多帧 + 建造表现
- **三损伤态**：RA2 建筑 SHP（6 帧）帧 0/1/2 = 完好/中损/重损，按 `hp/max_hp` 选帧（>66% / 33-66% / <33%）。
- **地面投影**：与单位一致的等距椭圆阴影（`Iso.shadow`）。
- **建造表现**：施工中的 RA2 建筑由游戏既有的**程序化全息**路径绘制（蓝色块随进度自下而上生长 + 进度条），
  本批保留该表现，未叠加 SHP 建造动画（`GAPILEMK` 等素材只有「底板 + 完整」两帧，不适合作逐帧动画）。

## 4. 独立炮塔
- RA2 把旋转炮塔存为**独立 VXL**：`<image>tur.vxl`（炮塔）+ `<image>barl.vxl`（炮管）。
- 管线新增：以**车体与炮塔的共同包围盒原点**分别渲染，产出与原车体同画布对齐的 `<id>_tur.png/.json`
  （帧宽高与车体完全一致，叠加即对齐）。共 11 个载具（MTNK/SREF/FV/TNKD/HTNK/APOC/LTNK/TTNK/HTK/HARV/XCOMET 等）。
- `unit.gd`：绘制时先画车体（`hull_angle` 选帧），再按 `turret_angle` 单独选帧叠加炮塔 sheet——炮塔独立指向目标，
  车体移动朝行进方向。

## 涉及文件
- `ra2pipe/art_build.mjs`（管线：涂装 / 炮塔 / 序列）
- `iron_tide/scripts/core/ra2_art.gd`（`seq()` / `seq_frame()`；`_load()` 透出 `turret/dmg/count` 等字段）
- `iron_tide/scripts/units/unit.gd`（步兵帧序 + 独立炮塔 + 阵亡动画）
- `iron_tide/scripts/buildings/building.gd`（三损伤态 + 地面投影）
- 重新生成 `iron_tide/assets/ra2/{shp,vxl}/` 相关素材（11 炮塔 sheet、13 序列、全量蓝涂装）

## 第三批补丁 · 走路动画优化（2026-10）
**问题**：步兵走路帧原先用**固定帧率** `int(_anim * 14.0)` 取相位 —— 帧率与移动速度脱钩，
加减速、减速 debuff 时腿仍按 14fps 摆动 → **脚下打滑/漂移**；且相位来自全局 `_anim`，
起步时相位随机、整队同步迈步。

**改法**（`iron_tide/scripts/units/unit.gd`，仍走「距离驱动」，与 `_track_phase` 履带同一范式）：
- 新增 `const WALK_STRIDE := 60.0`（一个步循环覆盖的地面距离 ≈ 1 等距地块）与 `var _walk_phase: float`。
- `decorate_tick()`：`_walk_phase = fmod(_walk_phase + delta * clampf(velocity.length() / WALK_STRIDE, 0, 4), 1)`；
  静止时 `_walk_phase = float(_seed % 977) / 977.0`（归位 + 按单位错开相位，避免整队同步迈步）。
- `_draw_ra2_sprite()`：`Walk` 段改用 `int(_walk_phase * per)` 取相位（`FireUp`/`Die1` 仍按时间）。

**实测口径**：修正前固定 14fps = **2.33 圈/秒**；本补丁后 `v≈104px/s → 1.83 圈/秒`，
落在 RA2 参考区间（`BASE_TICKS_PER_SECOND=15`、`AnimProps.defaultRate/2/1.33` ≈ 1.9 圈/秒），
且速度变化时严格不打滑。**参考依据**：`refs/ts-ra2` 的 `Infantry.ts`
（`findFrame = startFrame + facingMult*facing + animFrame`，确认帧序公式正确）、`GameSpeed.ts`、
`AnimProps.ts`。

**未改动**：锚点仍用「全朝向并集」（Guard 底部 41 → 走路底部 38，走路时脚恒定高约 3px；
改用分段锚点会在起步/停步瞬间产生 3px 跳变，故保持不动）；载具履带仍用 `_track_phase`。

## 待办 / 后续
- 建筑动画层（`IdleAnim`/`ActiveAnim`/`ProductionAnim` 独立 SHP 叠加）——下一批。
- 载具行进/开火/死亡动画（VXL 为单帧静态模型，需 HVA 或伪动画）。
- 复核既有「青色大圆盘」待办项（供电范围指示）。

## 第四批补丁 · 地面投影改为 RA2 原版做法（2026-10）

**问题**：建筑/单位的地影是「按碰撞半径画的等距椭圆」(`Iso.shadow(self, Vector2(0, r * 0.35~0.4), r * 1.15~1.5, 0.3)`)，
与美术尺寸无关 → 载具影子只有 ~17px（贴图 73px 宽），看着像没影子；建筑是一块对称圆斑，方向与形状都不对。

**做法（抄红警2）**：

- **建筑**：RA2 建筑 SHP 的**后半段就是影子帧**（总帧数 = 2 × 损伤态数），帧 `[dmg .. 2*dmg-1]` 与主体帧**同画布、同偏移**。
  依 `refs/ts-ra2/.../BuildingShpHelper.ts`（`shadowFrameNo = numImages/2 + frameNo`）
  + `ShadowRenderable.ts`（影子调色板全 0 = 黑、opacity 0.5、与主体同 drawOffset），直接叠加即像素级对齐。
  影子帧只含「露在建筑外」的部分（RA2 美术优化），本体遮挡处不需要补。
  `building.gd:_draw_ra2_sprite()`：`has_shadow = dmg_frames >= 2 and count == dmg_frames * 2` 时
  以 `Color(0,0,0,0.5)` 画帧 `di + dmg_frames`（画在主体之下），否则退回旧椭圆。
- **载具（VXL）**：新增管线影子渲染 —— VXL 沿光向**压平到地面**再投影
  （`ra2pipe/vxl_lib.mjs` 的 `opts.shadow`：按世界高度给恒定屏幕位移 `SH_SX=1.1 / SH_SY=0`，
  取所有体素并集 = 实心剪影），导出 `<id>_shd.png/.json`，与主体**共用同一套 cell 几何**，
  运行时同 `base` 绘制即对齐。炮塔一并压平并与车身并集。
  `unit.gd` 新增 `_ra2_shd`，`_draw_ra2_sprite()` 优先画 `<id>_shd`，无则退回椭圆（步兵 SHP / 程序化单位）。
- **光向标定**：由我们实际要烧的建筑影子帧反推 —— GAPILE / GATECH 影子帧相对主体的内容包围盒都是
  `Δx = +7 / +94`、`Δy = 0`，即 **屏幕正右方、无垂直位移**，故取 `SH_SX > 0, SH_SY = 0`（建筑与载具同一光向）。
  `SH_SX` / `SH_SY` 可用环境变量临时调参：`$env:SH_SX=...; node ra2pipe\art_build.mjs vxl`。

**实测**：`SMOKE_SUMMARY ok=303 fail=0`（保持）；截图 `shd_shot.png`、`shd_shot_zoom.png`
（建筑右侧大片投影、载具右侧投影，方向一致）。

**变更文件**：
- `ra2pipe/vxl_lib.mjs`（shadow 模式）、`ra2pipe/art_build.mjs`（VXL 段导出 `_shd`）
- `iron_tide/assets/ra2/vxl/*_shd.png|.json`（59 个，其中 11 个带炮塔）
- `iron_tide/scripts/buildings/building.gd`、`iron_tide/scripts/units/unit.gd`
- 备份：`ra2d_bak/building.gd.bak_shadow`、`unit.gd.bak_shadow`、`vxl_lib.mjs.bak_shadow`、`art_build.mjs.bak_shadow`、`ra2d_bak/vxl_assets/`（旧载具素材整份）
- 验证场景：`_recover/check4/smoke/_shdshot.gd|.tscn`；探针 `probe_shadow.mjs`、`probe_vxl_shd.mjs`、`imgtool.mjs`

**待办**：步兵（SHP）影子仍用椭圆（该 SHP 后半段为空，无 RA2 影子数据）；若要与建筑完全一致，
可后续在管线里按 `foundation`/贴图宽度烘一个足迹剪影。

---

## 第五批补丁 · 建筑动画改用 RA2 原版做法（2026-10）

**问题**：建筑主体是静态 SHP（每个损伤态一帧），RA2 原版那些动效（烟囱冒烟、雷达转盘、灯闪、厂房吊车）全都没了。

**RA2 原版做法**：建筑的动效不在主体 SHP 里 —— `art.ini` 用 `ActiveAnim` / `ActiveAnimTwo..Four` / `IdleAnim` /
`ProductionAnim` / `SpecialAnim` 指向**独立的动画 SHP**，运行时按各自的 `Rate` 循环播放并叠在主体之上。
（依据参考实现 `refs/ts-ra2/src/engine/renderable/entity/building/BuildingAnimArtProps.ts`：ACTIVE = `ActiveAnim`
+ `ActiveAnimTwo..Four` 常驻；IDLE = `IdleAnim`；`pauseWhenUnpowered = <prop>Powered`。）

**关键结论（这次实测出来的）**

- **动画 SHP 与主体 SHP 同画布**：`GAPOWR_A` 142x110 = `GAPOWR`；`GAPILE_A` 250x148 = `GAPILE`；
  `GAWEAP_A` 266x224 = `GAWEAP`；`GATECH_A` 346x300 = `GATECH`；`GAREFNL1` 210x196 = `GAREFN`。
  → 运行时**复用主体的 `base` 偏移直接画**即像素级对齐，不需要任何额外位移。
- **受损动画藏在同一个 SHP 里**：`[GAPILE_AD]` 写的是 `Image=GAPILE_A` + `Start=16 / LoopStart=16 / LoopEnd=31`。
  所以必须按 `Image=` 解析 SHP，并按段给出的两段帧区间截取（不能按段名找文件）。
- **`Shadow=yes` 的动画 SHP 总帧数 = 2 x 可见帧数**：前一半是可见帧，后一半是**同一动作的黑影**
  （光向偏移已经烘在像素里）→ 运行时黑影帧号 = 可见帧号 + 可见帧数，用 `Color(0,0,0,0.5)` 画在可见帧之下。
  验证：`GAPILE_A` 64 帧，`ActiveAnim` 用 0..15、`GAPILE_AD` 用 16..31，黑影在 32..47 / 48..63；
  `GAAIRC_A` 16 帧 → 可见 8 帧、`LoopEnd=4`；`GAPRIS_B` 36 帧 + `Shadow=yes` → 可见 18 帧。
- **`Rate` 单位**：`帧/秒 = Rate / 60`（缺省 900 → 15fps），即每帧 `60/Rate` 秒。
  实测 `GAPOWR_A rate=220` → 0.27s/帧、9 帧约 2.5s 一循环；`GAPILE_A rate=300` → 5fps。
- **`ZAdjust` 不参与屏幕位置**：参考实现把它当 `translateTowardsCamera`（沿视线移动，正交投影下**屏幕无位移**），
  只影响遮挡排序；art.ini 自己的注释也写「rendering this animation **over** the building」→ 一律画在主体之上。
- `GAGAP_A`（间隙发生器）在本 MIX 包里**缺文件**（`hasFile=false`）→ 该建筑没有动画，已在管线里记入 missing。
- art.ini 的**段头可以带行尾注释**（`[GAPRIS_B]	; Prism Cannon Active Anim`），解析时必须用 `/^\[([^\]]+)\]/`
  而不是 `/^\[([^\]]+)\]$/` —— 这个坑一开始漏掉了 40 多个动画段。

**管线（`ra2pipe/art_build.mjs` 新增 `anim` 段，并已并入 `all`）**

- 解析 `extracted/art.ini`（段头允许行尾注释；值里的内联 `;` 截断；键统一小写）；
  按 `data/ra2/buildings.json` 的 `image`（含 `rules.ini` 的 `Image=` 覆盖，如 `ATESLA→GAPRIS`、`GASPYSAT→GASPST`）取建筑段。
- 逐层解析 `ActiveAnim / ActiveAnimTwo..Four / IdleAnim / ProductionAnim / SpecialAnim` + 各自的 `...Damaged` 变体；
  `NewTheater` 时把名字第 2 个字符换成剧场代号再试一次。
- 硬约束：动画 SHP 的 cell 不等于主体 cell 的层直接丢弃（无法对齐），记入 missing。
- 产出 **动画帧表** `iron_tide/assets/ra2/shp/<IMAGE>.png|json`（与主体同格式同 cell，`kind:"anim"`，
  因此运行时走同一条装载路径，`_load()` 不用改），以及 **建筑层表** `iron_tide/assets/ra2/bldanim/<ID>.json`。
- 实测：`anim: ok=45 sheets=68 miss=8`。

**运行时**

- `ra2_art.gd`：新增 `BLDANIM_DIR` 与 `building_anims(id)`（带缓存、并入 `clear_cache()`），返回该建筑的动画层表。
- `building.gd`：`setup()` 里 `_ra2_anim = RA2Art.building_anims(building_id)`；
  `_draw_ra2_sprite()` 画完主体紧接着 `_draw_ra2_anim(base, sc)`；
  `_process()` 里按各层 `Rate` 推进 `_anim_t`，**只有帧号指纹变化才 `queue_redraw()`**（避免每帧刷）；
  受损时（`_dmg_index() > 0`）自动切到该层的 `dmg` 帧区间。
- 层选择：有 `ActiveAnim*` 就把全部 active 层都画（RA2 语义：常驻）；只有 `IdleAnim` 的建筑（如维修厂 `GADEPT`）走 idle 层。
  `SpecialAnim`（`ATESLA` 的 `GAPRIS_A` 开火帧、`GAREFNOR`）与 `DeployingAnim` / `UnderDoorAnim` / `RoofDeployingAnim`（厂房门）暂不播。

**实测**：`SMOKE_SUMMARY ok=303 fail=0`（保持，无新增 `SCRIPT ERROR`）；
截图 `anim_one_strip.png`（4x 放大 `GAPOWR`，8 帧 x 0.35s → 顶部发光体明显循环）、
`anim_strip.png`（整排 4 帧）、`anim_dmg_strip.png`（完好 / 50% / 20% 三行对照，动画随损伤态切换）。

**变更文件**

- `ra2pipe/art_build.mjs`（新增 `anim` 段）
- `iron_tide/assets/ra2/shp/*`（+68 张动画帧表 x2）、`iron_tide/assets/ra2/bldanim/*.json`（45 个）
- `iron_tide/scripts/core/ra2_art.gd`、`iron_tide/scripts/buildings/building.gd`
- 备份：`ra2d_bak/art_build.mjs.bak_before_anim`、`ra2d_bak/art_build.mjs.bak_anim`、
  `ra2d_bak/ra2_art.gd.bak_before_anim`、`ra2d_bak/building.gd.bak_before_anim`
- 验证场景：`_recover/check4/smoke/_animshot.gd|.tscn`；探针 `probe_anim*.mjs`、`dump_anim.mjs`

**待办**

- `ProductionAnim` 未用（本批建筑都没有这条）；`IdleAnim` 与 `ActiveAnim` 同时存在的建筑（如 `GAYARD` 船厂）
  还没做「生产中就切 active」的状态机，当前规则是「有 active 就走 active，否则走 idle」。
- `GAGAP`（间隙发生器）缺 `GAGAP_A.SHP`，需补 MIX 或自造。
- `ActiveAnimPowered` 还没接电力系统（游戏目前没有逐建筑电力）。
- 动画只用「管线换调色板」的阵营色，没有额外涂装。
## Step C 阶段2 · 删自创单位 + 初始建筑换盟军（本批）

**指令**：开始推进阶段2；把我们自创的单位删了；把初始的建筑换成盟军的。

**A. 删除引擎自创（非 RA2）单位/建筑**
- `data/units.json`：删除 7 个自创单位（`allied_harvester/allied_infantry/allied_javelin/allied_flak/allied_tank/allied_athena/allied_raptor`）
  与 6 个自创建筑（`allied_hq/allied_barracks/allied_factory/allied_airbase/allied_prism/allied_flaktower`）。
  保留 `swarm_*`（敌军）、`soviet_*`、`empire_*` 与 RA2 盟军阵容。
- `game_data.gd`：`RA2_TOKEN_IDS` 去掉自创 id（`BARRACKS=["GAPILE"]`、`RADAR=["GAAIRC","GASPYSAT"]`、`GACNST=["GACNST"]`）；
  `RA2_SUPERSEDE` 置空（自创建筑已不存在，保留常量以兼容调用点）。
- `hud.gd`：`_refresh_build_menu()` 改为直接取 `_building_catalog()`；`_owned_building_ids()` 兜底由 `allied_hq` 改为 `GACNST`。
- `admin/data_compiler.gd`：兜底 id `allied_hq` → `GACNST`。
- `data/cards.json`：删除指向已删单位的池条目（`allied_raptor`/`allied_athena`）。
- `data/skills.json`：删除已删单位的默认技能，并把原玩法**迁移到 RA2 等价单位**（删单位不丢玩法）：
  `allied_tank→MTNK(灰熊坦克)`、`allied_harvester→CMIN(超时空采矿车)`、`allied_raptor→ORCA(入侵者)`、`allied_athena→MGTK(幻影坦克)`。

**B. 初始建筑换成盟军（`battle.gd`）**
- 开局由 `allied_hq + allied_barracks + allied_factory` → `GACNST(建造厂) + GAPOWR(发电厂) + GAPILE(兵营)`，位置基本沿用。
- 采矿车：`allied_harvester x2` → `CMIN`（RA2 超时空采矿车）。

**C. 新增 GACNST 数据（RA2 数据表原本只有素材、无定义）**
- `data/ra2_allied.json`：`buildings` 新增 `GACNST`（盟军建造厂，tags=[structure,hq]，foundation 4x4，
  cost=0（与旧 allied_hq 一致：不进建造菜单、开局建筑），hp=3600，sight=420，Radius=60，ra2_prereq=[]）；
  `art` 新增 `GACNST → {cameo: YARDICON.png, shp: GACNST.png}`；`counts` 同步为 buildings=16/art=35。
- 素材已齐：`shp/GACNST{,_A,_B}.png`、`bldanim/GACNST.json`（activeanim GACNST_A 0..3 + productionanim GACNST_B 0..20）。

**D. 冒烟/截图装配迁移（`_recover/check4/smoke/`，不进 sync）**
- `_smoke.gd/_shot.gd/_ra2shot.gd/_ra2face2.gd` 里所有自创 id 映射到 RA2 等价 id。
- 4 处因数据 schema 变化的断言改写：`harvester_weapon_is_null`（CMIN 无 weapon 键，判 null）、
  `hq_has_build_list`（GACNST 是建造厂，无 builds）、`ra3_cat_antitank_infantry`（JUMPJET 是飞行兵）、
  `ra3_grey_gapile_blocked`（GAPILE 现开局拥有 → 改为可建造）。

**实测**：`SMOKE_SUMMARY ok=289 fail=0`（总数由 303 变化：开局建筑/单位组合改变，无失败、无新增 `SCRIPT ERROR`）。
截图：`iso_ui.png`（建筑菜单已是盟军 RA2 建筑、选中单位为灰熊坦克）、`iso_build.png`（可建造机枪碉堡 GAPILL）、`ra2shot_buildings.png`（RA2 建筑渲染正常）。

**变更文件**
- `iron_tide/data/units.json`、`iron_tide/data/ra2_allied.json`、`iron_tide/data/skills.json`、`iron_tide/data/cards.json`
- `iron_tide/scripts/autoload/game_data.gd`、`iron_tide/scripts/ui/hud.gd`、`iron_tide/scripts/world/battle.gd`、`iron_tide/scripts/admin/data_compiler.gd`
- 备份：`ra2d_bak/*.stepC2_<ts>`（8 个源文件）
- 补丁脚本：`patch_stepC2.mjs`、`patch_stepC2b.mjs`、`patch_smoke.mjs`

**待办（承接）**
- Step C 阶段2 续推：`SpecialAnim` 状态机（ATESLA 开火 / GAREFNOR 维修）、管线门动画层（`GAWEAP_1..4`）、步兵足迹影子。
- `GACNST` 目前不可建造（cost=0，仅开局核心）；若要允许「重造建造厂」需另开建造入口。
- `GAPOWR` 发电厂尚无电力系统联动（引擎暂无逐建筑电力）。

---

## Step C 阶段3：RA2 建筑动画状态机 + 门动画层 + 断言/引用修正

**A. 管线补门动画层（`ra2pipe/art_build.mjs`，Node 字面替换 + must()）**
- `ANIM_PROP` 正则扩展：补 `deployinganim|underdooranim|roofdeployinganim|underroofdooranim`，
  并放开各组变体 `idleanim(two..four)`/`productionanim(two..four)`/`specialanim(two..four)`/`superanim(two..four)`。
- `packAnim` 新增 `loopCount` 字段（来自 art.ini `LoopCount`，缺省 -1=无限循环）；layer/dmg 对象同步注入
  `loopCount` + `oneShot`（`loopCount===1`，供运行时判一次性动画）。
- 重烘结果：`anim: ok=49 sheets=95 miss=8`（此前 ok=45 sheets=68）。
  GAWEAP 门动画层全部产出：`deployinganim(GAWEAP_2/3)`、`underdooranim`、`roofdeployinganim`、`underroofdooranim`
  共 6 层；GADEPT 出现 `specialanim×3`；GAREFN `specialanim(GAREFNOR, loopCount=1 → oneShot)`。

**B. 运行时动画状态机（`iron_tide/scripts/buildings/building.gd`，6 处字面替换）**
- 新增字段：`_anim_state`（idle/active/production/special）、`_anim_group_t`（分组相位计时器，切换归零）、`_special_until`。
- 新增方法：`_anim_kinds()`、`_has_door_anim()`、`play_special(dur)`、`_set_anim_state()`、`_tick_anim_state()`、
  `_base_anim_state()`、`_layer_visible(kind)`、`_anim_frame_for(lay,st)`。
- 语义对齐 ts-ra2：**互斥分组**——special 态只显 `specialanim*`；production 态显门动画组 + 常驻 active/idle；
  active/idle 态只显对应层。special 为一次性，到期自动回落 `_base_anim_state()`。
- 触发钩子：`_fire()` 末尾 `play_special()`（ATESLA 鸡光塔开火播 `GAPRIS_A`，播完回落 `GAPRIS_B` 待机/active）；
  维修 `try_spend` 命中处 `play_special()`（GAREFN 维修/卸矿播 `GAREFNOR`）。
- 一次性层用 `_anim_group_t` 从头播（播完停末帧），循环层仍用全局 `_anim_t`，避免相位耦合。
- `_process` 与 `_draw_ra2_anim` 均加 `_layer_visible` 过滤，仅可见层参与帧指纹与绘制。

**C. 断言修正 / 新断言（`_recover/check4/smoke/_smoke.gd`，不进 sync）**
- 新增 8 条：`bld_has_ra2_anim_layers`、`bld_anim_kinds_nonempty`、`bld_base_state_valid`、
  `bld_layer_visible_active_or_idle`、`bld_special_hidden_by_default`、`bld_anim_loopcount_field`、
  `gaweap_door_anim_layers`、`full_damage_nil_args_ok`。
- 修 `full_damage` 既有 `SCRIPT ERROR`（第 4 参 Nil）：`combat.gd` 的 `full_damage` 重载默认参
  （`attacker_bonus=null, defender_bonus=null`），非 Dictionary 时按 `{}` 处理。

**D. cameo 引用大小写修正（`iron_tide/data/ra2_allied.json`）**
- 6 处引用名与实际文件名不符（Windows 不敏感故本地能加载，跨平台/导出会挂）：
  `GOREP→gorep`、`GWEPICON→gwepicon`、`PILLICON→pillicon`、`PRISICON→prisicon`、
  `GAPICON→Gapicon`、`ASATICON→asaticon`。修正后校验 `bad=0`。

**实测**：`SMOKE_SUMMARY ok=297 fail=0`（由 289 → 297，新增 8 条全过）；`full_damage` 的 SCRIPT ERROR 已消失。
截图：`anim_strip.png`（开局盟军建筑 + 采矿车渲染正常）。

**变更文件**
- `ra2pipe/art_build.mjs`（门动画 + loopCount；BOM=False LF）
- `iron_tide/scripts/buildings/building.gd`（动画状态机；BOM=True LF）
- `iron_tide/scripts/core/combat.gd`（full_damage 默认参）
- `iron_tide/data/ra2_allied.json`（cameo 修正；BOM=False LF）
- `iron_tide/assets/ra2/bldanim/*.json`（重烘，+门动画层）
- 备份：`ra2d_bak/art_build.mjs.bak_stepC2anim`、`building.gd.bak_stepC2anim`、`_smoke.gd.bak_stepC2anim`、`ra2_allied.json.bak_cameo`
- 补丁脚本：`patch_pipe_anim.mjs`、`patch_anim_state.mjs`、`patch_smoke_anim.mjs`、`patch_cameo_case.mjs`

**待办（承接）**
- `GADEPT` 的 `GADEPT_A`（弹出维修/建造用）暂归 special 钩子，但本工程无对应行为 → 待确认改 idle 常驻。
- `GAGAP` 裂缝产生器：`GAGAP_A.SHP` 任何 MIX 均不存在 → 仅主体静态图，无 activeanim（记 miss）。
- 步兵足迹影子（SHP 后半段为空帧）建议管线烘足迹剪影。
- `GACNST` 仍不可重造（cost=0，仅开局核心）。

## Step C 阶段3 补丁：建造占地框 / 碰撞判定对齐 foundation

- `battle.gd` 新增 `foundation_half(bd)`：从 `foundation`（如 `"5x3"`）换算占地半尺寸（`Vector2(w,h) * BUILD_GRID * 0.5`，`BUILD_GRID = 40`），无 `foundation` 时回退 `radius`。
- `_draw_build_preview()` 占地框由 `Vector2(r, r)`（r = 碰撞半径 radius）改用 `foundation_half(bd)`；四角点 & 提示文字位置同步。
- `build_spot_ok()` 重叠判定由圆形距离改为矩形 AABB（新增 `_rect_overlap` + `_building_data`），对齐真实占地。
- 结果：GAWEAP 5x3 预览框由 110x110 变为 200x120（逻辑格）；GAPILL 1x1 为 40x40；不再三个大方框互相叠。
- 新增诊断截图：`_shot.gd` 阶段 2a 产出 `iso_buildpreview_weap.png` / `iso_buildpreview_pill.png`。
- 验证：`SMOKE_SUMMARY ok=297 fail=0`，无 `SCRIPT ERROR`。未打包。
