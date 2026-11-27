# 三关触发逐条对照第4批：零售计时驱动

按第3批零售提取路径和 SHA。用户要求每批播报已做及剩余，已同步仓库和安装版移植技能。起点 60/681，待核验621；本批新增核验4（新补接1、复验既有3），累计64，待核验617；总表12已接并专项验证、51部分、1缺专用链。6条既有计时改为部分表驱动，不另扣剩余。

`tools/export_campaign_timer_drivers.mjs` 校验三个项目内沿用证据中的 SOV01/ALL02 原图 SHA，生成 `data/maps/campaign_timer_drivers.json`（7个已支持事件13/51的时长及动作53后继）。运行入口是正式苏一与好莱坞战场，`time_shift.gd` 使用 `0B554AFC/0B557E6C` 的表内随机范围和彼此启用，新增 `043E763C` 充能阶段80秒一次性防守文字；好莱坞 `hollywood_mission.gd` 读取 `094D906C/04627BCC` 和 `0618F5CC/07AC738C` 的等待与后继。仍由每关适配器判定阶段/设施，不是通用触发解释器。已有旧档保留先前的倒计时；未向已在侏罗纪而无提醒字段的旧档补播。未改第七关运行，未碰平民欢呼专用缺项。

Godot 4.7.2 无头隔离 APPDATA，`.validation/three-trigger-audit-04/`：`time_shift.tscn -- --recharge-reminder` 41；`hollywood_campaign.tscn -- --fortress-chain` 13、`--grinder-layout` 16、`--depot-taunt` 8、`--dinosaur` 20、`--retail-ai` 14，共112，stderr 空。新增分支通过正式战场入口并以夹具推进计时。未冷读本批新状态、无自然整关或全难度、未改玩家档与打包。重建覆盖表沿用前轮命令；驱动表重建 `node tools/export_campaign_timer_drivers.mjs "$env:TEMP/IronTide-S01-retail/sov01.map" "$env:TEMP/it-hollywood-retail/all02umd.map.map"`。
