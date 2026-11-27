# 第14批：好莱坞居民源楼、维修桥、任务报点与 AI 集结

接第13批。本轮61条新触发部分接线、22条既有AI补编队动作；[本批完整逐ID清单](THREE_TRIGGER_AI_BATCH14_IDS.md)。任务累计407/681（17专项、389部分、1缺专用链），待274（苏一157、好莱坞103、首脑14）。AI仍150/275进入调度或评估，124未进现有分支、1空编组；逐ID生产证据仍10。外层待办398，不含复刻与验收缺口。

- 好莱坞原图 SHA `168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303`。`tools/export_hollywood_drivers.mjs` 从 Structures/Tags/CellTags、Events/Actions、Waypoint/Teams 提取后继续生成两表。21条源楼被毁触发按原结构类型和地基锁定实际建筑，只停止该路线后续生成；21条初期居民的原30秒、类型与后继读表，现仍以克林特访问作为启动适配，使用既有排队与可走格，不声称完整旗标等价。7条雷达链：雷达恢复重新开启原120秒文字和四地点，断电/失雷达取消待发，不标已停运厂。
- 12条桥触发：四处原CellTag的断面、断修启停和60秒后工程师伞降读表；`hollywood_bridge_fixers.gd` 保留原项目小屋交互和已派机独立飞行，不修改桥贴图或几何。实际修复后清作业并允许下次派遣。
- 22条已有本图 AI：完整出厂后按脚本顺序执行3/16/53/54，抵达或120秒容错后推进，继续走既有按类别攻击；使用队伍首员附近可走点实现53/54集结，是位置适配，不宣称原威胁算法、动作49或者穿插所有指令等价；缺厂残队沿用现行回退。状态与队员引用进存档，首次冷读有到达阶段测试，未逐队自然出厂、抵达和交火。

证据 `.validation/three-trigger-ai-14`：`focus-final`120、`bridge-final`18、`paid-final`15、`main-final`102、`cold-final`3，共258，全部独立无头 exit0、stderr空；战场专项逐ID绑楼、造伤害、摆位并推进时钟，生产代表测试走付费出厂；不是自然三难度逐队全程。未改玩家档、地图资产或发行包。重建：`node tools/export_hollywood_drivers.mjs "$env:TEMP/it-hollywood-retail/all02umd.map.map"`，后用之前三图参数重建 `export_three_mission_triggers.mjs`、`export_three_mission_ai_coverage.mjs`。
