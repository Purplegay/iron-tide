# 美国首关驻防、增援、侦察与环境声

Iron Tide 0.32，新开盟军首关 ALL01UMD。原图 SHA-256 为 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`。

| 正式战场 | 本批新增 | 累计 | 剩余 |
|---|---:|---:|---:|
| [任务触发器](ALL01UMD_SCRIPT_RECHECK.tsv) | 50 | 264 / 334 | 70 |
| [本图 AI](ALL01UMD_AI_RECHECK.tsv) | 15 | 74 / 91 | 17 |

本批 15 个独立 TeamType 包括 8 支四人驻军、1 支四名动员兵和两条军犬的混编巡逻、2 支盟友鹞式战机，以及工程师、谭雅、航母和缆车各一支。32 名驻军先按各自原始出场点生成，再经正常寻路和驻军入口申请进楼。至少一名实际进入，冷读保留楼内成员；未逐人见证所有人到门。航母多次出场仍只算同一 TeamType。

50 条触发中 18 条管理穿越前后风、蟋蟀、海浪、鸟和街道环境，以及港口和缆车交接。玩家接近音源可听到零售样本。11 条管理盖特机炮发现、警报、教学、箭头的启停；第三区在零售地图没有启用来源，正式出击只验证不触发。既有供电后取消医院提示、穿越时撤销机炮提示等跨驱动启停仍有效。

## 逐 ID 任务清单

| ID | 原图名称 | 正式战场效果与限制 |
|---|---|---|
| 089b82bc | Tanya_Death | 阵亡置变量4，取消恶魔岛提醒并触发援军；配乐使用项目对应战况段 |
| 0ba104bc | Death_Reinforce | 变量3和4同时成立时首批3艘航母入场并前往417 |
| 0898812c | Ping_Carriers | 20秒后在PB提示增援并启用舰队全损检查 |
| 089b1ccc | Send_Carriers | 一秒后按同一TeamType派出3艘航母 |
| 0792b79c | Carriers_Killed | 美军航母全损后重新启用发送，追加一个编队 |
| 097d15dc | Time_Machine_Hit | 原时光机实际受击，且玩家没有谭雅时启用延迟通讯 |
| 0462b74c | Find_Hospital | 美国地面单位踏入原图发现格，揭示医院、闪烁建筑、雷达标记及教学；供电后取消 |
| 097d02cc | Time_Machine_Attacked | 三秒后播放保护时光机的原声通讯 |
| 0ac8355c | Apocs_Gone | 装甲出击后按原图 Special、Soviet2House 两房存活对象判断，包含普通与困难的基洛夫 |
| 0ac85f3c | Enter_Tanya | 清场后5秒，精英谭雅自PE出现、闪烁并移往93，恢复操控并启动恶魔岛提醒 |
| 04c19e5c | Start_Sounds2 | 派出AH缆车，循环137和33；接原难度装甲、控制器及断桥检查链接 |
| 0b94716c | Reveal_Gatt1 | 美军进入或飞过原图关联格，揭示目标、警报、雷达及箭头 |
| 095259ac | Reveal_Gatt2 | 美军进入或飞过原图关联格，揭示目标、警报、雷达及箭头 |
| 0b94432c | Reveal_Gatt3 | 原图禁用且无启用来源。正式接线，进入该区不提示；不计自然触发 |
| 0b945a6c | Reveal_Gatt4 | 美军进入或飞过原图关联格，揭示目标、警报、雷达及箭头 |
| 096109ac | TurnOff_Gatt1 | 15秒后撤销对应盖特机炮箭头的重复提示 |
| 0d38f4cc | TurnOff_Gatt2 | 15秒后撤销对应盖特机炮箭头的重复提示 |
| 097303dc | TurnOff_Gatt4 | 15秒后撤销对应盖特机炮箭头的重复提示 |
| 09610f3c | TurnOn_Gatt1 | 原图定时在指定航点播放箭头，停止触发器生效后不再重播 |
| 04c2263c | Start_New_Sounds | 按原动作开启五组交通声、三组鸟鸣与后续触发 |
| 092af4ac | Check_BridgePiece02 | CASANF10缺席后按原航点应用四次伤害 |
| 045a11cc | Gatt_Brief | 首次发现时播放原版盖特机炮说明 |
| 0d39599c | TurnOn_Gatt2 | 原图定时在指定航点播放箭头，停止触发器生效后不再重播 |
| 0973096c | TurnOn_Gatt4 | 原图定时在指定航点播放箭头，停止触发器生效后不再重播 |
| 0993f7bc | Stop_Rebuild | 原上游启用后5秒，关闭四门岸炮的重建检查 |
| 04c24a8c | Kill_Sounds3 | 按航点停止旧时代音源并启用下一组；五支已入账港区小队改为逐动作创建 |
| 04c2410c | Traffic_Sounds1 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 04c2d1dc | Traffic_Sounds2 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 089a6bac | Traffic_Sounds3 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 04bf608c | Traffic_Sounds4 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 04c0776c | Traffic_Sounds5 | 在2个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 089b776c | Bird_Sounds1 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 04bf8f3c | Bird_Sounds2 | 在6个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 04c3064c | Bird_Sounds3 | 在7个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 08a6340c | Make_People2 | 两名原市民补到AS和BE，六支四人苏军就近寻找可驻军建筑 |
| 04c230ec | Kill_Sounds2 | 按航点停止旧时代音源并启用下一组 |
| 0692c4ac | Make_Alcatraz_Men | 追加两支四人驻军和一支4动员兵、2军犬的双航点巡逻 |
| 04c23c0c | Kill_Sounds1 | 按航点停止旧时代音源并启用下一组 |
| 08ad89ac | WindSounds1_Pre | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 08adc8dc | WindSounds2_Pre | 在3个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 08adae2c | Crickets1 | 在6个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 08a00f3c | Kill_Pipes | 一秒后仅摧毁附有08A0080C的两段管线，未绑定的一段保留 |
| 04c199bc | Water_Sounds1 | 在10个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 09f7b59c | Wind3 | 在3个原始动作航点注册实际零售环境音，包括距离、音量、变调、间隔和并发限制 |
| 0c077bcc | Camera_Harriers | 两支 Alliance 鹞式战机按各自起点出场并飞向214；镜头及基地回跳接既有简报 |
| 0972981c | Camera_Bridge | 开场镜头转向原桥航点，启用战机镜头 |
| 0972907c | Camera_HarrierStart | 按10秒延迟转向PB，再启用战机镜头 |
| 08e56b3c | Barracks_Gone | 按美国兵营原实例检查失去/转属，启动补援条件 |
| 08e568dc | Engineer_Check | 过去时代前，低电力且无美军工程师时从EN派运输机，在EM空降4人；同一架次不重复 |
| 090ab04c | Engineers_Arrived | 实际落地后消费变量54，雷达通报并重新检查后续损失 |

## 逐 ID 地图队伍

| TeamType | 名称 | 原房号 | 编组 | 原始指令 |
|---|---|---|---|---|
| 08071C8C | TEAM_Carriers | Americans | 3,CARRIER | 3,417 |
| 0780F21C | TEAM_Harriers | Alliance | 1,ORCA | 3,214 |
| 0780BC8C | TEAM_Harrier2 | Alliance | 1,ORCA | 3,214 |
| 088C1A4C | TEAM_Tanya | Americans | 1,TANY | 3,93 → 11,11 |
| 060FB74C | TEAM_CableCar2 | Neutral | 1,CBLC | 3,137 → 3,33 → 6,1 |
| 098A9B5C | Alcatraz_Patrol | Confederation | 4,E2 + 2,DOG | 3,72 → 3,71 → 6,1 |
| 0788E0EC | SovGar_BV | French | 4,E2 | 64,0 |
| 0788F21C | SovGarrision_BW | French | 4,E2 | 64,0 |
| 0788BC4C | SovGarrision_BX | French | 4,E2 | 64,0 |
| 077D3BAC | SovGar_CK | French | 4,E2 | 64,0 |
| 077D3A7C | SovGarr_CL | French | 4,E2 | 64,0 |
| 077D394C | SovGarr_CM | French | 4,E2 | 64,0 |
| 077D381C | SovGarr_CN | French | 4,E2 | 64,0 |
| 077D36EC | SovGar_CO | French | 4,E2 | 64,0 |
| 0908B07C | Engineers | Americans | 4,ENGINEER | 39,54 → 11,11 |

## 验收与保留差异

Godot 4.7.2 无头正式出击，隔离存档和日志在 `.validation/allied01-map50/`。入口为 `res://tests/allied_first_playable.tscn --`。

| 验证 | 参数 | 通过 |
|---|---|---:|
| 开场、发现格、机炮原声、箭头、管线及战机 | `--map50-open` | 30/30 |
| 工程师正反条件、运输机真实落地及受击通讯 | `--map50-rescue` | 25/25 |
| 普通与困难城区、驻军及过去环境 | `--new-sequence-mainline --map50-past`，困难追加 `--hard` | 各 85/85 |
| 独立进程恢复驻军、声源与重复出兵检查 | `--cold-map50` | 4/4 |
| 上批普通档在本版本独立进程冷读 | `--cold-map40` | 31/31 |
| 普通全图、岸炮重建关闭、航母补发、获胜 | `--field-audit --new-sequence-mainline --retail-transition --late-dominator --carriers` | 91/91 |
| 简单全图与主线 | `--field-audit --new-sequence-mainline --retail-transition --easy` | 82/82 |
| 原始指令解释器 | `res://tests/allied_retail_script.tscn -- --first-only` | 162/162 |

从原图和剧场重解 9,400 个地形格、981 个坡格及 276 个航点，数据一致。189 个原始建筑中 157 栋开局在场、31 栋界外、1 栋已毁。在场有 104 栋中立房号建筑和 5 个任务桥建筑。正式出击检查地基、房色、雷达记忆和普通桥覆层。

旧存档维持原有任务流程，新出击开始使用这 50 条任务。载入后的音源保留位置和触发状态，单个环境声采样可重新起播。谭雅阵亡的音乐动作沿用本项目的战况配乐，未核验零售主题曲。开场沿用现有影片和操控交接，后续基地镜头衔接原始延迟。Clean_Map 的完整清理和建造仍属后续任务，本批只接其下游音源交接；控制器售出继续沿用已验证的换场断点。机炮和医院的进入格、清场与补援分支使用受控位置、毁坏或电力条件，未全程以自然游戏速度走遍地图。截图 0 张。
