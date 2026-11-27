# 三关零售动作链续补：目标顺序、全局 AI、片场与撤退

原图 SHA 沿用 `SESSION_2026-11-27_THREE_MISSION_SCRIPT_COUNTS.md`。首关仅有 AI 启停覆盖；从 Steam 本机 `aimd.ini`（SHA `5df41eaec00a78d0760ef5eecdf27d65ae1cd537309c7eac973318266986f89d`）关联 165/165，其中 45 条尤里侧。复跑：`node tools/export_time_shift_global_ai.mjs '<游戏目录>' "$env:TEMP/IronTide-S01-retail/sov01.map" data/maps/time_shift_global_ai.json`。

- 首关 `05D695EC` 用 16,459 → 0,7 → 0,1，`09350DBC` 用 46,131081 → 0,4 → 0,1。`mixed_orders` 依序执行经点及防御→任意、NAPOWR→步兵→任意，类内近距选择是适配，未实现 46 高位旗标完整挑选和队伍统一择敌。`time_shift_global_ai.gd` 由接管状态启用表读取、适用难度、资金/单位阈值和真实产线限定，现只支持尤里的一部分条件及正常生产，未解释全局队伍完整动作、副队伍、招募、其它房和原版间隔；零售本图没有尤里兵营、车厂等对应产线，没擅加。专项验证真场景无生产设施不凭空生兵，未对有生产设施用例付费出兵验收。
- 好莱坞 `09164ACC → 05D9EE6C` 15 规则秒计时，`clint_report` 等其它视频完毕后播已实装 A02_P02E，回调清状态。原图动作编号 9 与 artmd 同键 A02_P02E 有证据，但代码现有片头也播此资源，字幕是回收厂内容，未确认音画身份，保留旧片头，不称完整媒体对齐。阿诺、史泰龙补 120 帧闪烁；史泰龙 `0789F21C` 目标两点取附近原标签建筑，排队攻击再走 470，未跑摧毁及抵达。`09635F3C/07A3955C/0B20458C`、`0CEBD51C/0938862C` 使用房号和条件，出售后 5/6 秒命令残部攻击移动；停止本房再生产，不把无关房资产卖掉。类型 302/303 实为 YAPOWR/YABRCK（零售类型表按注册顺序，不用显示数字键）；4 厂关闭代替原局部标志 1，主房维护24栋被毁计数。副房原版立即切 Hunt + 延迟重复命令当前只接延迟，胜利仍按房建筑清除，未验追击到交火。旧档没历史摧毁计数不追溯。
- 第七关居民保留原 German1/2 源房信息，释放后记录 Civilian House（房号12），在战斗引擎仍为中立；不是全房通用转属。混编 `06B5903C/0BA1D7AC` 补原 CSF 两句中文简报及语音→简单难度揭示→雷达→文字顺序；先前二秒并行条件及完整多轮时序仍需逐项验证。

Godot 4.7.2 `--headless --path .`，隔离 APPDATA，`.validation/three-retail-chains-20261127/`：`res://tests/time_shift.tscn -- --island-teams` 55/55（含生产守门及目标类别夹具）；`res://tests/hollywood_campaign.tscn -- --actor-report-sale` 11/11、主线100/100；`res://tests/head_games.tscn -- --combine` 11/11、`--grinder-script` 10/10，共 187 项，stderr 空。未全难度通关、独立冷读、实景或打包，未改玩家存档。继续查漏时优先处理首关全局 AI 的真实可用房与生产前置、好莱坞片场电影原声身份与各残部出击实战、《首脑游戏》逐指令 AI 与混编时序。
