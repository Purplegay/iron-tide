# 三关设施、受袭支线与媒体复核

依据零售地图、哈希和来源见 `SESSION_2026-11-26_THREE_RETAIL_MAPS_WALLS.md`、`SESSION_2026-11-26_THREE_CAMPAIGNS_AI_MEDIA.md`。本次专项，不是 681 条触发逐项运行。

- **SOV01UMD**：Alliance 的 CATHOSP (90,96) 确有 `InfantryGainSelfHeal=1`，之前医院对象可占领，但 `building.gd` 的周期治疗只挂盟军关。补首关入口和换边清空旧周期；机械维修厂仍走既有载具维修。`07837A2C` 发现医院和 `05BF366C/05BF4E3C` 维修介绍不仅有原声。`time_shift_events.gd` 补 98/64 航点、医院局部揭示及原图 120/200 帧闪烁；保留可见性适配，未恢复维修厂原图不同房号的 25 秒启动及强制镜头。
- **ALL02UMD**：`0ABA8C5C → 0ABAE7BC` 及 `08E32CFC → 065C3EDC` 的前置是事件 6，分别绑五名新兵、两辆坦克与三栋建筑。`hollywood_mission.gd` / `hollywood_bases.gd` 从原始布局坐标登记标签，`unit.gd` / `building.gd` 正伤害通知；只靠近不招募，标签目标受袭后转属与播报。旧档缺标签延续旧触发，不凭现有位置重绑。原队伍额外行为 `0C9C885C/0789F21C`、克林特完整片场/Carville CG 链未移植。现有医院、机场、油井沿用机制；复跑维修厂未占/占领/易手/损毁。
- **SOV07UMD**：BadGuy1 的 CASLAB (171,98)，`rulesmd.ini` 可占不可出售，本图 `[CASLAB] SecretBuilding=GTGCAN`。`data/head_games.json` 修定义，`battle.gd` 和 `hud.gd` 实时用实验室与己方任一建造场授予巨炮，涵盖请求、在建、选址及已就绪交付权限。失去实验室不拆已建巨炮；已付队列保留、失去权限不能推进或交付。此处按现有联合建造栏适配，不声称通用秘密实验室规则已移植；旧快照若存有旧 CASLAB 定义未迁移。
- 房色复核依据：好莱坞 Americans DarkBlue、三个尤里房 Purple、Special Grey；本轮复跑实际尤里反应炉和守军材质检查。苏一医院和苏七秘密实验室由占领实测颜色随实例即时转属；未重新调色，未全房逐贴图或旧档冷读。影片不新增；首关与第七关媒体路径、好莱坞主线影片与对白、三关 11 段正片/收藏图及 4 音轨可加载。

## 实测与交接

Godot 4.7.2 隐藏无头，隔离 APPDATA，日志 `.validation/three-special-sites/`。`res://tests/time_shift.tscn -- --hospital-feature` 8、`--media` 50；`res://tests/head_games.tscn -- --secret-lab` 13、`--media` 42；`res://tests/hollywood_campaign.tscn` 100、`--shop-repair` 13；`res://tests/cg_collection.tscn -- --three-campaign-assets` 26。合计 252，最终对应日志 `s01`、`s01-media`、`lab-final`、`s07-media`、`h-ship`、`h`、`cg`，stderr 空。测试用摆位、伤害夹具、计时推进，巨炮直接调用正式交付入口，未人工点卡/走选址；未有头、冷读新分支、逐句耳听或全难度自然通关。未改玩家档、未打包。中途共享工作树的 local_traffic.gd 类型错误已由当时工作树后续变动消失，失败的中间日志不计。

已同步更新仓库 `docs/skills/yr-campaign-porting/SKILL.md` 和已安装技能，文件哈希一致。增加科技设施实效／建造特权失效、支线按标签和事件类型、房色/雷达/识别描边分离，以及语音入队、原声、字幕和影片触发时点分别验收的门槛。
