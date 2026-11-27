# 第12批：超武、开场队伍与《时空转移》电台

接第11批。新接43条任务触发（均部分），29条既有AI规则条件表驱动；[本轮全部逐 ID 清单](THREE_TRIGGER_AI_BATCH12_IDS.md)。任务累计284/681（17专项、266部分、1缺专用链），待397：苏一157、好莱坞226、首脑14。AI 150/275进入调度或评估，124未进入、1空编组，逐ID生产证据10。两项外层待办合计521，不代表全部等价还差521。

- SOV07 15条超武：铁幕或核弹井落成启用、两翼解放状态挑选尤里对白、苏军核弹井/盟军天气控制器/尤里心灵控制器按零售难度与延时，心控器实际落成才启动基因突变器倒计时。`head_games.gd` / `head_games_sites.gd` 保留任务建筑落点与旧档计时回退。
- SOV07 10条开场：三房驻军、四条难度守军、反应炉驻军及两批苏军入场。`head_games.gd::setup/arrive/attackers`、`head_games_orders.gd::prepare` 用正式表；采用现有就近驻军与入口投影，不等价于每个 TeamType 全脚本。第二批开场延时3秒，独立冷读检查不提前、不漏派、不重派。
- SOV01 18条媒体：恶魔岛及海战电台、登陆电台和镜头、鲍里斯下船与重逢、时光机/守卫目标提示、医院和维修厂双房分支。`time_shift.gd::scenario_film` 与 `time_shift_events.gd::media_tick`，读取零售后继、延时及地标；部分原上游用片尾、实际离船或可见性替代，不声称原引擎整段精确。
- SOV07 29条既有 AI 玩家兵力规则：`head_games_orders.gd::dispatch/force_allowed` 读取原始 Entity 与六类比较码，仍从玩家存活对象计数；未改变权重、难度、工厂、生产账号，也未逐条验自然生产或交火。

零售 SHA 同此前，先 `node tools/export_head_games_drivers.mjs "$env:TEMP/IronTide-S07-retail/sov07.map"` 与 `node tools/export_time_shift_fleet.mjs "$env:TEMP/IronTide-S01-retail/sov01.map"`，再重建两表。证据 `.validation/three-trigger-ai-12/`，Godot4.7.2 隐藏无头、隔离APPDATA。采用 ai33、sup13、nuke2 19、sites309、orders19、landing52、media-chain10、s01main59、s01media50、col-write2 2、col-cold2 5；共571项通过断言，无失败断言或stderr，两处开场援军最终进程显式 exit0。早期存档测试放在雷达通讯之后已错过3秒，该失败轮未计；挪到实际出击首帧重测通过。用了菜单、真实实体、原声播放器、夹具推进规则时钟和独立进程冷读，未自然覆盖全部难度、未有头、未改玩家档或打包。
