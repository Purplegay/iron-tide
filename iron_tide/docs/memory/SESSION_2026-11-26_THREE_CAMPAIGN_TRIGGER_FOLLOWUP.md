# 三关零售触发补接与复查（二轮）

沿用零售 `mapsmd03.mix` 提取件与原图索引。再次校验地图 SHA-256：SOV01UMD `498b989a4b6f579dee0904a77f1fabf982c14786db21a46c41900fc8344ec72b`，ALL02UMD `168ed42024991b6c2af4de0e5a667e9c2bf15767741efe99dac975721460b303`，SOV07UMD `eacf89952cb6e8eacd762f97895a062e0b6bfa16c8f916b901c1e667def266d4`。

|关|零售依据与玩家可见结果|运行入口与限制|
|---|---|---|
|《时空转移》|`0959CAFC/0959C92C` → `082C44AC/082C467C`：犀牛艇 9、动员兵艇 3 规则秒补派；`0B603E5C/0B60744C` 对卸载后通知及停用。保留 4 辆犀牛、12 名动员兵的两套编组。|`time_shift.gd` 对新开局登记这两艘任务艇，未卸载即损失才补；重派艇清空载荷后关闭且通知。沿用当前滩头入口近似；未移植登陆艇原图多路点预航和返航，以及人员全灭、首波坦克全灭等独立触发；旧档缺登记不猜测历史艇。|
|好莱坞|`Bridge1..4_Broke / Fixer_Team / Fixed`。四处 CellTag `(112,155)/(112,150)/(130,61)/(131,56)`，掉落航点 XB/XC/XE/XF 与小屋 156–159，分别等 60 规则秒，派一名工程师。其余两座没有这四条触发链。|`hollywood_bridge_fixers.gd` 替换通用 20 秒派工；以桥段损坏状态计时，以指定小屋为维修目标，修复清除任务；每次破损有序号防止上一轮空投错认。复用现有伞兵飞机/降落表现近似零售 Droppod；来自原图的运输起点 XA/XD 和实机自然飞抵均未验。通用断桥、修复、桥面路径逻辑不变。|
|《首脑游戏》|`0CBF5A9C` 西南回收厂遭袭或 `0CBEE55C` 发现，两者共用一次守军触发；`0AA45A2C/0AA466CC` 动作 108 类型 0，在 BU=72、BV=73 放资金箱。尽管全局规则为 5000，本关 `[CrateRules]` 覆盖 `SoloCrateMoney=2500`。|`building.gd` 实际正伤害、`head_games.gd` 与 `battle.gd` 接一次守军和可见时画箱，地面单位进入格子一次领取；沿用项目既有回收厂位置及守军表现，居民房转属、欢呼、原编组逐队解散尚未接。旧档已拆不追补。|

三张零售地图的 `[General]` 均指定 `SpyMoneyStealPercent=0.05`，`allied_abilities.gd` 限这三关战役启用 5%；第七关专项走正式渗透结算扣目标房，第 1 关与好莱坞未各自进矿场验该比率。无改遭遇战配置。

## 实测

Godot 4.7.2，隐藏无头、隔离 APPDATA，从正式战役任务卡进入：`res://tests/time_shift.tscn -- --landing-backup` 8/8、主线 51/51；`res://tests/hollywood_campaign.tscn -- --bridge-fixers` 18/18、主线 94/94；`res://tests/head_games.tscn -- --grinder-script` 8/8、主线 49/49。各 stderr 空，共 228 项通过。日志 `%TEMP%/IT-three-recheck-6b7aec9aaf374fe383c6df1e1e3903ce` 的 `s01`、`s01-main`、`holly`、`holly-main`、`s07-spy`、`s07-main`。早期全局五千样本不算最终。

夹具注入伤害、推进时钟并摆位；执行真正的运输卸载、伞兵落地和工程师修桥动作。未自然计时全程航行、未做新增触发器等待中的独立进程冷读、未做全难度、有头画面或逐条原版触发运行，不改玩家档、不打包。
