# 2026-11-26 镭射幽浮吸电不扣血与断电提示

用户截图：两架幽浮停在己方满血建筑旁。用户已明确建筑是苏军采矿场（NAREFN）；先前误认成核电站。下文第一阶段是独立的吸电修补，不是该截图的成因。未读取玩家存档，不推断具体关卡或每一架的指令。

- 本机 Steam 尤复 `expandmd01.mix > 0x8218f9f4` 提取的 `rulesmd.ini`（SHA-256 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`）中，`DISK` 的 Primary 为 `DiskLaser`，Secondary 为 `DiskDrain`；后者 `DrainWeapon=yes`，`NANRCT` 为 `Drainable=yes, PoweredSpecial=yes`。保留吸电不扣血，不把特殊武器改作普通伤害。零售规则还标记一些防御建筑可汲取，本次未做全部目标的原版机制移植。
- 原逻辑断电时 `side_power_low()` 为真，但顶栏读账面供电，生产乘数也按账面产电/耗电比算。`scripts/world/battle.gd` 现在统一读取已有 `blackout_*` 状态：电力事件、语音低电过渡和 HUD 有效供电按断电处理，生产使用既有最慢倍率 0.5。保留账面电力及其非断电用途。`scripts/ui/hud.gd` 在这段时间显示「基地断电 - 生产减缓」。`scripts/units/head_games_weapons.gd` 首次对玩家吸电时报一次原因，不缩短已有更长断电计时。未更改武器选择、原有四秒续期或矿场资金数值。
- Godot 4.7.2 隐藏无头、全新隔离 APPDATA（另设 `IRON_TIDE_DISK_TEST_USER` 为同一路径），运行 `--headless --path . --quit-after 350 res://tests/disk_blackout_regression.tscn`。实际遭遇战 Battle/HUD，固定摆位并经 `order_target`、`_fire_shot`；清除冻结线圈的摆下动画，手动推进 Battlefield `_process` 验断电到期。13/13、退出码 0、stderr 空。覆盖核电站不掉血但断电、磁暴线圈停工并恢复、HUD 进出断电、生产倍率、消息不重复、长断电不缩短、普通车厂实际掉血、苏军矿场取款。日志 `.validation/disk-blackout-20261126/final.{out,err}`。
- 未跑自然寻敌逼近、长局、多房号、雷达交互、冷读档、有头或发行打包；未改玩家存档，未发布。既有 `blackout_*` 计时循环只覆盖 ally/enemy，本次未扩展。

## 采矿场后续修正

零售同源 `NAREFN` 为 `Refinery=yes, Drainable=yes`；实际战场走 `DiskDrain`，不扣建筑血量、不触发断电，保留工程既有每次最多 50 资金。`battle.gd::transfer_drain_funds` 先扣实际余额再入对方账，完成后才发玩家 HUD 资金事件，绕开免费购买不扣款的逻辑；余额不足只转现有金额。`head_games_weapons.gd` 对涉及玩家的实际转账增加战况日志和建筑处金额飘字，余额为零不追加提示。

用同一测试场景和隔离 APPDATA 重跑：19/19、退出码 0、stderr 空；验证 NAREFN 武器选择、双向实账和实际 HUD 日志、不掉血不断电、余额 12 时只转 12、免费购买不凭空造钱、空余额不追加日志。证据 `.validation/disk-blackout-20261126/refinery-final.{out,err}`。飘字接入但未有头目视；未测多房号、持续自动吸取、截图原局或发布包。
