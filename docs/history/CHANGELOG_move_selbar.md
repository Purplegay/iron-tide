# 本轮变更：修复「攻击中不能移动」+ 红警3 式底部选中单位条

## 1. 缺陷修复：单位攻击时无法移动（真 bug）
**根因**：`scripts/units/unit.gd` 的 `_process_combat()` 中，只要自动索敌到的目标进入射程，
就执行 `has_move_order = false` 并停下开火。默认「自由开火」姿态下战场上到处是敌人，
于是玩家下达移动指令后单位立刻被就地钉住 → 表现为「攻击中不能移动」。

**修复口径**：区分「玩家显式集火」与「自动索敌」。
- 新增 `var attack_ordered: bool`；`battle.force_attack()`（右键集火）会置 `true`。
- `_process_combat()` 重构为 4 段：
  1. 显式集火：追击指定目标，进入射程停下开火；
  2. 攻击移动（Ctrl+移动）：途中遇敌停下交战，保留目的地，清场后继续；
  3. **普通移动：边走边打** —— 自动索敌不再取消/打断移动指令（车身朝行进方向，炮塔独立指向目标）；
  4. 待机：射程内有目标则站定开火，否则原地警戒。
- `_refresh_target()`：显式指定且仍存活的目标保持锁定（允许追击）。
- `order_move / order_stop / order_guard / order_harvest / set_fire_stance("none")` 均会清除 `attack_ordered`。

## 2. 新增：红警3 式底部选中单位条
`scripts/ui/hud.gd` 新增 `_build_selection_strip()` / `_rebuild_selection_strip()` /
`_make_strip_tile()` / `_refresh_strip_live()`。
- 位置：屏幕**最下方居中**（锚点 `PRESET_CENTER_BOTTOM`，±430px，高 86px）；RA3 皮肤面板。
- 内容：标题行「已选部队 N 总血量 X%」（选中建筑时为「建筑 · 名称 HP x/y」）+
  一排单位图标格（沿用 `unit_icon.gd`，每格附带实时血条），最多 24 格，超出以「…+N」提示。
- 交互：单击图标 → 单选并聚焦镜头（新增 `battle.focus_unit()`）；双击 → 选中全部同类。
- 血条随战况实时刷新（`_process` → `_refresh_strip_live()`，仅在变化时 `queue_redraw()`）。

## 3. 其他
- `view_btn` 悬浮提示更新为「7 档预设（默认略平视 2.25:1，K=0.4444）」。

## 校验
- `--headless --editor --quit` 导入：无 Parse / SCRIPT ERROR。
- 冒烟：`SMOKE_SUMMARY ok=109 fail=0`（新增 11 项回归：集火标记、射程内不打断移动、
  移动条存在/可见/多格/隐藏、`focus_unit` API）。
- 实拍：`iso_selbar.png`（选中 20 单位，底部条 20 格，总血量 100%）、
  `iso_ui.png`（7 单位 + 侧栏 + 底部条）、`iso_build.png`（建造进度条）。
