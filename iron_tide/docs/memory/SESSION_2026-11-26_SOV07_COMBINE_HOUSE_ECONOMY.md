# 苏军第七关：混编替补、独立敌房账户及漏接巡查

原图 `%TEMP%/IronTide-S07-retail/sov07.map`，Steam `mapsmd03.mix`，SHA-256 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`；原记录见 `SOV07_TRIGGER_INDEX.md`。

## 实装

- `head_games_combine.gd`、`unit.gd`：零售 Combine 01/02 的 `0DB2278C → 0DB1703C`、`0DB1203C → 0DB2246C`、`0DB5507C → 0DB55B5C`、`0DB5195C → 0DB560FC` 分别按车/乘员到位标志 7/8/11/12 控制 2 规则秒替补；先遣成员已经登记到位、但尚未合编时不误走前置补员。`0952AC5C` / `0954B2BC` 对应合编后死亡清理该对的到位/合编状态、重招两角色，保留另一对进度；不让运输工具和乘客死亡双重触发。01 与 02 各自编成后可出击，不再等两对凑齐、按统一 240 秒循环；已出击合编车的损失也会重组该对，解放任一翼后不招替补。01 的两秒编组等待 + 02 的 2/15 字段按串行近似为登车后 19 秒开第二对。仍以翼和座位模拟 Temp House 与原图脚本指令，用周边可招募单位/工厂代替原游戏选兵；03 五车链沿用既有实现。
- `head_games_economy.gd`、`head_games.gd`、`battle.gd`、`building.gd`、`unit.gd`、`economy_cycle.gd`、`head_games_orders.gd`、`allied_abilities.gd`、`head_games_weapons.gd`、`civilian_sites.gd`：BadGuy1/2/3 原图各 Credits=400，House 写出原字段时除以 100，实际每房 40000。分别维护尤里、受控苏军、受控盟军账户，不拆共同战斗敌方。单位订单、退款、维修、收入、矿车返厂/卸款、提纯器加成和资金类 AI 判定按各房。油井/回收厂/资金转移按实际设施或单位归属。解放或占领后生产走玩家款，未自动划走旧敌房余额。新账通过快照保存；旧版只存合账，迁移时将剩余敌款等分，不能恢复当时各房历史流水。仍未复刻原版逐房电力、动态 AI 权重及所有经济行为，不能当成完整 House 引擎。
- 漏接巡查：`0CBDEA2C` 原动作 55 只有雷达提示（加索菲亚语音），不是 17 揭开地图。`head_games.gd` 修为一次雷达提示、不揭迷雾。`0AA45A2C` / `0AA466CC` 原图拆回收厂还含行动队伍解散、房转属、居民欢呼、在 BU/BV 生成补给箱；当前有停止居民路线/援军，但未找到这两处专属箱子与原版完整转属链，列为待补。`0CBF5A9C` 西南回收厂受袭可与发现互斥触发，当前按可见才起守队，仍待按 Tag 重查；`06B5903C` / `0BA1D7AC` 的 ComboWarn01/02 文本及难度措辞尚未逐句认领。

## 验证

Godot 4.7.2，隐藏无头、独立 APPDATA，`--headless --path . res://tests/head_games.tscn --`：`--house-economy` 12/12；同档新进程 `--cold-house-economy` 3/3；`--combine-kia` 10/10；`--combine` 11/11；`--backdoor-script` 7/7；主线 49/49。日志 `%TEMP%/IT-s07-house-41c926f035b54f7e8bb02d9328adafd3`（`house-final`、`cold`、`kia-final`、`combine-b`、`back`、`main-final`），标准错误空。回归用夹具推进工时、摆位、伤亡；实际调用卸矿、扣款、登车、出击与结算，未完整自然等候或观察替代队最终交火。未冷读混编等待断点、未用旧真实档验证等分迁移、未逐条验证所有受袭和重复 KIA 时序，未有头验收/修改玩家存档/打包。
