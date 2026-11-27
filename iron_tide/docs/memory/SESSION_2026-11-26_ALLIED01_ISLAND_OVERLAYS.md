# 盟军首关：恶魔岛围栏与原图覆盖物核查

用户问控制器周围原来是否有栅栏，并要求查地图。零售 `ALL01UMD` OverlayPack/OverlayDataPack 确认目标周界 u=84..90、v=26..32 有 23 格 CAFNCP，开口 (84,29)，不是建筑表里的条目。覆盖物 ID 是零售 INI 非注释条目的零基顺序，不能用左侧编号。原图 SHA `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`。`tools/export_allied_first_overlays.mjs .validation/allied-ends-20261126/source data/maps/yr_all01umd.json data/ra2/allied_first_overlays.json` 扫 9,400 可玩格，328 个覆盖物：99 CAFNCP、67 GAWALL、25 CAFNCB，122 矿宝覆盖，8 石块、7 瓦砾，标准桥覆盖为零（金门桥是特殊建筑，不等于没桥）。

- `allied_first.gd` 把 191 格墙/围栏按原格和 55 单位间距挂到实际 Battle，复用原画、墙段连接、碰撞和寻路。没有重烘贴图，未改桥坡。旧档首次读入会装配，存在状态位后不重复生成；`GameData`/`battle_saves.gd` 接本关围栏定义/校验。显式右键单位可瞄准这些中立墙，`ForceFire` 保留明确目标进入溅射结算，不加入自动索敌；已有武器的破墙/木墙能力仍决定能否造成伤害。HUD 提示围栏挡路先打缺口。
- Godot 4.7.2 隐藏无头、隔离 APPDATA：`tests/allied_first_playable.tscn -- --island-walls` 24/24，`--cold-island-walls` 2/2，均 exit0、stderr 空，查全图数量、真实墙画支持、入口网格路径、实际写档不重复。`--reported-slot2 --swim` 36/36、exit0、stderr 空，旧档副本装配后，用夹具拆北侧五段围栏、清敌及推进时间，谭雅实际跨水、C4 与胜利。日志 `.validation/allied01-playable/{island-walls,cold-island-walls,island-breach}.{out,err}`。直接从谭雅落点点控制器会被围栏或 CASANF05 监狱底盘卡住；数版强制引导不稳全部撤销，西侧网格能规划不等于实车完成。未用真实单位发射拆这批围栏，也未验现场围栏破坏后独立冷读。
- 未做窗口实景、未改玩家存档。原图数据查到石块和瓦砾不等于已补场景，8+7 未补；其余城市/恶魔岛原图建筑、桥坡与光照没有宣称整图通过。本轮只完成覆盖物盘点与围栏层，现有完整移植缺项见脚本核对表及此前记录。
