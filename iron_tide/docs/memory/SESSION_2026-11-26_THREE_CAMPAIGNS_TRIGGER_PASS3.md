# 三关脚本再查：登陆队全灭、维修厂喊话、城堡受袭

沿用 mapsmd03.mix 零售提取件和哈希，见 [上一轮触发补接](SESSION_2026-11-26_THREE_CAMPAIGN_TRIGGER_FOLLOWUP.md) 与 [AI/媒体审计](SESSION_2026-11-26_THREE_CAMPAIGNS_AI_MEDIA.md)。本轮定点检查，非三关全部触发器逐项运行。

- SOV01UMD：`082C3CEC` 源 Tag `082C34CC` 是第一批卸载的 4 辆犀牛，原动作同时调用两艘后援；`082C79BC` / `082C77EC` 分别挂后援动员兵与犀牛，归零重新启用 `082C467C/082C44AC`，沿用 3/9 规则秒及沉艇检测；`07FA53DC` 在关闭旧金山时撤销。`time_shift.gd` 保存编组成员引用，区分空艇与地面编组；第一批犀牛在陆上全灭时补尚未发出的后援，已有后援不重复生成。后援在陆上全灭后排本组；并列分支冲突时保留已生成组属适配决策。仍沿用现有航线，不补返航；老档无成员登记不猜测历史单位。未验后援动员兵实际陆上团灭与全部重复组合。
- ALL02UMD：`094D821C` 条件 32 建筑存在、索引 27 NADEPT。`hollywood_mission.gd` 补施工状态门槛，排除 GADEPT，完成且玩家拥有才提交 `xa2yu01`。专项验语音事件进入队列，不等于实听。`09635F3C/0CEBD51C` 残余基地出售与追击、`Carville_Comment` 的播放时机仍未移植，本轮不猜测涉及街道特殊建筑的房号前置。
- SOV07UMD：`05BC965C` 原图为 Castle Attacked。`building.gd` 从正实际伤害触发，`head_games.gd` 不再以受伤状态轮询，警报和守军保持一次。正常致命命中仍经过伤害入口；本轮测试覆盖非致命、直接赋血量和重复受击；未单测一击致死、归属与修理全过程。回收厂居民房转属与欢呼仍待。

验证：Godot 4.7.2 `--headless --path .`，隔离 APPDATA，各项从真实任务卡进入。`res://tests/time_shift.tscn -- --landing-group-loss` 7/7，`--landing-backup` 8/8，主线 51/51；`res://tests/hollywood_campaign.tscn -- --depot-taunt` 8/8，主线 94/94；`res://tests/head_games.tscn` 51/51。共 219 项、最终六组 stderr 空。日志 `%TEMP%/IT-trigger-pass3-d2a3e48bd6ee47b087ec09ee8b423f5d` 的 land、boat、depot-final、s07、holly-main、s01-main。夹具摆位、注入伤害并推进计时，调用实际卸载函数；不等同于自然完整通关，新增成员关联未独立进程冷读、未有头、未碰玩家档和发行包。
