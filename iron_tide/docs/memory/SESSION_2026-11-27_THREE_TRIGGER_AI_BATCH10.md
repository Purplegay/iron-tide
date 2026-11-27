# 第10批：《首脑游戏》平民路线、攻势和防守 AI

接第9批续做。本批 30 条任务驱动（部分接线）：9 路居民及9条源房被毁停用、1条启用、8条部署/攻势、3条失建造场超武停用。AI 12 条既有候选补迁巡逻脚本。累计任务201/681：17专项、183部分、1缺专用链、480待核验（苏一175、好莱坞226、首脑游戏79）。AI 仍150/275进候选或评估，124未进、1空编组；逐ID生产证据仍10。两项台账外层待办合计604，不含已登记条目的补齐和验收。

零售 Steam `SOV07UMD` SHA `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`。`node tools/export_head_games_drivers.mjs "$env:TEMP/IronTide-S07-retail/sov07.map"` 生成 `data/maps/head_games_drivers.json`；导出两张原台账按前轮命令。`head_games_orders.gd::tick` 读取路线启用、停用及事件51周期，重复间隔按公开参考随机30–90秒；沿用项目首轮60秒、既有回收路线与势力适配。N房消失关闭两条路线；不强制删除已出发居民。`head_games.gd::attackers` 读取展开后45/75/90秒、后续普255/难165秒及未展开120秒；沿用原有运行队伍与玩家基地识别，不计其它外交动作。`retail_yard_disabled` 读取三房停用列表，映射现有超武剧情计划。

12 条 AI 在 `head_games_orders.gd::advance_production/start_defense/advance_defender` 以原 AI ID 在付费编组结束后发路令，支持原路线 3、限时警戒 5、跳回 6；动作49评价未实现，航点仍投影到可走格，编队同步、全部自然出厂、抵达和交火未逐条验。读档存储单位路线状态与警戒期限。

验证 Godot4.7.2 隐藏无头，真实战役菜单，隔离用户目录 `.validation/three-trigger-ai-10/`。`qualify` 59、`qualify-cold` 4、`orders-final` 19、`main-final` 52，共134，均 exit0 且 stderr空。运动逐ID用夹具摆位至站点、推进等待；冷读代表队确认警戒未到不动、到点续走。主线与路线专项不等于自然全难度验收。没动玩家档、地图资源或发布包。
