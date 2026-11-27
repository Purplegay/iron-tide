# 盟军终关首批敌军与车厂 AI

承接 `SESSION_2026-11-26_ALLIED_PORT_GAP_AUDIT.md`、读取 `SESSION_2026-11-25_SOV07_RETAIL_AI_ORDERS.md` 和实际 ALL07SMD 审计索引。预览原先只装配预置守军，没有执行前期登陆和战术造兵。零售 `0960D93C` 在苏军兵营条件、未有苏军战车工厂、相关局部变量和延时成立后调用 `08D5D5FC`：1 YHVR 载 5 INIT。后续 `0464C5FC / 0B7AE1EC / 0B2E9EDC` 分别对应另外三队；首批两个零售外边界入口 TA/TC 需投影到可玩水域。106/107 作为本批登陆适配点，用真实两栖通行与卸载。未接零售分队局部变量/回收链全语义、第五批或战车工厂触发链，前四批当前以 75/75/90/90 模拟秒、兵营存在而苏军车厂不存在驱动，不宣称零售完整时序。

`tools/export_allied_finale_ai.mjs` 从原图索引导出四队与 7 个启用的本图 AI 条件，保留队列、脚本、数量、难度和初始权重。注意 AITrigger 的房模板和 TeamType 自身的 House 有出入，如 `08DA8EDC` 前者 YuriCountry，后者 Yuri2Country。适配按 AITrigger 所属原图房选择活着的车厂，当前共享 enemy 经济和通用科技检查仍是近似。普通/困难的一座苏军电厂触发例 `08DA8EDC` 两艘 DISK，4 辆灰熊触发例 `0E6056AC` 六辆 LTNK；本批按数量条件/原图初始权重选队，队伍造齐后带行动 3 航点和近似攻击目标出击。复杂 ScriptType 动作、成功/失败权重回写、条件语义全复刻及房经济、守军再部署均未全部移植，不把剩余 77 条当已完成。

`allied_finale_ai.gd` 实现。`allied_finale.gd` 接模拟步与预置设施已完工状态，`battle.gd` 出厂回调绑定原图房/集结队，`game_data.gd` 增加原图尤里车厂 DISK 目录，`battle_snapshot.gd` 为已存车厂补该产品。状态队列和载员由现有快照承载，没改玩家存档。关卡仍是试玩。

Godot 4.7.2 隐藏无头、隔离 APPDATA：`res://tests/allied_finale_playable.tscn -- --enemy-ai` 23/23，真菜单进入、占领火地岛后用夹具放兵营、加速队列和计时；艇自然移动、真实卸载，登陆队实际命中建造场；车厂真实扣费、飞碟和狂风出厂及下达出击。未测飞碟/狂风整队自然抵达交火。主回归 41/41，雷达后独立进程冷读 4/4；全部 exit0、stderr 空。证据 `.validation/finale-ai/{main,test,cold}.{out,err}`。未专测艇航行/生产中间档、所有难度、全波、长局、有头及发行。