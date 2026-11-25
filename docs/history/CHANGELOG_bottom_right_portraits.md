# 变更记录：红警3 式右下角「单位显示 + 技能栏」+ 动态单位头像

会话语言：简体中文。工程：Iron Tide RTS（Godot 4.7.2）。

## 用户诉求
> 红警3 的单位显示是在右下角的，技能我们也放在那边，不过我希望我的单位图片是动态的。

## 改动 1：单位显示 + 技能栏移到右下角
- `scripts/ui/hud.gd::_build_selection_strip()`
  - `sel_strip` 锚点由 `PRESET_CENTER_BOTTOM` 改为 `PRESET_BOTTOM_RIGHT`，右对齐：
    `offset_left=-640 / offset_right=-8 / offset_top=-94 / offset_bottom=-8`。
  - 即「已选部队 N · 总血量 X%」这排单位头像落在屏幕**右下角**。
- `scripts/ui/hud.gd::_build_ability_bar()`
  - `ability_panel` 锚点由 `PRESET_CENTER_BOTTOM` 改为 `PRESET_BOTTOM_RIGHT`，堆叠在单位条**正上方**：
    `offset_left=-640 / offset_right=-8 / offset_top=-150 / offset_bottom=-98`。
  - 即技能（Q/W/R/D 等）与单位显示同处右下载荷区。
- 底部中央因此空出，视野更干净；战术地图仍在左下角，右上信息栏/生产栏未动。

## 改动 2：单位头像改为「动态」
- `scripts/ui/unit_icon.gd`
  - 新增动画时钟 `_t`、`anim_tick(delta)` 与 `_process(delta)`：约 30fps 节流（`ANIM_STEP=0.033`），
    且 `is_visible_in_tree()` 为假时跳过，多个头像同屏也不吃性能；`animate` 可整体关闭。
  - 整图**呼吸起伏**（`sin(_t*2.2)`）+ **掠光斜带**扫过（金属高光感）。
  - 分兵种动态：
    - 车辆：履带刻线滚动 + 炮塔/炮管轻微摆动。
    - 步兵：持枪手臂摆动。
    - 机甲：双腿交替迈步 + 光学眼脉冲。
    - 虫族/群袭：多足摆动 + 复眼脉冲。
    - 飞机：旋翼旋转。
    - 采集车：采集滚筒旋转。
  - 完整保留：兵种剪影判定、右上「有武器」角标、右下同类数量角标、底部红警3 风格血条（`HpBar.draw_bar`）。

## 校验
- 导入：无 `Parse Error / SCRIPT ERROR / Failed to load`。
- 冒烟：`SMOKE_SUMMARY ok=207 fail=0`（上一轮 202，本轮 +5）：
  `strip_bottom_right`、`ability_bottom_right`、
  `icon_dynamic_time_advances`、`icon_dynamic_step_defined`、`icon_dynamic_respects_pause`。
- 实拍：
  - `iso_ui.png` / `iso_selbar.png`：单位条 + 技能栏落位右下角（右上信息栏/左下地图无回归）。
  - `iso_iconframes.png`：动态头像相位扫描（同一图标在不同 `_t` 下并排），可见履带滚动、
    旋翼旋转、手臂摆动、滚筒转动逐帧变化。

## 涉及文件
- `iron_tide/scripts/ui/hud.gd`
- `iron_tide/scripts/ui/unit_icon.gd`
- 校验脚手架：`_recover/check4/smoke/_smoke.gd`、`_recover/check4/smoke/_shot.gd`（不进工程）

## 备注 / 后续可选项
- 若还要把「型号/武器」信息牌也一起并入右下角（RA3 底栏右端的选择信息卡），需先腾挪右上
  信息栏，属下一批「底部指令甲板」重构范畴，待拍板。
- 头像动效参数集中在 `unit_icon.gd` 各 `_draw_*` 中，可按势力/兵种继续差异化。
