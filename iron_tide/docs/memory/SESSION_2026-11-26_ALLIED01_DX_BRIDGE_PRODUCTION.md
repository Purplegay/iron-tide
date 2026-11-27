# 美国首关：DX 炮击、金门桥连接段级联、敌房生产入口

接 `SESSION_2026-11-26_ALLIED01_FOLLOWUP_FLEET_GGI.md`。只针对用户点名的三项开始接入，不宣称全量完成。

- DX（`0955BB7C`）ScriptType `46,131138`：131138=`0x00020042`，低 16 位 66 对应零售 rulesmd `[BuildingTypes]` 的 `NANRCT`，以 Confederation 房的活核电站为任务目标，走正式显式攻击与真实 DMISL 发射。用强制攻击是因为 French/Confederation 当前压为同一战斗侧，且零售两房盟友；上位 2 的目标选择策略及 42,2 未还原。首发后推进是项目近似，未验导弹命中和伤害。
- BridgeHouse：`Connector_Gone 07A8917C` 明确检查 CASANF09，后续在 BS/BH 位置施加伤害。`BackBridge_Gone` 后的附着销毁标签在零售 Structures/Units/Infantry/CellTags 未找到对应行，本批仅把 BH 附近 CASANF11 作连接段代理。穿越恢复后 CASANF09 毁坏会击毁低血的相邻 CASANF11，记录一次性旗标，保留 CASANF12 和原始断口，不做全桥坍塌猜补；分层通行和跨段阻断仍待验。
- `Build_Dom 0B8A090C` 动作 3 启动 Confederation 房；原图 `NodeCount=1`, `000=YAPPPT,46,69`，该房唯一预置 YACNST 在可玩边界外 (-0.5,85.5)，可玩范围没有它的工厂。`allied_first.gd` 给已有的过去时代控制器生成入口记该房身份并接普通建筑施工（1 模拟秒为近似、零费，不动共享敌方钱包）。不是全局 165 条条件执行，不擅自塞厂或套遭遇战 AI。保留原故事位置、先于支援和谭雅阶段；零售建造场的场外存在、生产条件、重建及 50 的胜利门槛仍待核实。

Godot 4.7.2 隐藏无头、隔离真实存档 2 副本：`tests/allied_first_playable.tscn -- --reported-slot2 --dx-bridge-production` 29/29；`--cold-crossing --after-midpoint` 7/7；`--reported-slot2 --carriers` 35/35，均 exit0、stderr 空。测试夹具推进前置及施工时间、伤害打断桥；观察实际 DX 导弹从原位出场后发往核电站而非注入发射。船只瞄准、桥段存活与控制器唯一性已验；未图形验收、未发行。证据 `.validation/allied01-playable/dx-bridge2.{out,err}` 与 `dx-reg-{cold,carrier}.{out,err}`。玩家 slot2 SHA 未变 `57213705CE674EEBC6DE9F8D77E10402E856D8F767ABD4BD3EA5BD543F442E0B`。
