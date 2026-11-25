# RED ALERT 全军军衔修复

日期：2026-11-19

## 用户问题

远征战斗中按下红色警戒按钮后，在场单位没有按原逻辑全升军衔，英雄也没有恢复原有的满军衔逻辑。

## 修复

- `scripts/expedition/red_alert.gd` 的 `apply_units()` 现在对所有存活盟军 Unit 调用 `unit._grant_veteran(3, false)`。
- `_grant_veteran()` 自身按单位类型限制上限：RA2 单位仍到原配置上限（通常精英/2 级），RA3/英雄单位可到英雄/3 级，并执行已有的属性、武器、英雄效果重算。
- 红色警戒激活时立即作用于当前单位；警戒期间新生产或增援的盟军在 `apply_units()` 的周期调用中也会补齐。
- 按钮提示和激活消息已注明“全军立即升满军衔”。

## 校验

- Godot 4.7.2 编辑器扫描通过。
- 真实场景 `--headless --path . --quit-after 300 res://scenes/battle.tscn` 退出码 0。
- 未发现 `SCRIPT ERROR`、`Parse Error` 或 `ERROR:`。

## 注意

`red_alert.gd` 与 `uprising_red_alert_button.gd` 当前在 Git 状态中显示为原有未跟踪文件；本次只修改这两个文件，未覆盖其他工作区改动。
