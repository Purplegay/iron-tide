# 《好莱坞与虚荣》逐项复核

本机 mapsmd03.mix 中 ALL02UMD.MAP 的 Triggers 有 253 项，TeamTypes 有 199 项，ScriptTypes 有 121 项，CellTags 有 98 项。这些数量统计定义，包含条件分支。对照对象是 scripts/world/hollywood_mission.gd、战役大厅、战场、通讯和现有回归。

| 玩家经历 | 原图定位 | 当前实现 |
|---|---|---|
| 接管战场 | Camera_Start、Camera_to_LAX、Point_at_LAX、Camera_to_Grinder、Grinder_Movie、Return_Control 组织镜头和交还操控，BringOn_MCV、BringOn_GIs 负责队伍入场 | 尔湾标准基地，直接给坦克与开场语音 |
| 识别目标 | 四座 YAGRND 在原图格 (104,127)、(128,78)、(151,69)、(193,102)，各挂独立 Tag，Ping_Grinder1 至 4 与雷达、卫星事件并存 | 同一锚点附近放四座精炼厂，HUD 给总数 |
| 阻止回收居民 | 1、2、4 号厂有命名的平民队伍、生成和换阵营触发器，另有 Civ_CleanUp、Civ_Cheer。1号厂触发动作含设置标志、生成箱子、停用六个触发器 | 按敌方精炼厂数量差每座直接加 500。当前仅看归属，建筑被占也会减少计数。原图有被摧毁、占领或渗透事件 48，需沿每座 Tag 分别复核 |
| 主动探索 | Discover_Westwood、Change_Arnold、Stallone_Discovered、Find_Dino、Find_Hospital、Find_MachineShop | 任务脚本缺少对应地点事件和行动结果 |
| 敌我行动 | Make_Patrols、Studio_Patrol、Garrison_Hard/Medium、Bridge1 至 4 的 Broke/Fixer/Fixed、BF_Reinforcement、Control_Bus 和增援语音 | 敌设施旁生成动员兵，无对应的任务调度 |
| 任务对白 | 动作列表引用开场、伊娃发现克林特、恐龙片场、阿诺、史泰龙、尤里喊话、全厂摧毁等多条录音，同时调用交还操控与增援等通用语音 | 接了三段原声。Yuri_Taunt 是事件 32 建筑存在、参数 27，当前改在首次拆厂后。当前中文字为改编任务提示 |
| 结尾 | Win_Check 同时读本地标志 0 Base_Gone、1 Grinders_Gone。Base_Gone 检查房号 9 和 14 的建筑。随后有 Cheer 和 Mission_Over。PlayerLose 有时间事件和玩家房号 0 的全灭事件 | 单一敌方阵营，四厂归零后检查敌方建筑清空。此次把盟军失败条件改为建筑和单位均无存活者 |

验证采用 Godot 4.7.2 真实任务卡进入场景，更新了原有回归。胜利 9 项、失败 10 项通过，两个进程均退出 0。日志在 %TEMP%/it-yr-audit-win.log 和 it-yr-audit-loss.log。原版分支依据任务文件静态复核，各难度完整游玩、事件的实际播放顺序与精确延迟待对照。复刻时可先以开场机场导览、一座厂的居民路线及拆厂后的变化做首段验收。
