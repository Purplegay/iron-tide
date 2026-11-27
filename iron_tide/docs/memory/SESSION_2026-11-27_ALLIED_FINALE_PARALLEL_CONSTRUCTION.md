# 盟军终关：双基地并行建造（2026-11-27）

玩家确认两阵营应能同时建造。适用盟军终关《脑死》（ALL07SMD；原图火地岛 NACNST 与 `0964b13c` 盟军基地车，见 `ALL07SMD_SCRIPT_RECHECK.tsv`）。替代 `SESSION_2026-11-27_ALLIED_FINALE_BASE_TABS.md` 中当时的共用队列决定；不改任务触发器、地图 AI、科技与建造场前置。

`battle.gd` 将本关玩家队首、就绪阻塞、预约容量、暂停和继续按阵营×建筑/防御分类，最多各基地各跑一条建筑和一条防御；两边用同一笔资金，未改变扣费、公用电力或建造速度规则。现有失厂退款仍按建筑所属阵营执行。继续用订单 ID 推导阵营，存档字段不变。`hud.gd` 与 `unlock_guidance.gd` 同源显示各基地进度、就绪及排队状态。其它模式不拆分。

Godot 4.7.2 隐藏无头、独立 APPDATA，`res://tests/allied_finale_playable.tscn -- --parallel-construction` 45/45、`-- --cold-dual` 5/5，退出 0 且 stderr 空。证据 `.validation/finale-parallel-construction/`。从真实菜单出击，取得苏军建造场，夹具放置盟军建造场及两兵营，用实际 HUD 信号下单、推进，验双建筑同时扣费、暂停独立、各自就绪放置、双防御、只退款失厂阵营、冷读双在建订单续造。普通完整回归在后段遭遇现有 `allied_retail_script.gd::resolve_spawn` 访问缺失 `waypoint`，导致增援未生成；该链不在本次改动内，不能宣称整关回归通过。未做有头验收、未改玩家存档、未打包。
