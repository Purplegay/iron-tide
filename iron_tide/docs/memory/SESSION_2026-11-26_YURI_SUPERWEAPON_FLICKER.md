# 尤里超级武器待机关盖闪烁

玩家截图反馈心灵控制器在战场一直闪。旧的 `assets/ra2/bldanim/YAPPET.json` 和 `YAGNTC.json` 按 Godot 的闭区间把 0、1 当成一段待机动画，且未导出受损覆盖、配对投影。帧 0 是完整关盖，帧 1 是受损关盖，后两帧是各自投影，原样来回播会随时间切换整块外观；基因突变器同源。心灵控制器底座灯光另有 20 帧（10 个前景 + 10 个投影）；现有前景帧 5 已包含受损灯位，健康不能播到它。

- 原版证据：本机 Steam 零售 `artmd.ini` 来自 `ra2md.mix > localmd.mix`，SHA-256 `e1f0378394313c04ebbd5073f47785ee3e46f1b3c62d65724e8f3c310ee7ba31`。`YAPPET_E/ED`、`YAGNTC_E/ED` 使用同一 SHP、`Shadow=yes`，区间分别从 0 和 1 开始。温带实际解码 `genermd.mix` 中 `YGPPET_E` 与 `YGGNTC_E` 各 4 帧，`YGPPET_A` 20 帧；现有 PNG 像素核对其对应区域。灯光受损沿用原版起点 6，裁到最后一帧前景 9。
- 修改两个动画描述：关盖正常固定帧 0，受损固定帧 1，仍依既有建筑判伤阈值；各取偏移 2 的对应影子。灯光正常 0–4，受损 6–9，配对影子偏移 10。`tools/yuri_superweapon_idle_art.mjs` 是共享导出逻辑，接入 `tools/yuri_skirmish.mjs`、`tools/head_games_sites.mjs`；本次只按零售帧数重生成两份描述，没有重烘 PNG、改高光贴图、改充能/伤害或另一个没有这些动画层的剧情对象 `YAPPPT`。
- Godot 4.7.2，独立 APPDATA、隐藏控制台：`--headless --path . res://tests/yr_superweapon_idle_art.tscn`。从正式遭遇战的建筑放置入口创建两类建筑，设血量 100%→40%→100%，每档对实际选层及帧选择做等效 10 秒的采样，并验证资源和影子帧。修前 11/29（exit 1），修后 29/29（exit 0），均无 stderr。真实菜单出击的 `res://tests/allied_finale_playable.tscn` 36/36、exit 0、无 stderr，包含脚本生成心灵控制器及胜利结算。日志 `%TEMP%/IronTide-YuriIdle-20261126-200739/{before,after,finale}/{out,err}.log`。
- 未做有头逐帧截图或冷读档复验，未启用原版开盖、就绪、发射与低电独立图层；本次范围是待机闪烁。未运行全量资产再导出、未打包、未改玩家存档。
