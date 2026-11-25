# 2026-11-20 烟雾与幻影坦克视觉跳变

用户反馈：烟雾随机乱跳，幻影坦克也会跳变，并提供战斗截图。

## 定位与修正

- `scripts/units/allied_abilities.gd::update_mirage_tree`：旧逻辑在坦克移动或显形时删除 `mirage_tree`；每次停车重新伪装都会再次随机抽树，因此同一辆 MGTK 会在 TREE01..TREE04 间跳变。现改为只在第一次静止伪装时抽取，移动、开火/显形及恢复伪装时保留该辆坦克原树种。
- `scripts/units/unit.gd::_draw_smoke` 与 `_draw_buff_smoke`：循环烟团以前相位回绕时直接重新显示，容易在循环边界看到突然跳点；新增短淡入。
- `scripts/units/ra3_mirage_damage_visual.gd`、`scripts/units/ra3_damage_state.gd`：RA3 受损粒子烟雾新生时做约 3 个模拟粒子的短淡入；RA3 MIRAGE 与苏联 RA3 扩展载具通用。
- 不采纳一项坐标锚点猜测，避免误改等距绘制坐标。

## 回归

- `tests/ra3_mirage_conditions_regression.gd` 补了烟雾淡入，以及 MGTK 移动-停下、显形、显形恢复均保留同一树种的断言。
- Godot 4.7.2 headless editor 脚本扫描通过。
- 隔离回归 `ra3_mirage_conditions_regression` **20 项通过，0 失败**；启动器报告 `source_unchanged=true`，exit 0。
- 曾运行渲染版该条件回归：烟雾粒子生成、受损贴图、显形抑制/恢复等断言均通过；末尾既有“修复后 hull 与健康截图差异不超过 1 色阶”的像素检查失败，最大差异 80。该项不是新加烟雾/树种断言；当前无对照证据将其归因于本修正，不应宣称渲染回归全绿。
- 另一次完整 `allied_abilities_regression` 启动器未留下可读报告，无法据此判定通过/失败。以有可读证据的 20 项隔离条件回归为当前确认结果。

工作区有大量其它用户未提交文件；本任务只改上述脚本与测试对应位置，没有重置或清理其它文件，未提交代码。
