# 美国首关：穿越后的敌方装甲 AI

接 `SESSION_2026-11-26_ALLIED01_FLEET_RETAKE.md`。用户要求补 AI。使用同一零售 ALL01UMD，原图 `05EE7C8C` / `05EE7B9C` 分难度生成 Special 房 `093DDC8C/093DD7DC/093DD32C/093DFDEC`，每队一辆 APOC，出场航点 CE/CF/CG/CH（82..85）；简单两队、普通和困难四队。`0AC8355C` 原图检查 Special / Soviet2House 两房，才启用谭雅。已有的另外六辆装甲属 Soviet2House。

`allied_first.gd` 在过去时代装配天启并保存一次性标记，原有两队补原图房号；谭雅门槛现在覆盖已实现的两个房的装甲，但不冒充全房所有对象灭绝。已有装甲先走任务航点，再由关卡 AI 检查可见、可攻击的目标，选最近者交正式攻击指令；有移动命令或已有有效目标时不打断，0.5 模拟秒一轮。现有寻路不能让坦克去原图临近桥的水格目标 78，天启暂从原始出场格就地进入接敌判定。出兵不是工厂生产。

Godot 4.7.2 隐藏无头、隔离存档 2 副本：`tests/allied_first_playable.tscn -- --reported-slot2 --ai-contact` 31/31，过半前 `--cold-crossing` 7/7、过半后 `--cold-crossing --after-midpoint` 7/7，均 exit 0、stderr 空。`--ai-contact` 用夹具推进充能、放置可见靶车并让一辆天启结束移动，再调用真实任务选敌，未指定攻击目标、未注入接敌伤害，实等正式战斗观察被选目标扣血。之后清装甲和控制器用夹具。冷读查房号数量、无重复出兵。日志 `.validation/allied01-playable/ai-final-{contact,before,after}.{out,err}`；未改玩家存档。

还缺：独立房号外交、资金、厂房恢复与零售全局 AI 条件；完整桥区路径、两支机动队自然集合及三档真实推进交火；`Attack_Tanya 089F2AAC` 的启用来源和行动先核清再接，不把一个表项存在当已启用；无畏舰原剧本与海战。当前只做装甲任务 AI，不宣称 AI 全移植。
