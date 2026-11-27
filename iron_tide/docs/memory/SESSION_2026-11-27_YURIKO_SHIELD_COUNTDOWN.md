# 百合子灵能护盾独立倒计时

用户指定百合子的盾按剩余秒数单独显示，不能画成蓝色盾量。`shield_readout.gd` 只读在场百合子的实际 `special.psi_shield`，不纳入盾耐久或通用“防护中”。`unit.gd` 让满血未选中的百合子也可绘制；`hp_bar.gd` 在战场血条上方用紫色显示「灵能护盾 N 秒」，`hud.gd` 在选中面板复用文案和颜色。大于 0 的时间向上取整，结束立即隐藏。若还有其他来源的有限护盾，蓝条和蓝色面板读数保留。未改变技能、护罩、受击处理、持续时间或存档格式。

隔离无头 Godot 4.7.2：`res://tests/shield_catalog_regression.tscn` 217/217，exit 0、stderr 空。证据 `.validation/yuriko-shield-countdown-20261127/`。新增六项使用真实 Battle/HUD，夹具注入计时后通过真实受击和 `Yuriko.tick` 核对不扣时、下跳、到期、有限盾并存；未通过玩家技能按钮施放，未验有头实际画面、缩放、独立进程冷读或打包。上一批统一耐久显示见 `SESSION_2026-11-27_UNIFIED_SHIELD_READOUT.md`。
