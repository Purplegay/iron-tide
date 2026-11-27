# 三图地图验收补测与移植技能门槛

沿用 [三张零售图逐格复核](SESSION_2026-11-26_THREE_RETAIL_MAPS_WALLS.md) 的三图 SHA、桥段/维修点坐标、墙栏装配及逐格证据。本轮无新的生产地图或地物变更，不向旧档补种。

## 持久检查规范

`docs/skills/yr-campaign-porting/SKILL.md` 和已安装 `yr-campaign-porting/SKILL.md` 同步新增「地图覆层必须单独验收」。从零售 IsoMapPack5、OverlayPack/DataPack、Structures、剧场 TMP 取证，分别核对开场／时代切换实体、门洞、连接、碰撞、寻路、碾压、摧毁、任务目标、边界裁剪。逐桥逐端验桥上／桥下及断修，独立进程核对已毁障碍和断桥不复活；实际加载贴图先扫描，再经用户同意做有头同机位核查。区分装配、夹具移动、玩家真实命令和自然游玩。

## 已补的验收

Godot 4.7.2 隐藏无头，使用各关独立 APPDATA。日志 `.validation/three-map-retail/followup/`，以下用例 stderr 为空，共 230 项。

|地图|复跑入口|实测及范围|
|---|---|---|
|好莱坞|`res://tests/hollywood_campaign.tscn -- --bridge-all-entries` 29/29；`--bridge-orders` 11/11|六座高桥 11 处可玩桥头，每处用灰熊坦克实际碰撞移动接口向前 4 格再原路退出，核对位置、桥面层级、落回街道，保留裁剪的一端。逐桥是夹具步进，不是每端完整下令。正常命令实车覆盖南段；另有前轮 `--bridge-tech` 的样本桥下横穿。|
|好莱坞|`--write-broken-bridge` 8/8；`--cold-bridge-broken` 64/64；`--cold-bridge-repaired` 44/44|六个断面同档写入，独立进程检查三车道阻挡，工程师走正式交互（用夹具到入口）修好，然后再冷读确认可走。|
|首脑游戏|`res://tests/head_games.tscn -- --write-broken-bridge` 3/3；`--cold-bridge-broken` 10/10；`--cold-bridge-repaired` 6/6|低桥断面、两端小屋、通行数据和维修终态跨进程持久化。低桥未补两端逐车完整过桥命令。|
|时空转移|`res://tests/time_shift.tscn -- --write-golden-gate` 52/52；`--cold-golden-gate` 3/3|实际任务场景推进两次穿越、触发任务桥坍塌、写断点；冷读保留返回时代和断桥，坍塌桥段不复活。此桥是脚本建筑，未把它当有通用修复小屋的桥。|

`tools/check_native_terrain.py` 追加八邻接归组，输出包围格和峰值格以供同机位验收；用实际贴图扫描：时空转移 `yr_sov01_terrain.png` 1,308 格，0 告警；好莱坞 `yr_all02umd_bridge_ground.png` 2,462 格，48 格/11 组；首脑游戏 `yr_sov07_terrain.png` 1,239 格，54 格/11 组。三个命令退出 0，保护区无回归；后两张的告警只是候选，未做有头画面判断和重烘。仍待：逐桥正常命令和桥下路线完整矩阵、逐组同机位画验（需用户同意）、三难度自然通关和发行包。未改玩家档、未打包。
