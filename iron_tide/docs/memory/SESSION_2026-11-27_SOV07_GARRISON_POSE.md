# 首脑游戏：驻军进出时切换建筑外观

用户报告苏军第七关步兵进去了但建筑没变，截图可读 400/400 和驻军格；未从截图唯一识别建筑，未读取玩家档。本关真实场景中 400 HP / 6 格的可驻军建筑为 CAFARM01，另有 400 HP / 10 格的 CAEUR04、CAFRMA。

零售依据：`Brief:Sov07md` 对应 `mapsmd03.mix` 的 TEMPERATE 地图（SHA-256 `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`，见原图交接）。`data/maps/yr_sov07.json`、`data/head_games_sites.json` 和 `head_games_sites.gd` 决定实装建筑和驻军资格；逐张对照当前加载的 `assets/ra2/shp/*.json` 与实际零售 SHP 像素。13 类原版民用建筑主体依次是完整、受损、驻军，独立阴影从 3 或 4 开始；8 帧表另有第 3 帧废墟。没有重烘素材，没有把废墟或阴影选作主体。

`building.gd` 为从已核对图集加载、且有驻军资格的建筑选用真实驻军与阴影帧；损伤态仍按既有规则，撤出后立即回完整/受损空置帧。绘图锚点、选择底盘以空置姿态为准，不随沙袋挪位。迷雾静态快照与现场共享同一绘制入口。`civilian_orders.gd` 在最后一名失效驻员被清理时也请求重绘。战斗碉堡 NABNKR 原有正常/受损驻军帧保留并固定锚点；不改 YAPOWR/NATBNK 机制、存档格式、建筑位置、驻军容量、任务触发器或地图 AI。

Godot 4.7.2 隔离 APPDATA、隐藏窗口无头，`res://tests/head_games.tscn -- --garrison-pose` 从战役菜单出击，经真实驻军登记/撤出函数夹具验证 13 类民居和 NABNKR 的画层及锚点、半血与撤出，共 44/44。`-- --bunker-transfer` 4/4，实际解放一翼时堡与驻军一起换边。均 exit 0、stderr 空；证据 `.validation/s07-garrison-pose/`。测试验证共享绘制命令，并非 GPU 像素截图；未跑手动右键寻路、独立冷读或整关，未改玩家档，未更新发行包。此轮无任务触发器/AI 新接或逐 ID 新验收。
