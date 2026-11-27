# 美国首关城区、基洛夫与任务提醒

Iron Tide 0.32。原图 ALL01UMD，NEWURBAN，SHA-256 为 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`。正式入口为战役菜单的盟军首关。

| 范围 | 本批新增 | 累计 | 剩余 |
|---|---:|---:|---:|
| [任务触发器](ALL01UMD_SCRIPT_RECHECK.tsv) | 40 | 214 / 334 | 120 |
| [本图 AI 小队](ALL01UMD_AI_RECHECK.tsv) | 20 | 59 / 91 | 32 |

## 本批在战场上的变化

沿现有穿越抵达与后续舰队交接继续推进。Create_Stuff2 将原有五支舰队从整组手写生成转为逐条动作 80 创建，再依 Play_Movies 的谭雅存活条件启动城区。先后出现七支和八支中立车辆，八名行人使用四个原编组。包含警车与皮卡的循环行驶、车辆指定停靠朝向、平民警戒和受惊移动。普通及困难另有一艘苏军基洛夫，简单不派。警车与缆车共用原有车型数据，战场和冷读兼容校验共用同一份首关清单。

获得操控后，供电目标按原图每 150 游戏秒提醒，时光机镜头取消提醒。谭雅入场后，恶魔岛任务按 120 游戏秒提醒，阵亡取消。32 个建筑条件按原图数值类型、房号、存在与缺席、局部变量执行。393–400 所指的八种建筑均未预置，409 为第八发电厂 CAPOWR08。第八组四条条件保留两个不同类型，不按行名改写。32 条中，17 条在原图初始布局或第八厂转属时得到正向覆盖；15 条仅通过隔离房号/类型夹具正向验证，同时在原图确认条件受阻。

## 任务逐 ID

| ID | 原图触发器 | 结果或条件 |
|---|---|---|
| 046358ac | Mission2_Text | 谭雅出场后120游戏秒显示恶魔岛目标；阵亡取消 |
| 06cbe3fc | Mission1_Text | 交还控制后150游戏秒未完成供电时显示目标；时光机镜头取消 |
| 089d5a8c | Create_Stuff2 | 五支后续舰队按动作80航点创建，启用Play_Movies |
| 0899832c | Play_Movies | Tanya_Dead清除时置穿越变量3并启用城区 |
| 0b3778ec | Make_Civ_Cars1 | 七支城市车辆；启用基洛夫与第二组车辆 |
| 0921804c | Create_Kirov | 仅普通/困难，304接近后攻击岸炮、146/147投弹、148退场 |
| 0692a65c | Make_Civ_Cars2 | 八支城市车辆；启用行人 |
| 06a1d17c | Make_People | 八次行人出场、四个独立TeamType；Make_People2待接 |
| 07a67d1c | PP1_Is_America | Americans 的 CAPARK04 存在；局部变量 31；原图无此建筑，仅条件夹具正向通过 |
| 07a677bc | PP1_Is_Neutral | PowerHouse Country 的 CAPARK04 存在；局部变量 32；原图无此建筑，仅条件夹具正向通过 |
| 07a6737c | PP1_Not_America | Americans 的 CAPARK04 缺席；局部变量 31；正式战场初始或占领第八厂实测 |
| 07a671fc | PP1_Not_Neutral | PowerHouse Country 的 CAPARK04 缺席；局部变量 32；正式战场初始或占领第八厂实测 |
| 095a8c3c | PP2_Is_America | Americans 的 CAPARK05 存在；局部变量 33；原图无此建筑，仅条件夹具正向通过 |
| 095a856c | PP2_Is_Neutral | PowerHouse Country 的 CAPARK05 存在；局部变量 34；原图无此建筑，仅条件夹具正向通过 |
| 095a828c | PP2_Not_America | Americans 的 CAPARK05 缺席；局部变量 33；正式战场初始或占领第八厂实测 |
| 095abc2c | PP2_Not_Neutral | PowerHouse Country 的 CAPARK05 缺席；局部变量 34；正式战场初始或占领第八厂实测 |
| 095ab94c | PP3_Is_America | Americans 的 CAPARK06 存在；局部变量 35；原图无此建筑，仅条件夹具正向通过 |
| 095ab66c | PP3_Is_Neutral | PowerHouse Country 的 CAPARK06 存在；局部变量 41；原图无此建筑，仅条件夹具正向通过 |
| 095ab38c | PP3_Not_America | Americans 的 CAPARK06 缺席；局部变量 35；正式战场初始或占领第八厂实测 |
| 095aac9c | PP3_Not_Neutral | PowerHouse Country 的 CAPARK06 缺席；局部变量 41；正式战场初始或占领第八厂实测 |
| 095aa92c | PP4_Is_America | Americans 的 CALA14 存在；局部变量 36；原图无此建筑，仅条件夹具正向通过 |
| 095aa64c | PP4_Is_Neutral | PowerHouse Country 的 CALA14 存在；局部变量 42；原图无此建筑，仅条件夹具正向通过 |
| 095aa36c | PP4_Not_America | Americans 的 CALA14 缺席；局部变量 36；正式战场初始或占领第八厂实测 |
| 095a9cfc | PP4_Not_Neutral | PowerHouse Country 的 CALA14 缺席；局部变量 42；正式战场初始或占领第八厂实测 |
| 095a998c | PP5_Is_America | Americans 的 CALA15 存在；局部变量 37；原图无此建筑，仅条件夹具正向通过 |
| 095a96ac | PP5_Is_Neutral | PowerHouse Country 的 CALA15 存在；局部变量 43；原图无此建筑，仅条件夹具正向通过 |
| 095a93cc | PP5_Not_America | Americans 的 CALA15 缺席；局部变量 37；正式战场初始或占领第八厂实测 |
| 095b6f3c | PP5_Not_Neutral | PowerHouse Country 的 CALA15 缺席；局部变量 43；正式战场初始或占领第八厂实测 |
| 095b688c | PP6_Is_America | Americans 的 CABUNK03 存在；局部变量 38；原图无此建筑，仅条件夹具正向通过 |
| 095b65ac | PP6_Is_Neutral | PowerHouse Country 的 CABUNK03 存在；局部变量 44；原图无此建筑，仅条件夹具正向通过 |
| 095b62cc | PP6_Not_America | Americans 的 CABUNK03 缺席；局部变量 38；正式战场初始或占领第八厂实测 |
| 095b2e6c | PP6_Not_Neutral | PowerHouse Country 的 CABUNK03 缺席；局部变量 44；正式战场初始或占领第八厂实测 |
| 095b2a5c | PP7_Is_America | Americans 的 CABUNK04 存在；局部变量 39；原图无此建筑，仅条件夹具正向通过 |
| 095b277c | PP7_Is_Neutral | PowerHouse Country 的 CABUNK04 存在；局部变量 45；原图无此建筑，仅条件夹具正向通过 |
| 095b249c | PP7_Not_America | Americans 的 CABUNK04 缺席；局部变量 39；正式战场初始或占领第八厂实测 |
| 095b21bc | PP7_Not_Neutral | PowerHouse Country 的 CABUNK04 缺席；局部变量 45；正式战场初始或占领第八厂实测 |
| 095b0d4c | PP8_Is_America | Americans 的 CAPOWR08 存在；局部变量 40；正式战场初始或占领第八厂实测 |
| 095b5f3c | PP8_Is_Neutral | PowerHouse Country 的 CALUNR01 存在；局部变量 46；原图无此建筑，仅条件夹具正向通过 |
| 095b5c5c | PP8_Not_America | Americans 的 CALUNR01 缺席；局部变量 40；正式战场初始或占领第八厂实测 |
| 095b597c | PP8_Not_Neutral | PowerHouse Country 的 CAPOWR08 缺席；局部变量 46；正式战场初始或占领第八厂实测 |

## 本图 AI 逐 ID

| TeamType | 原名 | 原房号 | 编组 | 原图指令 |
|---|---|---|---|---|
| 0A7AB0CC | TEAM_Truck1 | Neutral | 1,PTRUCK | 3,116 → 3,117 → 3,118 → 3,119 → 3,20 → 3,35 → 3,120 → 3,121 → 3,122 → 3,130 → 3,122 → 3,121 → 3,120 → 3,35 → 3,20 → 3,119 → 3,118 → 3,117 → 3,116 → 3,115 → 6,1 |
| 0A7ACC6C | TEAM_Cop1 | Neutral | 1,COP | 3,481 → 3,13 → 3,481 → 3,20 → 6,1 |
| 0A7AC7BC | TEAM_ConVehicle1 | Neutral | 1,CONA | 5,120 → 6,1 |
| 0A7AC30C | TEAM_ConVehicle2 | Neutral | 1,CONA | 5,120 → 6,1 |
| 0A7ADDEC | TEAM_Cop2 | Neutral | 1,COP | 3,134 → 3,135 → 3,136 → 3,137 → 3,138 → 3,13 → 3,138 → 3,137 → 3,136 → 3,135 → 3,134 → 3,133 → 6,1 |
| 06A1DEBC | TEAM_Civ3 | Neutral | 1,CIV3 | 19,0 → 6,1 |
| 068FE26C | TEAM_Calm_Civ1 | Neutral | 1,CIV1 | 5,120 → 6,1 |
| 068FFC5C | TEAM_Calm_Civ2 | Neutral | 1,CIV2 | 5,120 → 6,1 |
| 068FFB2C | TEAM_Calm_Civ3 | Neutral | 1,CIV3 | 5,120 → 6,1 |
| 068FC13C | TEAM_Stat_Stang | Neutral | 1,STANG | 42,6 |
| 068FDEFC | TEAM_Stat_SUVW | Neutral | 1,SUVW | 42,2 |
| 0692D74C | TEAM_SUVW1 | Neutral | 1,SUVW | 3,28 → 3,185 → 3,186 → 3,184 → 6,1 |
| 0692AB8C | TEAM_Cop3 | Neutral | 1,COP | 3,186 → 3,184 → 3,28 → 3,185 → 6,1 |
| 069226CC | TEAM_Cop4 | Neutral | 1,COP | 3,114 → 3,187 → 3,188 → 3,13 → 3,187 → 6,1 |
| 0C39AEFC | TEAM_SUVB_LL | Neutral | 1,SUVB | 42,4 → 5,120 → 6,2 |
| 0C39803C | TEAM_WINI_UR | Neutral | 1,WINI | 42,1 → 5,120 → 6,2 |
| 0C8992CC | TEAM_Stang2 | Neutral | 1,STANG | 3,191 → 3,192 → 3,193 → 3,194 → 3,107 → 3,195 → 3,196 → 3,197 → 3,198 → 3,111 → 3,112 → 3,114 → 6,1 |
| 08BF127C | TEAM_Bus1 | Neutral | 1,CBLC | 3,46 → 3,55 → 6,1 |
| 0A7C0A8C | TEAM_SUVB_2 | Neutral | 1,SUVB | 3,199 → 3,200 → 3,201 → 3,202 → 3,203 → 3,204 → 3,20 → 3,35 → 3,120 → 3,121 → 3,122 → 3,205 → 3,27 → 3,28 → 6,1 |
| 0941632C | TEAM_Kirov_HT | Soviet2 Country | 1,ZEP | 3,304 → 46,131136 → 3,146 → 59,146 → 3,147 → 59,147 → 3,148 → 37,0 |

## 验收

命令入口为 Godot 4.7.2 的 `--headless --path . res://tests/allied_first_playable.tscn --`。隔离 APPDATA 及输出位于 `.validation/allied01-map40/`。

| 项目 | 参数 | 通过 |
|---|---|---:|
| 普通、困难城区 | `--new-sequence-mainline --map40-city`，困难追加 `--hard` | 各 111/111 |
| 简单城区 | `--new-sequence-mainline --map40-city --easy` | 109/109 |
| 普通城区独立进程冷读 | `--cold-map40`，读取普通场景 quick 档 | 31/31 |
| 建筑条件与供电提醒 | `--map40-guards` | 70/70 |
| 基洛夫路线与原武器 | `--new-sequence-mainline --map40-city --map40-kirov-route` | 115/115 |
| 谭雅提醒和阵亡取消 | `--new-sequence-mainline --map40-reminder` | 64/64 |
| 原舰队 | `--new-sequence-mainline --followup-fleet` | 80/80 |
| 全图与主线结算 | `--field-audit --new-sequence-mainline --retail-transition --late-dominator` | 85/85 |
| 原任务解释器 | `res://tests/allied_retail_script.tscn -- --first-only` | 134/134 |

20 个唯一小队在正式场景逐队核对成员、原房号、出生航点、原图美术载入和第一条行动。皮卡实际驶离起点；基洛夫的后段采用航点摆位及岸炮受击夹具，两个航点由正常武器系统实际投弹。其余车辆未逐辆自然走完整圈。Make_People2 的后续驻军分支仍待接入。原图有 102 个 TeamType，其中 91 个有创建或招募引用，另 11 个仅定义；全局 AIMD 开关单独保留。

原图重算使用 `tools/audit_allied_ends.py`、已有 LZO 解码器与零售地图/剧场源。9,400 个地形格、981 个坡格、276 个航点及普通桥覆层与原图一致。189 个原始建筑中 157 栋在场、31 栋在界外、1 栋开局已毁。在场包括 104 栋 Neutral、5 栋 BridgeHouse。正式战场复核建筑位置、地基、房色与雷达记忆，差异为零。214 条入表记录的事件、动作已逐条和此次重解的原图作字段比较。截图 0 张。
