# 变更日志 · 血条深化（受击白闪 + 掉血残影 + 低血整牌泛红 + 敌方描边）

日期：2026-10-09
主题：在既有 RA3 风格血条（凹槽 + 描边 + 分段 + 高光）之上，补齐「打击反馈」表现层。
指导原则：照红警2 / 通用 RTS 的观感抄——血量变化要「看得见」。

## 1. 血条绘制层 `scripts/ui/hp_bar.gd`
`draw_bar()` 扩展为向后兼容的表现层 API：
`draw_bar(ci, rect, frac, fill, segments=0, ghost=-1.0, flash=0.0, alert=0.0, rim=NO_RIM)`

- ④ **掉血残影（ghost）**：在「当前血量 → 旧血量」之间的裸槽画一段半透明白（`GHOST = (1,1,1,0.40)`），
  填充盖住重叠段，形成延迟下落的残影条。
- ⑤ **受击白闪（flash）**：命中瞬间在填充之上叠一层白（`FLASH = (1,1,1,0.92)`，alpha 按 flash 强度衰减）。
- ⑦ **受损警戒脉冲（alert）**：按强度给整条叠一圈脉动的红色细边（`ALERT = (1.0,0.30,0.24)`），
  用于「建筑受损时血条闪烁」，强度 = 1 - 当前血量比例（受损越重越明显）。
- ⑧ **敌方细描边（rim）**：`rim_for(side)` 返回敌方专属的一道细白描边（`RIM_ENEMY`），
  提供「颜色之外」的区分维度（对红绿色觉不友好场景也生效）。

新增：`GHOST / FLASH / ALERT / RIM_ENEMY / NO_RIM` 常量 + `rim_for(side)` 静态方法。

## 2. 面板血条控件 `scripts/ui/hp_bar_control.gd`
- 新增 `_ghost` / `_flash` 状态与 `_process()` 衰减；
- `set_hp()` 检测到掉血时自动触发白闪并保留残影，与世界血条表现同步。

## 3. 单位 `scripts/units/unit.gd`
- 新增 `_hp_ghost` / `_hp_flash`；
- `receive_hit()`：扣血前记录旧血量比例，非死亡时设置残影与白闪；
- `decorate_tick()`：白闪 5/s 退散、残影 1.4/s 追赶当前血量；
- `_physics_process()`：残影/白闪期间持续 `queue_redraw()`；
- `_draw()`：血条叠加 `ghost/flash` 与 `HpBar.rim_for(side)`（敌方描边）。

## 4. 建筑 `scripts/buildings/building.gd`
- 新增 `_hp_ghost` / `_hp_flash`；`receive_hit()` 同上；
- `_process()`：衰减 + 受损时逐帧重绘驱动脉冲闪烁；
- `_draw()`：`alert = 1 - pct`（受损即脉冲），叠加残影/白闪/敌方描边。

## 5. HUD 选中面板 `scripts/ui/hud.gd`
- 新增 `_update_sel_panel_tint(frac)` 与 `LOW_HP_TINT = 0.34`；
- 选中单位/建筑血量低于 34% 时，把选中面板底色**整牌泛红**并脉动（越红越低血），
  恢复后自动还原 RA 面板样式；
- `_refresh_selection_live()` 在单位分支与建筑分支均接入该告警。

## 6. 校验
- `_smoke.gd` 新增 12 条断言：颜色常量、`rim_for`、`HpBarControl` 掉血白闪/残影、
  单位/建筑受击后 `_hp_flash`/`_hp_ghost`、HUD 低血泛红开/关。
  冒烟基线：**ok=231 fail=0**（上轮 219 → +12）。
- `_shot.gd` 新增截图：`iso_hpbar_flash.png`（白闪/残影/敌方描边同框）、
  `iso_selbar_low.png`（低血整牌泛红）。

## 7. 未纳入本轮
- 低血面板的呼吸/心跳音效（留待音效批次）。
- 残影速度、白闪时长等参数目前为常量，未来可并入 Esc 选项面板。


## 8. 补丁：鼠标框选框改为屏幕空间（2026-10-09）
- 问题：等距相机（旋转 45° + Y 压扁）下，`battle.gd::_draw()` 的框选框用
  `Rect2(drag_start, cur - drag_start)`（世界坐标）绘制，屏幕上看是斜菱形。
- 修复：`battle.gd` 新增成员 `drag_start_screen`；按下左键时记录
  `get_viewport().get_mouse_position()`；绘制时用
  `draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())`
  把绘制切到屏幕像素空间，画完复位 `Transform2D.IDENTITY`，得到屏幕正矩形。
- 一致性：`_apply_selection()` 的框选判定改为屏幕空间
  （`u.get_global_transform_with_canvas().origin` 落在 `_drag_screen_rect()` 内），
  与所画矩形一致；新增 `_drag_screen_rect()` 辅助函数。
- 兼容：`_apply_selection(a, b)` 签名不变（a==b 仍走单击选点），不破坏冒烟用例。
- 校验：`_smoke.gd` 新增 3 条断言（`selbox_screen_roundtrip` /
  `selbox_screen_rect_api` / `selbox_screen_rect_ok`），冒烟 **ok=234 fail=0**。
  新增截图 `iso_selbox.png`。


## 9. 补丁：生产队列交互（右键取消单项 / Shift·长按排 5 / 上限 9 / 图标网格）（2026-10-09）
照红警2 侧栏（`SidebarCard`）语义抄：队列以「图标 + 数量角标」网格呈现，右键移除单个。

- 队列上限（`scripts/buildings/building.gd`）：新增 `const MAX_QUEUE = 9`（对齐红警2）；
  `enqueue()` 满员即拒；新增 `enqueue_many(uid, n)`（返回实际入队数，受上限与资金限制）。
- 按项取消：新增 `cancel_at(idx)`——移除指定下标并**全额退款**；取消的是「正在生产」
  的那一个（下标 0）时进度归零。保留旧 `cancel_queue()`（取消末尾）。
- HUD 页脚（`scripts/ui/hud.gd`）：文字列表 → **图标网格**。新增 `_queue_host`（常驻容器）、
  `_queue_shape()` / `_update_queue_host()` / `_build_queue_host()` / `_queue_runs()`（连续同型
  合并成一段、带数量角标，对齐 `SidebarCard`）/ `_make_queue_tile()`（图标 + `×N` 角标）。
  队首标题「队列 n / 9」+ 提示「右键图标取消该单位」+ 既有进度条（生产名 · 百分比）。
- 原地刷新：`_prod_signature()` **不再包含队列内容**——队列变化只走 `_update_queue_host()`
  重建图标条，避免「排一个兵就整体重建、销毁按下中的按钮」导致连续建造丢点击；
  按钮的 disable 状态与进度条数值仍由 `_update_production_live()` 逐帧原地刷新。
- Shift / 长按一次排 5：新增 `HOLD_TIME=0.45` / `HOLD_BATCH=5` 与 `_begin_prod_hold()` /
  `_end_prod_hold()` / `_tick_prod_hold()`；生产按钮 `pressed` 时按 `Input.is_key_pressed(KEY_SHIFT)`
  决定排 1 还是 5；按住超过 `HOLD_TIME` 自动排 5（`_hold_fired` 防止松手时重复入队）。
- 右键取消的输入优先级：`battle._input` 早于 GUI 派发，会抢走右键（平移/指令）。新增
  `_ui_wants_right_click()`——鼠标悬停控件属于 `rmb_cancel` 组时提前 `return`，把右键让给 HUD
  图标；图标格 `mouse_filter=STOP` 消费事件，兼顾 `_unhandled_input` 不发指令。
- 活跃建筑路由：`_active_producer()` 改为「优先选中建筑（若在施工/有队列），否则我方首座忙碌的，
  最后回退」——保证刚排的队列一定显示在页脚，右键取消才用得上。
- 校验：`_smoke.gd` 新增 10 条断言（`queue_cap_constant` / `queue_batch_five` /
  `queue_cap_enforced` / `queue_cancel_at` / `queue_cancel_at_oob` / `queue_cancel_at0_refunds` /
  `queue_strip_built` / `queue_tile_rmb_group` / `queue_runs_grouped` / `battle_rmb_ui_guard_api`），
  冒烟 **ok=244 fail=0**（上轮 234 → +10）。新增截图 `iso_queue.png`。

## 10. 补丁：被动技能介绍（2026-10-09）
- 现象：战斗 HUD 底部技能条里主动技能（Button）悬停有 tooltip，但「被动」项看不到任何说明。
- 根因：被动用 `kit.ra_label(...)` 生成的是 `Label`，Godot 4 中 `Label` 默认 `mouse_filter = MOUSE_FILTER_IGNORE`，不参与命中测试，因此 `tooltip_text` 永不触发。
- 修复（`scripts/ui/hud.gd`）：被动改为可悬停 chip（`HBoxContainer` + 金色名称 Label + 暗色说明 Label），两个 Label 均 `mouse_filter = MOUSE_FILTER_STOP`，tooltip =「被动　名称\n说明」；同时在技能条内直接显示被动说明（如「复合装甲板 · 常驻：受到伤害-11%。」），无需悬停即可看到介绍。
- 校验：`SMOKE_SUMMARY ok=244 fail=0`；`iso_ability.png` 复核通过。

## 11. 补丁：头像势力动效差异化 + 选中描边脉冲（2026-10-09）
- 诉求：头像动效原来全势力统一节奏；改为按势力差异化——盟军「干净」、苏联「笨重」、帝国「花哨」、虫群「有机」；并给 HUD 选中单位头像加高亮描边脉冲。
- 实现（`scripts/ui/unit_icon.gd`）：
  - 新增 `const FACTION_STYLE`：`tempo`（动画节拍，苏 0.72 慢重 / 帝 1.30 快炫 / 盟 1.12 利落）、`edge`、`flash`、`grit`。
  - `_apply_style(fid, role)`：`setup()` 内每次都调用（修正早期「只应用一次」的复用缺陷）；步兵/空军 tempo 再微调。
  - `_t` 累加改为 `_t += delta * _fs_tempo`，全头像动画节拍随势力缩放。
  - 原 `_draw()` 拆为 `_draw_base()`（原逻辑）+ 新 `_draw()` 包装 + `_draw_overlay()`：帝国金边呼吸辉光 + 第二道扫光（花哨）、苏联厚灰钢框缓慢脉动（笨重）、选中时双层白/青描边脉冲（`sin(_t*3.4)`）。
  - 新增 `set_selected(v)`；HUD 在 `_make_strip_tile`（`u != null`）与 `_add_portraits` 处对选中头像调用。
- 校验：`SMOKE_SUMMARY ok=250 fail=0`（+6 条：icon_api / icon_style_table / icon_style_empire_flashier / icon_style_soviet_heavy / icon_style_allied_clean / icon_selected_flag）；截图 `iso_iconframes.png`（苏联坦克行厚钢框）、`iso_ability.png` 复核通过。
- 待办：右上「型号/武器/护甲」信息牌并入右下选择信息卡 → 属「底部指令甲板」整体重构，单独一批做。

## 12. 补丁：技能 buff 栏（倒计时）+ 各色环绕特效（2026-10-09）
- 诉求：技能释放后加 buff，最好有「buff 栏目 + 倒计时」可查看，并给不同 buff 类型配简单环绕特效（攻击红 / 防御绿 / 闪避烟幕 / 命中黄 / 暴击红+蓝 / 速度青蓝 / 冷却青 / 回血绿）；用户随后补充「闪避 buff 可以直接烟雾环绕」。
- 数据/机制（`scripts/units/unit.gd`）：
  - 新增 `const BUFF_KINDS`（9 键，含 `col`/`col2`/`short`/`debuff`）与 `var buffs: Array`。
  - 新增 API：`add_buff(kind,dur,value)`（同键取更长剩余 + 更高数值）、`has_buff` / `buff_value`（求和，用于概率/比率型：闪避/命中/暴击/冷却/回血）、`buff_mult_scalar`（累乘，用于攻/防/速）、`clear_buff`、`buff_entries()`（产出给 HUD 的短文案 `攻击+50%` / `冷却-40%` / `回血3.0%/s`，附长名供 tooltip）。
  - 单一数据源：`_recompute_bonuses()` 改为「只由 buff 驱动」攻/防/速；技能 `<kind>_buff` 在 `_cast_ability` 里落地为 buff（`radius>0` 时经 `_grant_buff` 对范围内友军生效），避免与旧的 `_ability_mult` 重复计入。
  - 结算：`_tick_skills` 每帧先 `_tick_buffs`（倒计时 + `regen` 回血），瘫痪（stun）期间也在 stun 分支推进，保证 buff 计时不被冻结。
  - 战斗接入：命中判定 `1 + 命中 - 目标闪避`（`_target_evade`）；暴击概率增伤 ×1.6；武器冷却 `cooldown × (1 - 冷却缩减)`。
  - 绘制：`_draw()` 顶部新增 `_draw_buffs(r)`——每种 buff 一圈彩色椭圆环（半径按序号错开 `r*(1.50+0.42*idx)`），暴击双环（红+蓝），回血叠上升十字，瘫痪叠旋转警示点；**闪避 = 淡紫环 + `_draw_buff_smoke()` 烟幕**（9 团贴地旋转雾 + 3 缕升腾雾）。
- UI（`scripts/ui/hud.gd`）：技能栏正上方新增「增益/减益栏」`buff_panel`（`z_index=12`、右对齐、宽度按内容自适应 `_fit_buff_panel()`，避免被底部指令甲板遮挡或越界）；每个 buff 一个 chip（色块 + 短文案 + 倒计时 `%.0fs`，tooltip 显示全名）；`_rebuild_buff_bar`（选择变化时重建）/ `_update_buff_live`（每帧刷新倒计时，签名变化才重建，避免每帧建节点）。
- 数据：`data/skills.json` 新增 6 个 base 主动技能（机动规避/瞄准强化/狂暴射击/快速装填/纳米修复场/战鼓光环）；`defaults` 给若干单位补挂新技能（如守护者坦克仍为烟幕弹+引擎超载，步兵/直升机/矿车等换成新 buff）。
- 校验：`_smoke.gd` 新增 14 条断言（`unit_buff_api` / `unit_buff_from_cast` / `unit_buff_attack_recalc` / `unit_buff_mult_scalar` / `unit_buff_entries_text` / `unit_buff_crit_dual_color` / `unit_buff_expire` / `unit_cooldown_buff_value` / `unit_cooldown_buff_shortens` / `hud_buff_panel_present` / `hud_buff_panel_visible` / `hud_buff_chips` / `hud_buff_chip_countdown` / `hud_buff_panel_hides`），冒烟 **ok=264 fail=0**（上轮 250 → +14）。新增截图 `iso_buff.png`。

## 13. RA3/风暴崛起 版面重构 + 建造栏 cameo 图标（本会话）

按用户指定，HUD 版面改为红警3/《风暴崛起》式：
- **右上**：战术小地图（原左下）。
- **右侧竖栏**：建造栏（`prod_panel`，`指令甲板 · <页签>` + 页签行 + 2 列 cameo 网格），标题与页签改为两行避免溢出。
- **左下**：单位卡（特殊指令：移动/攻击/警戒/采集… 3 列）+ 技能栏（4 主动 + 被动）+ 增益栏。
- **底部中间**：已选部队条（`sel_strip`）。
- **左上**：目标/操作日志；**顶右**：资金/击杀/系统按钮。

实现要点：
- `_apply_ra3()` 统一负责所有面板锚点（`W=356`）；`prod_panel` 用 `anchor_left/right=1, anchor_top=0, anchor_bottom=1`（顶右拉伸到底）。
- 建造栏 cameo 由纯文字按钮改为 **图标 + 名称 + 造价 + 热键**：新增 `_make_cameo(d, cost, idx)`（内含 `UnitIconScript` 36px 头像 + 两行文本 + `F1..F8` 标签）与 `_activate_cameo(i)`；`_input` 接住 `F1–F8` 触发对应 cameo。
- `unit_icon.gd` 新增 `role == "structure"` 分支与 `_draw_structure()`（基座 + 主楼 + 窗 + 天线），建筑 cameo 不再借用车单位图形。
- 冒烟基线：`SMOKE_SUMMARY ok=267 fail=0`（新增/更新断言 `ra3_deck_panel_right`、`ra3_deck_below_sel`、`strip_bottom`、`ability_bottom_left`）。

> 注：本会话发现 `edit_file` 工具在 `hud.gd` 上偶发“报成功但未落盘”，后续 .gd 改写统一改用 Node/PowerShell 字面替换 + 计数校验。
---

## 14. 技能施放「范围显示」（本会话）

用户诉求：「放技能要有个范围显示」。

**红警3 式瞄准流程（`scripts/world/battle.gd`）**
- 新增状态：`cast_slot`（已武装技能槽，-1=未武装）、`hover_ability`（HUD 技能按钮悬停槽）、`_cast_flashes`（施放扩散圈）。
- 新增 API：`request_ability(slot)`（>0 即时施放 / -1 进入瞄准态 / 0 不可用）、`confirm_cast()`、`cancel_cast()`、`preview_ability(slot)` / `clear_ability_preview()`、`_ability_color(target)`、`_ability_radius(ab)`、`_range_preview_ability()`、`_ability_affected()`、`_draw_ability_range()`、`_add_cast_flash()`。
- **有作用范围（`radius > 0`）的技能**：点击 / 热键后进入**瞄准态** —— 在施法者周围绘制等距地面圆（`Iso.ell`）+ 内圈 + **落在半径内的单位高亮环**；左键确认施放，右键 / `Esc` 取消，再点同一槽 = 取消；光标切换为十字。
- **无范围的自身增益**：保持即时施放（不打断节奏）；施放瞬间在施法者处播放**范围扩散圈**（`_cast_flashes`，0.6s 外扩 + 淡出）；有范围技能在确认施放时同样播放。
- 颜色按 `target` 区分：`allies` 绿、`enemies` 红、其它青。
- 提示文字与鼠标准心改用**屏幕空间**绘制（`draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse())`，画完复位 `Transform2D.IDENTITY`），避免被等距相机旋转 / 压扁。
- 与既有交互互斥：进入指令模式（`arm_command`）、建造模式（`set_build_mode`）、清空选择（`_emit_selection`）都会退出瞄准态；`_process` 在瞄准 / 悬停 / 有扩散圈时持续 `queue_redraw()`。

**HUD（`scripts/ui/hud.gd`）**
- 技能按钮 `_cast_ability(slot)` 改走 `battle.request_ability(slot)`（有范围 → 瞄准态；无范围 → 即时）；不可用时提示「技能不可用或仍在冷却」。
- 技能按钮新增 `mouse_entered` / `mouse_exited` → `battle.preview_ability(slot)` / `clear_ability_preview()`：**悬停即预览范围**。
- `armed_escape()` 优先取消瞄准态（`battle.cancel_cast()`）。
- 修正技能热键标签：`["Q","W","R","D"]` → `["Q","W","E","R"]`，与 `Shift+Q/W/E/R → 槽 0/1/2/3` 的真实绑定一致。

**校验**
- `_recover\check4\smoke\_smoke.gd` 新增断言：`battle_cast_api`、`battle_ability_preview_on` / `_off`、`battle_ability_arm_range`、`battle_ability_cancel`、`battle_ability_instant_cast`。
- `_recover\check4\smoke\_shot.gd` 新增 6a) 段：给坦克临时装配 `radius=120` 的「纳米修复场」，进入瞄准态并截图 `iso_ability_range.png`（`DIAG ability_range arm=-1 cast_slot=0 affected=5`）。
- 冒烟基线：**`SMOKE_SUMMARY ok=267 → ok=273 fail=0`**（+6 断言）。
- 存档「备份 → sync+smoke+shot → 还原」：`restored=True meta=True`。未打包。

---

## 15. 点选生产建筑 → 甲板自动跳到可造列表（本会话）

**问题**：点击（框选）有生产功能的建筑后，HUD 底部「指令甲板」仍停留在上次的页签（默认「建筑」），没有呈现该建筑能造的东西——红警2/3 的直觉是「选中建筑即弹出它的可造列表」。

**改动**
- `scripts/ui/hud.gd`
  - 新增 `_tab_for_building(b) -> String`：按建筑 `buildable` 里各单位的分类推断目标页签——只有步兵/反装甲 → `"infantry"`；含载具/防空/飞行/经济 → `"vehicle"`；无 → `""`。
  - 新增 `_auto_focus_building_tab(b)`：仅当 `b.side == "ally"`、未在施工、且 `buildable` 非空时，把甲板切到 `_tab_for_building(b)`（与当前页相同则不动作，避免打断用户随后的手动切页）。
  - `_refresh_selection()` 开头接入：选中建筑时自动跳页。选择变化 → `Events.selection_changed` → `_refresh_selection` 自动生效；`_process` 的签名轮询只在选择真正变化时触发一次，故手动切页后不会被反复抢回。
  - 建筑信息面板提示文案改为「已在下方『指令甲板 · <页签>』列出该建筑可造项目，点单位即可造兵」。
- 行为边界：点防御塔等无可造建筑的建筑不切页；施工中的建筑不切页；进入指令/建造模式的互斥逻辑不受影响。

**校验**
- `_recover\check4\smoke\_smoke.gd` 新增 5 条断言：`deck_tab_for_barracks_infantry`、`deck_auto_focus_infantry`、`deck_auto_focus_vehicle`、`deck_no_autofocus_empty`、`deck_no_autofocus_constructing`。冒烟基线：**`ok=273 → ok=278 fail=0`**（+5）。
- `_recover\check4\smoke\_shot.gd` 新增 6c3) 段：先把甲板复位到「建筑」页，再选中生产建筑，验证自动跳页并截图 `iso_deck_autofocus.png`（`DIAG deck_autofocus tab=vehicle buildable=1`）。
- 存档「备份 → sync+smoke+shot → 还原」。未打包。

**已知待办（等用户拍板）**：当前甲板是「全阵营同页汇总」——点指挥中心跳到「载具」页会列出全部载具，而不只是它自己能造的采集车。如需「只显示选中建筑可造项目」（更贴近 RA2 侧栏），可再加一层按 `selected_building.buildable` 过滤。

---

## 16. 已选单位面板视觉重构（本会话）

**问题**：用户贴出左下「已选中 N 个单位」面板截图，反馈「有点丑」。原面板是纯文本堆：`型号：X` / 霓虹绿 3D 血条 / `姿态：X` / `护甲 中甲 射程 285 速度 105` / `武器：X（Y）` / `克制 …` / `攻击加成 ×1.00 减伤 ×1.12`，行与行无对齐；面板是浅灰粗描边 + 默认浅色滚动条；指令按钮偏厚重。

**改动**（均在 `iron_tide\scripts\ui\hud.gd`、`hp_bar.gd`）

- `_add_unit_info(first)` 重写为「单位卡」结构：
  - 标题行：左侧 3px 强调条（`COL_ACCENT_2`）+ 型号名（15px `COL_TEXT`）+ 弹性间隔 + 右侧角色标签（`_unit_role_tag`，取 `units.json` 的 `role_name`，如「主战」「后勤」）。
  - 生命条行：血条 + 右对齐数值 `cur / max`（`sel_hp_label.horizontal_alignment = RIGHT`）。
  - 关键数据：`GridContainer(columns=4)` 一排小卡片——姿态 / 护甲 / 射程 / 速度（采集车额外一枚「货舱」），卡片上说明（10px 暗色）/ 下数值（13px 亮色）。
  - 武器：`武器 · <名>` + `穿甲弹 · 克制 重甲(×1.30) · 弱于 空中(×0.20)` 两行分主次。
  - 加成：两枚胶囊 `攻击加成 ×1.00` / `减伤 ×1.12`（数值用 `COL_OK` 绿）。
- 新增辅助：`_unit_role_tag(u)`、`_stat_card(parent,cap,val)->Label`、`_bonus_chip(...)`、`_chip_style()`（深色 `RA_TILE` + 1px `RA_EDGE` + 4px 圆角 + 内边距）。
- `_refresh_selection_live()`：姿态 / 货舱的实时刷新文案由 `"姿态：%s"` / `"货舱 %d / %d"` 改为只写值（卡片已有说明文字），避免出现「姿态」标题 + 「姿态：待命」重复。
- 面板描边：`kit.make_panel(Color(0.07,0.08,0.11,1.0), Color(0.30,0.34,0.42,1.0))` → `kit.make_panel(kit.RA_PANEL, kit.RA_EDGE)`，与技能栏 / 增益栏统一深色描边。
- 滚动条：`_build_selection()` 里给 `sc.get_v_scroll_bar()` 换成 6px 细杆（半透明轨道 `Color(1,1,1,0.05)` + 青灰滑块），去掉默认浅色滚动条。
- 指令按钮：`kit.ra_button(13,30)` → `(12,28)`、`custom_minimum_size` `(100,30)` → `(98,28)`，收敛厚重感。
- `hp_bar.gd`：血条顶部高光 `lightened(0.30)→(0.16)`、底部阴影 `darkened(0.28)→(0.16)`，全 UI / 战场血条同步变平，削弱「糖果渐变」感。

**校验**
- `--check-only --script res://scripts/ui/hud.gd` 干净（仅 `Identifier not found: Events` 等 autoload 缺失，属正常）。
- 冒烟：**`ok=278 fail=0`**（与基线一致，未新增/未破坏断言；`hud_selection_built` / `hud_panel_header_text`（"已选中"）/ `hud_panel_clears_on_deselect`（"未选中"）均通过——新卡片的标题仍是 `sel_box` 的直属 `Label`）。
- 出图：`_recover\check4\iron_tide\iso_ui.png` / `iso_selbox.png` 正常，`DIAG panel_text` 已含「武器 · 120mm 滑膛炮」等新文案。
- 存档「备份 → sync+smoke+shot → 还原」。未打包。

**待办**：技能栏按钮 / 指令按钮仍未深改（文字顶对齐、`ra_button` 的亮青顶边较抢眼）；如需继续统一可下一轮处理。

---

## 17. RA2 数据管线（Step A：rules/art/csf → JSON）

**背景**：用户拍板 RA2 移植方案——① 按 **A→B→C→D** 顺序推进；② 先做**盟军**；③ 美术口径**直接烧 RA2 原图（SHP/VXL）**；④ 先接受**原版 RA2（无尤里）**（后续再找 yuri）；⑤ ts-ra2（GPL-3.0）作为**算法/规则参考一并移植**。故第一步 = **A 数据管线**（零风险、纯离线、当场出成果、是地基）。

**产物**：`iron_tide\data\ra2\` 下脚本生成的 JSON（详见该目录 `README.md`）——
`meta.json` / `localization.json` / `units.json` / `buildings.json` / `weapons.json` / `warheads.json` / `factions.json` / `tech_tree.json`，合计约 1.13 MB。

**计数**：步兵 45、载具 55、飞机 8、建筑 295、武器 176、弹头 82、科技树实体 403、本地化标签 4473、国家 13。声明但无 rules section 的 id 记入 `meta.unresolved`（飞机 `APACHE`；建筑 `NAWAST,GARADR,NAHPAD,CAEURO01,CAIRSFGL`）。

**管线脚本**（沙箱根 `ra2pipe\`，不进工程）：
- `lib/ini.mjs`：Westwood INI 解析（段/key=value/`;` 注释）。
- `lib/csf.mjs`：CSF 字符串表解析。**关键坑**：CSF 的字符串值是 **XOR 0xFF 后再按 UTF-16LE 解码**（不是裸 UTF-16），否则读出乱码；`STRW` 变体额外 4 字节。
- `build.mjs`：合并 rules+art+csf → JSON；`art.ini` 段以 `Image=` 命名（无则回退 id）；`Owner` → `allied`/`soviet`。
- `validate.mjs`：50 条地面真值断言，输出 `RA2_SUMMARY ok=50 fail=0`。

**校验**：
- `RA2_SUMMARY ok=50 fail=0`（断言：`Name:E1=美国大兵`、E1 hp125/armor none/primary M60/cameo GIICON、MTNK hp300/heavy/105mm/voxel、M60 dmg15 rof20 range4 warhead SA、105mm dmg65/AP、`SA.verses` 11 槽且 heavy=×0.25、GAPILE hp500/factory InfantryType、GAREFN foundation 4x3、阵营名册非空 …）。
- Godot 侧：仅新增数据文件、未动 `.gd`；`sync → smoke` 复核 **`ok=278 fail=0`（基线未变）**；存档「备份 → 跑 → 还原」。未打包。

**CSF 事实**：`general.csf` 头部声明语言 0(EnglishUS) 但内容是**简中**（`THEME:INTRO=开场`、`Name:MTNK=灰熊坦克`）。

**下一步**：B（美术管线：移植 ts-ra2 `Blowfish.ts`+`BlowfishKey.ts` 到 Node，解 `RA2.MIX` → SHP/VXL+PAL → PNG，先用 `meta`/`art` 里的 `Cameo`/`Image` 定位文件）。
---

## 18. RA2 美术管线（Step B）

**目标**：把原版红警2 的 `RA2.MIX / LANGUAGE.MIX`（Blowfish 加密）解开，取出 SHP/VXL + PAL 并转成 PNG，
为后续 Step C（阵营+科技树）/ Step D（RA2 风 UI）备料。

### 18.1 结果

- 新增 `iron_tide/assets/ra2/`：**cameo 91 张**（60×48，含简中文字）+ **SHP 精灵表 324 张** + **VXL 车辆 8 朝向表 59 张**，合计 434 文件 / 约 12 MB。
- 载具体素 **0 缺失**；SHP 仅约 20 个民用/装饰 id 未解析（记入 `ra2_art_index.json`）。
- 冒烟基线未变：**`SMOKE_SUMMARY ok=278 fail=0`**（本次只新增数据文件，未改任何 `.gd`）。

### 18.2 关键坑（实测，务必保留）

1. **MIX 加密**：`RA2.MIX` / `LANGUAGE.MIX` flags = `0x00030000`（Blowfish）；子 MIX（`CONQUER.MIX` 等）为明文。解头需先解 Blowfish 再读 `u16 count / u32 bodySize`。
2. **建筑 SHP 的调色板是 `UNITTEM.PAL`**，不是 `TEMPERAT.PAL` / `SNOW.PAL`（后两者字节完全相同，会把建筑画成噪点）。步兵/建筑/载具统一用 `UNITTEM.PAL`，cameo 用 `CAMEO.PAL`。
3. **子 MIX 命名反直觉**：建筑 SHP 实际在名为 **`SNOW.MIX`** 的子 MIX（18 MB）里；`TEMPERAT.MIX`/`URBAN.MIX` 内没有这些键。
4. **cameo 在 `LANGUAGE.MIX > CAMEO.MIX`**（203 项，本地化版本），不在 `RA2.MIX`。
5. **文件名哈希 = CRC32 大写文件名**，大小写不敏感；无法反查，只能正向枚举候选名匹配。
6. **SHP 解码**：`reserved==0` 走 8 字节主头，否则为 TS 风格；压缩类型 3（Format3）是主流，1:1 复刻 ts-ra2 的逐行 RLE。
7. **VXL 文件布局**：`[16 文件名][u32×4][remapStart,remapEnd][768 palette][section headers 28B×n]` → `bodyStart` → **body** → **section tailers 92B×n 在文件末尾**（不变量：`bodyStart + bodySize + 92*n == fileLen`）。tailer 里 `startingSpanOffset` 相对 `bodyStart`。
8. **VXL 体素渲染**：不要把「模型绕 Z 旋转」和「固定 45° 投影公式」叠加（会在 45° 处退化成正交轴）。正确做法是让**视角方位角**随朝向变化：`az = π/4 − facing·2π/facings`，屏幕右轴 `r=(−sin az, cos az, 0)`、上轴 `u=(−cos az·se, −sin az·se, ce)`（仰角 30° → `se=0.5, ce=√3/2`），深度轴取 `r×u` 做 z-buffer。
9. **法线表**：直接从 `refs/ts-ra2/src/data/vxl/normals.ts` 运行时解析；RA2 用 `normals4`（245 项，`normalIndex` 最大 244）。
10. **HVA 解析要设上界**（`sectionCount` 越界会导致 40 亿次循环 → OOM）；静态出图可不套 HVA（用 0 帧）。

### 18.3 复现

```
& "C:\Users\admin\AppData\Local\Author Software\nvm\.nodejs\node.exe" ra2pipe\art_build.mjs all
& "C:\Users\admin\AppData\Local\Author Software\nvm\.nodejs\node.exe" ra2pipe\art_preview.mjs
```

产物说明见 `iron_tide/assets/ra2/README.md`。

## 19. Step C 阶段1：RA2 盟军阵营 + 科技树（数据层 + 建造栏 cameo）

**目标**：用 Step A 的 RA2 数据搭建盟军阵营 + 科技树，并把 Step B 的 cameo 接进建造栏（"照抄红警2"）。

**新增（离线管线 ra2pipe/）**
- `faction.mjs`：读取 data/ra2/{units,buildings,weapons}.json + assets/ra2/* 美术索引，翻译成引擎 schema，产出 `data/ra2_allied.json`（additive，不动 data/units.json）。
  - 阵容白名单：19 单位（E1/ENGINEER/JUMPJET/SNIPE/SPY/TANY/GHOST/CLEG/DOG/MTNK/FV/MGTK/SREF/TNKD/AMCV/SHAD/CMIN/ORCA/BEAG）
    + 15 建筑（GAPOWR/GAREFN/GAOREP/GAPILE/GAWEAP/GAAIRC/GADEPT/GATECH/GAPILL/ATESLA/GTGCAN/GAGAP/GASAND/GAWALL/GASPYSAT）。
  - 映射：cost 直取；hp 单位直取 / 建筑 ×3；speed 按兵种 ×26/15/24；sight ×60/40/50；range=格×55；cooldown=rof/15；弹头→attack_type；护甲映射；武器少量覆写（SREF/TNKD/ORCA/BEAG）。
  - 科技树：写入 `ra2_prereq`（RA2 原始前置）+ `tech_level`；`builds` 按 built_at 回填。

**工程改动（.gd，Node 字面替换，保 BOM/LF + 计数校验）**
- `scripts/autoload/game_data.gd`：新增 `_load_ra2_allied()`（增量合并 units/buildings 索引，不覆盖 data/units.json）；
  API：`ra2_loaded / ra2_ids / ra2_art_of / ra2_cameo_path / ra2_sprite_path / is_ra2 / ra2_prereq_ok / ra2_hide_engine`。
- `scripts/ui/hud.gd`：
  - `_make_cameo`：有 RA2 cameo 则用原图 TextureRect（TEXTURE_FILTER_NEAREST），否则回退 UnitIcon。
  - `_building_catalog` / `_unit_catalog`：科技树门控（`_ra2_gate` / `ra2_prereq_ok`）+ 阵容去重（隐藏引擎 allied_barracks/factory/airbase；过滤引擎盟军单位）。
- 前置令牌兼容两套命名：BARRACKS/TECH/POWER/PROC/RADAR/GACNST → tag 或具体 id（GAPILE/GAPOWR/GAAIRC/GATECH/GAREFN/allied_hq…）。

**校验**
- 冒烟 278 → **ok=287 fail=0**（新增 9 条 Step C 断言：ra2_loaded/ids/cameo/gaweap_builds_mtnk/prereq 门控×3/harvester art/building_cameo）。
- 无新增 SCRIPT ERROR（仅既有 `full_damage ... Nil` 噪音）。
- 截图：建造栏「建筑」页只剩 RA2 **发电厂 800**（冷却塔原图 cameo）；建出电厂后解锁兵营/矿厂等。
- 未打包。

**未做（下轮）**
- 单位/建筑用 SHP/VXL 替换程序化绘制（Step C 的"单位渲染"部分）。
- 引擎自带盟军防御（光谱塔/防空塔）是否一并替换 / 引擎盟友军阵容是否整体隐去。

## 20. Step C 阶段2 前置：建造栏改为「RA3 风格置灰」而非 RA2「隐藏」

**用户拍板**：Step C 阶段2 的口径选 **(B)**（盟军完全 = RA2 阵容，连引擎自带盟军防御也归 RA2），
但可建造列表**不要学 RA2 的"隐藏所不能造"**，改用 **RA3 风格：不能造的仍列在网格里，只是置灰 + 禁用**。

**改动（.gd，Node 字面替换，保 BOM/LF + 计数校验）**
- `scripts/autoload/game_data.gd`：把 `ra2_prereq_ok` 拆出单一真源 `ra2_missing_prereqs(id, owned)`（返回未满足的前置令牌数组）；
  令牌表提为 `const RA2_TOKEN_TAGS / RA2_TOKEN_IDS`。`ra2_prereq_ok` 改为 `ra2_missing_prereqs(...).is_empty()`。
- `scripts/ui/hud.gd`：
  - `_building_catalog()` / `_unit_catalog()` **不再做可用性过滤**；改为列出全阵营条目（RA2 在前、引擎自带在后）。
  - 新增 `_build_state(bid)` / `_unit_state(uid)` → `{ ok, reason }`：RA2 条目按 `ra2_prereq_ok` / 是否有已建成的生产建筑判定；
    引擎自带盟军建筑/单位在 `ra2_loaded` 时一律 `ok=false`，reason = "已被 RA2 阵容取代"。
  - `_make_cameo(..., avail)`：`avail=false` → `btn.disabled=true` 且整块 `row.modulate = Color(0.62,0.62,0.66,0.72)`（图标+文字一起压暗）。
  - 新增 `_prod_locked`（uid→原因）：每帧的 `_update_production_live` 对锁定项强制 disabled，不受资金影响。
  - tooltip 追加 `[不可建造] <原因>`；`_prod_signature` 纳入可用性位（`id + "+"/"-"`），使"建成前置后解锁"能触发重建。
  - 新增 `_prereq_names` / `_entity_name`：把前置令牌翻成中文（兵营/发电厂/作战实验室…），未知令牌回落到实体名。

**效果**
- 「建筑」页：RA2 发电厂/矿厂/兵营/战车工厂… 亮色可造；引擎 `兵营550 / 战争工厂1400 / 空军基地1800` 保留但置灰。
- 「防御」页（选项 B）：引擎 `光谱塔 / 防空塔` 保留但置灰。
- 「步兵/载具」页：引擎盟军单位（MRV 采集车300 / 复仇者防空车480 / 守护者坦克700 / 雅典娜火箭车950 / 猛禽战机900 …）保留但整块压暗。
- 未满足科技树前置的 RA2 建筑同样置灰，tooltip 显示所缺前置。

**校验**
- 冒烟 287 → **ok=296 fail=0**（新增 9 条断言：引擎建筑/单位保留且锁定、GAPOWR 可造、GAPILE/GATECH/光谱塔锁定且带原因）。
- 无新增 SCRIPT ERROR（仅既有 `full_damage ... Nil` 噪音）。
- 截图确认置灰效果（载具/建筑页）。
- 未打包。

**未做（Step C 阶段2 主体，仍待做）**
- 单位/建筑用 SHP/VXL 替换程序化绘制（矿车/坦克出 RA2 素材）。

---

## §21 Step C 阶段2 主体（第一批）：单位/建筑改用 RA2 原图（SHP/VXL）替换程序化绘制

**目标**：把程序化矢量建模换成红警 2 原图 —— 载具走 VXL（8 朝向横排），步兵走 SHP（站立 8 朝向帧），建筑走 SHP（帧 0）。

**新增文件**
- `iron_tide/scripts/core/ra2_art.gd`（`class_name RA2Art`，无 BOM / LF / Tab）：
  - `art(id)` 静态缓存装载：`res://assets/ra2/vxl/<id>.png`+`.json`（frameW/frameH/facings）或 `shp/<id>.png`+`.json`（rects 帧表）；
  - `src_rect(m, frame)`：VXL 帧 i 源矩形 = `(pad + i*(frameW+pad), pad, frameW, frameH)`（pad=2）；SHP 取 `rects[i]`；
  - `anchor(m, frames)`：**内容包围盒锚点**（横向内容中心 x、纵向内容底边 y）。画布四周留白很大（实测 E1 内容仅在 78×66 画布的上半部），用画布底边做锚点会让步兵整体偏高 31px。旋转类传全部朝向帧取并集，保证转向时不抖动；
  - `facing_index(world_angle, facings)`：**按屏幕方向向量最近邻取帧**。关键教训：不能把屏幕方位均分 45° 取整 —— 2:1 等距会把方位非线性压扁（RA2 素材 facing 0/2/4/6 的屏幕角只有 ±26.57° / ±153.4°，并不在 45° 网格上）。做法：单位前向 `s = Iso.dir((cosθ,sinθ))`，与每个素材朝向应有的屏幕方向 `u_f = (sin az_f, -0.5*cos az_f)`（`az_f = 45° - f*360°/facings`，由素材管线相机方位推导，与 RA2「facing0 = 正北 = 屏幕右上」一致）做 dot 最邻近。

**工程改动**
- `iron_tide/scripts/units/unit.gd`（有 BOM，5 处字面替换）：
  - 新增成员 `var _ra2: Dictionary = {}`；`setup()` 末尾 `_ra2 = RA2Art.art(unit_id)`；
  - `_ready()` 设 `texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST`（像素化采样）；
  - `_draw()` 分支：`if not _ra2.is_empty(): _draw_ra2_sprite(r) elif is_air: ...`（其余 buff / 血条 / 选中环 / 烟雾 / 载货条 全部保留）；
  - 新增 `_draw_ra2_sprite(r)`：按 kind 取帧（VXL 用 facings、SHP 用站立 8 帧），`draw_texture_rect_region`，底边中点对齐脚下（`dst = (-a.x, r*0.35 - a.y)`）；空中单位抬升 `r*1.6`。
- `iron_tide/scripts/buildings/building.gd`（有 BOM）：
  - 同样新增 `_ra2` + 装载 + nearest 采样；
  - `_draw()` 里把**程序化身体块**整体包进 `if not _ra2.is_empty(): _draw_ra2_sprite(r) else: <原块>`（用脚本按标记自动缩进，未手改 50 行）；新增 `_draw_ra2_sprite(r)`（帧 0）。

**关键设计结论**
- 素材按 **1:1 像素**接入：本工程 2:1 等距与 RA2 逐像素一致（地块 60×30），故 RA2 原图无需缩放；
- RA2 素材的「阵营涂装色」当前为红色（对应 RA2 红色房屋色 / UNITTEM 红阶），盟军规范应为蓝色 —— **待管线做 house-color remap**（见下）。

**校验**
- 冒烟 **ok=296 fail=0**，无新增 SCRIPT ERROR。
- 新增截图脚本（在 `_recover/check4/smoke/`，不进工程）：`_ra2shot.gd`（载具/步兵/朝向 A/B/建筑 四图）、`_ra2face3.gd`（解向箭头）、`_ra2diag.gd`（打印取帧）、`_ra2move.gd`。
- 朝向用「RA2 坦克 vs 程序化坦克同角度 A/B」核对：θ=0 两者同指右上，与 `Iso.dir` 理论值 −26.57° 一致。
- 未打包。

**未做（Step C 阶段2 后续）**
- 步兵/载具的**行进 / 开火 / 死亡动画帧**（现只用站立朝向帧与静态朝向）；
- 建筑多帧动画（建造中 / 破损 / 生产）；
- 阵营涂装 remap（红→蓝）、炮塔独立旋转（RA2 载具 VXL 含炮塔，本批用整体）；
- 矿车/建筑与既有 gameplay（寻路 footPrint、血条位置）微调。

## §22 Step C 阶段2 主体（第二批）：建筑体积（碰撞半径）标定 + RA3 式渐进建造 + 技能缩减为 2 主动 + 形态切换（美国大兵卧倒）

- **建筑「体积」（碰撞半径）按 RA2 原图重新标定**：`radius = clamp(内容最大宽/2*0.55, 14, 56)`，写入 `data/ra2_allied.json`（GAPOWR 22→25、GAREFN 34→39、GAOREP 30→35、GAPILE 26→36、GAWEAP 38→55、GAAIRC 26→20、GATECH 26→52、GADEPT 30→14、GATESLA 14→18、GAGAP 14→19、GAWALL 14→17、GASPYSAT 22→32 …）。放置间距（`build_spot_ok` 用 `(r+br)*1.12`）与物理碰撞体随之更正，建筑不再互相压叠、单位不再贴图穿模。
- **建造改为 RA3 式「一边建造一边扣钱」**：
  - 结构：`battle._try_place_building` 去掉一次性 `spend_funds`；`building._process` 建造期按 `build_cost/build_total*delta` 逐帧扣款；资金不足则暂停（不推进 `build_elapsed`），只提示一次「建造暂停」。
  - 单位：`building.enqueue` 不再预付；生产期逐帧扣款；取消（`cancel_queue`/`cancel_at`）只退还「已付进度」`= cost*clamp(progress/bt,0,1)`。
  - 新增 `battle.try_spend(amount)`：静默扣款（避免「资金不足」逐帧刷屏），驱动 HUD 资金刷新；维修消耗也改用它。
  - `build_spot_ok` 资金门槛由「≥全额」放宽为「>0（可开始支付）」。
- **技能缩减为「2 主动 + 1 被动」**：`meta.json.unit_upgrades.slots.active` 4→2；`skills.json.slots.active` 4→2；HUD 技能栏快捷键 `["Q","W","E","R"]`→`["Q","W"]`；`unit._init_skills` 注释同步。
- **新增主动技能「部署/卧倒」**（`ap_deploy`, `effect=deploy`）：切换形态（RA2 美国大兵式）。部署态：`move_speed×0`（无法移动，`_steer_dir` 归零、`order_move` 被拒并提示需先起身）、攻击 ×1.5、防御 ×1.15；再点一次起身。RA2 E1 卧倒姿态帧 = `292..299`（SHP `Deployed=292,1,1`，8 朝向），`unit._draw_ra2_sprite` 在部署态改用该帧组并按其包围盒定位锚点。E1 / allied_infantry 增加 `deploy_frame=292, deploy_attack_mult=1.5, deploy_defense_mult=1.15`；`skills.json` 默认装配 E1 / allied_infantry = `["ap_deploy","ap_bayonet"]`。
- **冒烟**：`SMOKE_SUMMARY ok=303 fail=0`（基线 296；改名 2 项 +`新增 7 项`：`deploy_skill_present`、`infantry_deploy_frame`、`building_radius_power`、`building_radius_warfactory`、`infantry_deploy_toggle`、`infantry_deploy_immobile`、`infantry_undeploy_toggle`），`SCRIPT ERROR=0`。
- **脚本**：`ra2pipe` 下 `p1_data.mjs` / `p3_data.mjs` / `p4_building.mjs` / `p5_battle.mjs` / `p6_unit.mjs` / `p7_deploy.mjs` / `p8_hud.mjs` / `p9_smoke.mjs`~\`p12_smoke4.mjs` / `p13_shot.mjs`；预览 `smoke/_ra2shot.gd` 增加「步兵形态切换 A/B」截图 `ra2shot_deploy.png`。
