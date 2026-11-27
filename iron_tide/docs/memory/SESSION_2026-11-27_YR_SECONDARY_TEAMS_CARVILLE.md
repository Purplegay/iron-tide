# 首关副队与招募、好莱坞卡维利正片和实战追击

接续 `SESSION_2026-11-27_THREE_RETAlL_ACTION_CHAINS.md`、`SESSION_2026-11-27_THREE_TRIGGER_RUNTIME_PASS.md`；零售证据哈希沿用。没有改玩家档或出发行包。

- SOV01：`tools/export_time_shift_global_ai.mjs` 补导出副队的实际 TaskForce/ScriptType，重建 `data/maps/time_shift_global_ai.json`（165 条零售启用定义；尤里侧 45 条中 15 个副队引用，招募标志的主队 2 条）。`time_shift_global_ai.gd` 主、副队独立预留编号、分别以现有工厂或可招募闲置兵员填员。`battle.gd` 由实际出厂回调注册正式成员；不会重复招同一个单位，不接管登陆队、巡逻队或指定工程师。支持部分作战类别、脚本 46 低位指定建筑类型、驻反应炉、警戒与跳回。`time_shift_events.gd` 将一般电力目标与 `46,131081` 的专门 NAPOWR 分开。仍非全局引擎等价：复杂动作 5/9/49/53/54/58/61 等、类型46高位选择语义、其它侧、动态权重、真实集合与队伍级协调未完整解释。副队只有具备生产或招募条件才创建；原关无对应厂时不造假厂。专项用真战场及夹具检验副队数据、现有坦克招募、无款消耗和不重复；没有实测每条全局规则与补设工厂的完整扣费出厂流程。
- ALL02 `05D9EE6C Carville_Comment`：零售 `movmd03.mix` 成员 `0x256ab317` 为 `A02_P03E.bik`，SHA `e7cd88ac6fd4641993318459ed148472199e73fb5f78fd9b30b0e3df03701844`，6.73秒、140×110、44.1kHz 立体声，抽帧明确卡维利。对照 `A02_P02E.bik` `0xee3660b2`，SHA `8e011821bed8156fcbf1725b2c182e5b2720de6b8c25b97c46b82d4c224550e4`，17.27秒、伊娃和回收厂模型。地图动作键 9 与 `artmd.ini` 文本键的差异按片段序号和内容核对，不能直接取同键。克林特触发后15秒播正确 `A02_P03E`，前言回收厂保留 `A02_P02E`。将原 Bink 转 Theora/Vorbis，正片原声随片；同 ID 收藏节选从2.4秒取帧，肉眼确认。未逐句听写，因此没有伪造卡维利字幕；未人工验证该卡进度条、逐句音画、片中冷读。
- ALL02 `09635F3C` 与 `0B20458C` 前轮已有立即与5秒重发。本轮测试走实际触发处理，夹具清副房前置建筑并设置拆厂/克林特标志，观察立即发令；手动取消以确认4.9秒不重发，超5秒观察第二次命令，残军坦克摆近建造场后由真实物理及武器命中。未测跨图自然长途追击、无目标/换边等所有分支。史泰龙专项在真场景移除外来火力、用夹具置支线已唤醒，演员不摆位、目标不预扣血，实际用本体武器击毁两栋脚本目标并走到470号航点。

Godot 4.7.2 隐藏无头、隔离 APPDATA，日志 `.validation/three-retail-followup/`：`res://tests/time_shift.tscn -- --island-teams` 58/58，`res://tests/hollywood_campaign.tscn -- --actor-report-sale` 13/13、`--stallone-combat` 9/9，`res://tests/cg_collection.tscn -- --three-campaign-assets` 28/28。合计 108；stderr 均空。未全难度自然通关、未冷读本批新分支。
