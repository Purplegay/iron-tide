# 美国首关防空 AI 与生产触发器

Iron Tide 0.32，Godot 4.7.2。战役菜单出击进入 ALL01UMD 的正式 Battle。本批按原图 ID 去重。

| 表 | 本批新增 | 累计 | 剩余 |
|---|---:|---:|---:|
| 地图 AI | 3 | 4/165 | 161 |
| 任务触发器 | 1 | 120/334 | 214 |

Steam 地图 SHA-256 为 `dee38769f2247a85908705486c175ef14a4cf90437899defe7c8b4c0d1c51fb0`，全局 AIMD 为 `5df41eaec00a78d0760ef5eecdf27d65ae1cd537309c7eac973318266986f89d`。[地图 AI 逐 ID 表](ALL01UMD_GLOBAL_AI_RECHECK.tsv)与[首关任务逐 ID 表](ALL01UMD_SCRIPT_RECHECK.tsv)均已核对正式运行清单。

| 原图记录 | 条件与正式战场动作 |
|---|---|
| 0ca2a04c-g | 美国玩家房拥有至少 6 架 ORCA 入侵者 |
| 0ca2b06c-g | 美国玩家房拥有至少 5 架 BEAG 黑鹰 |
| 0ca2fedc-g | 美国玩家房拥有至少 2 艘 ZEP 基洛夫 |
| 0b8a090c Build_Dom | 从换场交接启用，按原图事件 13 等待 1 游戏秒，动作 3 对房号 7 Confederation 开启生产。由普通建筑更新完成控制器施工，动作 53 接通 0bd650ac New_Dom_Up。 |

三种威胁均限普通和困难，初始选队权重各为 500。矿车和防空队按满足条件的候选权重选取。防空队使用 06BC625C-G；本房 NAHAND、NARADR 满足 FLAKT 的原版生产前置，本房 NAFLAK 是集合目标。普通兵营按进度支付六人费用，三条规则共用同一队种的两队上限。成员按 58,131139 靠近本房防空炮，执行 21,0 分散，再以 11,11 进入战役区域警戒，自动对空开火。出击入口为 allied_first.gd，选择与生产在 allied_first_ai.gd、allied_first_flak.gd，普通建筑队列负责取消和退款。修复前的第一组夹具因缺苏联雷达被正式产线拒绝；现已验证本房无雷达、外房雷达、外房兵营、友军飞机、阈值差一架和简单难度。

原图初始场内 Confederation 只有核电站和控制器，正向回归在正式地图用建筑接口补本房兵营、雷达和防空炮，并按门槛摆放玩家飞机。六名步兵真实出厂、行走并击伤空中目标。为确认伤害来源，交火专项暂停其余部队和建筑，测试目标飞机固定在警戒区内。原图不会因本次接入自动增加任何设施。上游 Sell_Psychic 仍由换场交接代理，控制器施工时间与费用沿用关卡适配，后续计时在进入过去时代主线后推进。分散位置沿用战场可通行格，敌方资金目前仍为共用账户。未复刻完整全局 AI 权重随战果变化，也未做人手整关游玩。

## 无头回归

用隔离 APPDATA 运行 Godot 的 `--headless --path . res://tests/allied_first_playable.tscn -- --new-sequence-mainline`。分别追加 `--flak-ORCA --save-flak --flak-limit`、`--flak-BEAG --hard`、`--flak-ZEP`、`--flak-ZEP --easy`。独立进程以同一隔离目录用 `--cold-flak` 读取第三人已付费断点，核对不重复建队以及后续四人、分散与交火。主线覆盖 `--global-ai --late-dominator --field-audit --retail-transition`；换场与场外转属分别使用 `--cold-crossing --after-midpoint`、`--cold-offmap-yard`。原表解释器运行 `res://tests/allied_retail_script.tscn -- --first-only`。日志位于 `.validation/allied01-air-defense/`。

| 场景 | 实测通过 | 日志 |
|---|---:|---|
| 入侵者，跨规则上限和失厂 | 71/71 | of.out |
| 黑鹰，困难 | 66/66 | bf.out |
| 基洛夫，普通 | 66/66 | zf.out |
| 基洛夫，简单禁用 | 60/60 | ef.out |
| 正式主线、原矿车、驻军、全图与晚期生产关闭 | 96/96 | mf.out |
| 防空队在产冷读 | 9/9 | cf.out |
| 穿越中点独立冷读 | 9/9 | postswap.out |
| 场外转属后独立冷读 | 3/3 | yard.out |
| 原表解释器 | 113/113 | raw.out |

以上日志标准错误均为空。本轮截图 0 张。
