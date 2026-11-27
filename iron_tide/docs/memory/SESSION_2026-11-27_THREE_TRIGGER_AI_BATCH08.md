# 第8批：供电争夺触发链与好莱坞队伍路线

接第7批。沿用 Steam `SOV01UMD` / `ALL02UMD` 的 SHA 与提取路径；用 `export_time_shift_fleet.mjs` 从原 `Triggers/Events/Actions` 提取，两个总表仍通过三图 SHA 门禁。

- 任务：新增登记及接入 **8 条**。`094A4ADC → 079DB44C → 043DF33C → 0B454BBC → 06A6629C → 06A6646C`，两条并行 `08FC09DC/08FC0BAC`。正式 `time_shift_events.gd::power_contest` 读零售后继、延时、难度和雷达航点；供电阶段两个电台、四路船队，简单止于第一组夺厂，普通及难可继续第二组；两次突击各在派出后15秒标原 SC 航点496，不跟随艇。前六条是既有波次/电台表驱动；两条是本轮新增实际雷达动作。时钟仍以现有供电阶段为零点，沿用运输路径适配；原消息/揭雾/旗标和300秒循环 `06A6663C` 未全接，未做冷读。8条均记部分；累计 **117/681，剩564**；17专项、99部分、1缺专用链。
- AI：正式 `hollywood_bases.gd::deploy_team_member` 按零售 `ScriptTypes` 区分 3（移动）、16（巡逻/本项目攻移）并依序排航点，再接原有兜底攻击目标。覆盖 **12 条既有候选**：`0C6C0EDC/0C6C0D8C/05D5239C/0BC3AC3C/0BA1762C/0F7CB45C/09AF5C3C/09AF5AEC/09AF599C/09AF584C/09AF56FC/09AF55AC`。正式选择器也纠正 `07F2F2DC` 条件4读取玩家钱包而非该 AI 的钱包，本轮未独立触发这条。原航点队列逐ID实测，但尾部择敌、集合条件、全程抵达和交火不等价。候选累计仍 **150/275**；逐ID生产实测仍 **10**。新增长期逐ID路线证据12，不与生产数混算。

验证 Godot 4.7.2 隐藏无头隔离 APPDATA/LOCALAPPDATA，`.validation/three-trigger-ai-08`：`time_shift.tscn -- --power-raid-chain` 普通15、简单15；`--raid-orders` 23（实战入口与上岸接敌的专项，独立退出码未留）；`hollywood_campaign.tscn -- --retail-movement-ai` 19、`--retail-ai` 14、`--retail-guard-ai` 45。合计 **131** 通过断言、采纳组 stderr 空，除 `--raid-orders` 其余五组记录 exit0。供电专项从实际出击装配，用夹具推进供电时钟；路线在实际地图复用单辆坦克，下令及顺序测试，不是12队生产走完全程。未改玩家档、未打包、未跑三难度自然通关。本批没动地图、桥坡、美术；《首脑游戏》11处纹理告警和逐端桥下仍待补。
