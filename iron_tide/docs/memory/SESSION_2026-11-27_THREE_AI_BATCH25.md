# 第 25 批 · 苏一继承 AI 的房筛选与警犬编队

本批先做 AI。按第 24 批的正式战场口径，新增自动调度 0，三关累计 154/275（苏一继承 45/165，好莱坞本图 36/36，首脑本图 73/74）。新增 70 条的目标仍差 70。苏一剩余 120 条均逐 ID 检查了原房、初始科技和三档难度；收到正式订单、出厂和自然战役启用分别统计。地图直接创建的脚本队、AIMD 继承规则分别计数。任务触发器本批新增 0，累计 673/681 含部分接线，余 8 条待后续。

## 原版依据与正式调度

- Steam `SOV01UMD.MAP` SHA-256 `498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b`。302 个 Actions 条目共 1236 个定长动作，生产开始 3、自动编队 13、AI 条件开始/停止 74/75、队伍比例 76 均为零。165 条地图启用覆盖对应单条规则。
- 本机 Steam `gamemd.exe` SHA-256 `3e81a61775d2745d1dabe397325ef663cd994ffc194da4e998e3bf5d2d308600`。房构造在 `0x4F56F1..0x4F5710` 分别初始化生产、自动编队与 AI 条件开关。房更新在 `0x4F8587..0x4F85BD` 对电脑房按自动建造标志或 IQ/Production 阈值开启生产和自动编队。零售 rulesmd 的 [IQ] Production 为 5，Arabs 与 Nod 的地图 IQ 为 5。AIMD 选队在 `0x6F0B12..0x6F0B1A` 另查房开关 +0x1F2，关闭时跳过调用 `0x41E720` 的条件评估。规则科技与房 TechLevel 的比较在 `0x41E8D7..0x41E8ED`，超过房科技即退回。
- 找到的其他写入包括原版动作 74、玩家房交还电脑时的建基地分支，以及车辆部署后的非战役分支。其中部署分支在 `0x73987C..0x739883` 对战役模式 0 跳过，不能把地图放置或展开建造厂视作开关已开。房交还电脑的分支要求先处于玩家控制；苏一开场玩家是 Russians。未观察零售原进程完整自然游玩，不能穷尽所有间接状态来源。战役模式枚举对照 [YRpp GameMode](https://github.com/Phobos-developers/YRpp/blob/master/GeneralDefinitions.h)。
- `tools/export_time_shift_global_ai.mjs` 从零售国家和地图覆盖读取阵营、被动标志、房科技。Nod 这个房所属国家的 Side 是 GDI，且 MultiplayPassive 为真；即使 IQ 为 5 也不能拿它代替作战房。正式入口 `scripts/world/time_shift_global_ai.gd` 将“允许这个房开始新订单”与“这个房能选哪一队”分开。返城沿用已有尤里房适配；它开启原版全局 AI 的自然时点仍缺证据。盟苏房单靠出现单位、获得工厂或资金不会启动。保存中的编组仍能续训。

|苏一剩余 120 条的原房筛选结果|条数|
|---|---:|
|可匹配 Americans（科技 3）|29|
|可匹配 Arabs（科技 10）|30|
|Arabs 与 Confederation（科技 2）均可匹配|18|
|有符合国家条件的作战房，但初始科技不足|36|
|在现有敌方、非被动、有 IQ 的房中无匹配国家|7|

完整 ID、原 TeamType、TaskForce、ScriptType、科技和候选房保存在 [三关逐 ID 台账](THREE_MISSION_AI_COVERAGE.tsv)。77 条通过这层静态筛选，尚未发现这些房在原关启动全局选队的依据。房、队伍编制、资金、工厂、剧本条件仍分别判断。

## 隔离战场实测

六条原编制现复用既有零售单位映射。盟军三条为 `0CDF8EDC-G`、`0C1246FC-G`、`0A44F2CC-G`（ADOG → DOG），苏军三条为 `0A31295C-G`、`0C1245AC-G`、`0A44F17C-G`（DOG → SOV_DOG）。六条均验证主编组产品；只对 `0CDF8EDC-G` 验证全队出厂和编组命令。

从苏军战役菜单出击。测试在返城场景补入 Americans 兵营、电厂、作战实验室、产品和测试资金。正常时钟到期，即使有工厂和足额资金也没有产生盟军订单。单独调用正式房选队入口以模拟该房获准启动，确认普通难度下 399 元不足，400 元时选中原 ID，通过实际兵营生产两只本房警犬，总支出 400，齐员后收到原驻防脚本。第一次出厂后种档；独立进程恢复时已有一只、欠一只，余额为 199.999999999998（单价 200，分帧浮点扣款）。续训第二只后队伍完成、无重复扣款和重发。没有向正式关卡添加这三座建筑，未测该队自然出厂或实际到岗接敌。

## 复跑与交付

以 `iron_tide/` 为 cwd。运行 `node tools/export_time_shift_global_ai.mjs <Steam游戏根目录> .validation/three-trigger-ai-19/sov01umd.map data/maps/time_shift_global_ai.json`。再运行 `node tools/export_three_mission_ai_coverage.mjs docs/memory/THREE_MISSION_AI_COVERAGE.tsv .validation/three-trigger-ai-19/sov01umd.map .validation/three-trigger-ai-19/all02umd.map .validation/three-trigger-ai-19/sov07umd.map`。两次导出均校验零售地图 SHA。

Godot 4.7.2 隐藏无头，使用独立 APPDATA/LOCALAPPDATA，种档与对应冷读共用测试档。命令格式为 `Godot --headless --path . res://tests/<scene>.tscn -- --campaign-test-no-autosave --<case>`。日志位于 `.validation/three-trigger-ai-25/`。

|场景|用例|通过断言|
|---|---|---:|
|time_shift|retail-inherited-houses|136|
|time_shift|cold-dog-orders|4|
|time_shift|retail-room-economy|17|
|time_shift|cold-room-economy|3|
|time_shift|island-teams|62|
|head_games|retail-production-houses|80|

六组共 302 条，exit 0，stderr 均为空。《首脑游戏》`08CF30FC` 原 TaskForce `043F4BCC` 只有名称与 Group，调度表排除该空编组。未修改玩家存档，未做整关自然通关、窗口实景、打包或发布。
