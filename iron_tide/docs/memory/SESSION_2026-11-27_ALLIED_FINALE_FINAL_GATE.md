# 《脑死》最终验收门槛复核

承接 [最后五条任务](SESSION_2026-11-27_ALLIED_FINALE_LAST_FIVE.md)。结论：**源码的可玩流程及本轮无头回归通过；不签发零售整关复刻或发行验收。** 本轮只增加验收场景，不改战场规则、地图资源或玩家存档。

## 零售依据及双表

Steam `mapsmd03.mix/ALL07SMD.MAP` 实际解包散列 `0ec687c320382e4c02cf66eec0153b713e56c4449fab7d29b5a19b61bf10e4f3`；SNOW，LocalSize `15,13,100,110`。用 `.validation/allied-ends-20261126/audit/yr_all07smd_index.json` 重导本关任务与 AI，正式数据与重导逐对象一致，两份台账的零售字段逐 ID 零差异，任务外链 0。见本轮 `retail-audit.txt`。

| 类别 | 零售数 | 本轮新增／累计接入 | 本轮与既有实测分开计数 | 未完成范围 |
|---|---:|---|---|---|
| [任务](ALL07SMD_SCRIPT_RECHECK.tsv) | 88 | 0／88（4 条关闭、1 条空动作） | 88/88 逐 ID 数据核验；本轮重跑胜负链、补援、清剿、末五条等用例，不把 751 条断言冒充逐任务通过 | 不是所有动作、难度、登陆循环和异常线路均已逐 ID 玩家实测 |
| [地图 AI](ALL07SMD_AI_RECHECK.tsv) | 84 | 0／84 | 84/84 逐 ID 数据核验；实战重跑主房、第二房、第三房的若干出兵、同房科技与资金、集结/接令或特定战斗样本 | 未逐队验到抵达及交火，复杂 ScriptType、完整逐房经济与外交仍有适配 |
| 全局 AIMD | 不继承 | 0 | 原图 `IgnoreGlobalAITriggers=yes` | `AITriggerTypesEnable` 是启停覆盖，不算额外地图 AI；脚本登陆也不计入 |

地形沿用已有零售格和坡型审计（22000 格、1539 坡格），本轮复核审计索引：无桥覆层、无任务桥建筑，不适用逐桥运行验收。既有 PNG 扫描 `(152,48)/(153,48)` 仍待同机位实景复核；不把原审计当本轮实际渲染或全部覆层、建筑落点复验。

## 本轮证据

Godot 4.7.2，`Start-Process -WindowStyle Hidden`，每个用例独立隔离 APPDATA；冷读使用本轮实存快档或已有隔离副本。有效证据 `.validation/finale-final-gate/`；最终 20 组、751/751 断言，stderr 均空。`cg.out/.err` 为最初保护变量未设置的试跑，不计。没有覆盖玩家目录。

- `res://tests/allied_finale_playable.tscn`：主线 91，`-- --final-return` 93，`-- --lose-all` 23，`-- --lose-tierra` 24。新增真实结算点击返回战役菜单。失败用夹具损失血量，确认 `08ED7A3C` 全灭和 `0A57F46C→0A57B28C` 火地岛失守延时各提交一次失败；主线含真实工程师命令、媒体和结算，但以夹具推进时间和清敌，不是自然游玩。
- 同场景 `-- --last-five` 39、`-- --closing` 37、`-- --branches` 71、`-- --enemy-ai` 43、`-- --third-ai` 52、`-- --third-barracks` 50、`-- --replacement` 50、`-- --house-colors` 44、`-- --parallel-construction` 46、`-- --opening-snow-art` 18。
- 独立进程：`-- --cold` 7、`-- --cold-dual` 5、`-- --cold-house-colors` 12、`-- --slot4-armor` 8、`-- --slot5-cleanup` 8。雷达快档、双基地并行施工、房色恢复、旧档装甲艇卸载返航接续、最后潜艇清剿分别验证；上次独立雷达冷读夹杂的其它关编译错误本轮无重现。未覆盖全部断点（例如片头与雷达间隙、飞行中、地图 AI 队列中途）。
- `res://tests/cg_collection.tscn -- --allied-finale-replay` 30/30。设置 `IRON_TIDE_CG_TEST_PROFILE` 为隔离目录下 `Godot/app_userdata/Iron Tide RTS`（斜杠路径）。三个终关卡均验未收录雪花、已收录同名节选、点击对应正片、双向拖动与返回；雷达段验续音留帧、中文字幕存在及拖回画音同步。未有头核验节选取帧是否清晰、有辨识度，也未逐句听读。
- 重导复跑：`node tools/export_allied_script_slice.mjs .validation/allied-ends-20261126/audit <任务输出>`，仅比较 `yr_all07smd`；`node tools/export_allied_finale_ai.mjs .validation/allied-ends-20261126/audit/yr_all07smd_index.json <AI 输出>`。本轮未重烘、未打包。

## 剩余签发门槛

需要用户同意开启窗口后做自然新开局通关、实际画面/音轨/字幕同机位验收，另补足逐队和缺失断点的证据。不能用本轮的夹具结算、冷读旧档或 88/84 接入覆盖，替代原版整关通过。源码可以从「战役 → 盟军战役 → 脑死 → 原版配置 → 出击」进入。
