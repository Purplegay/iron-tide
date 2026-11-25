# 模型、皮肤与表现

## v0.31.40 百合子的十杀配乐

玩家的百合子在同一战场亲自击杀 10 个敌方计分单位后，平静时循环 James Hannigan 的《YurikoTensionb》。队友和心控守卫的击杀、建筑、临时单位及阵营淘汰清场均不计入。未满十杀沿用原配乐。击杀计数、解锁和最近交火时间随本场存档恢复，新战场重新计数。

这项规则调整了十杀后阵营均势曲的持续时间。玩家一方交火时播放本局抽中的战斗曲，连续 20 秒模拟时间没有交火后转入《YurikoTensionb》。如仍在开场探索阶段，十杀可直接替换探索曲。百合子出场主题、起义、优势、劣势、双方超武和胜利结算均有优先权。插曲播完按当时战况选曲。

Godot 4.7.2 后台音乐专项 167/167，百合子联动 152/152。验证了九杀存读档后普攻完成十杀、交叉超武播完、混音器有输出、真实曲尾循环、交火打断、停战恢复和十杀后的存读档。项目 MP3 与本机同名 CloudMusic 原曲的 SHA-256 一致。实机音量与切歌听感待试听。[音乐专项报告](../../../.validation/yuriko-tension-1795539512073/music_regression/result.json) · [百合子联动日志](../../../.validation/yuriko-tension-1795539512073/yuriko_score_regression/console.log)

## v0.31.38 胜利弹窗与配乐清单核查

2026-11-25 用隔离存档从盟军、苏军两场遭遇战分别触发胜利。两场都显示本阵营的胜利海报，点「查看结算」进入结算页。两张 354×512 的 PNG 逐像素对应《红色警戒 3》SDK 的 TacticalEndGameDialog 原图：盟军为 3.tga，苏军为 5.tga。弹窗布局和按钮由 Iron Tide 绘制。[两阵营弹窗检查](../../../.validation/camp-map-victory-audit-1795536571526/victory_art/console.log)

远征营地使用完整《Grinder 2》，进入地图先播探索曲，普通波次出现时继续探索，玩家首次与敌方交火时转入阵营战斗曲。十首探索录音、营地曲、两个版本的《Up Yours》及两首主动超武曲，共 15 个文件逐个与本机 CloudMusic 源 MP3 比对，SHA-256 全部相同。玩家和敌方的核弹均按 v0.31.37 的超武规则处理。音乐专项 146/146，百合子、远征与配乐联动 123/123；后台验证，未做扬声器试听。[音乐报告](../../../.validation/camp-map-victory-audit-1795536571526/music_regression/result.json) · [远征与战斗联动](../../../.validation/camp-map-victory-audit-1795536571526/yuriko_score_regression/console.log)

## v0.31.38 苏军 Combat 1 的凯旋曲

《Red Rock for Mother Russia》与《Soviet Combat 1 - Triumphal》固定配对。这条规则取代 v0.31.36 对《Red Rock》优势段的 2:23 切点。均势和劣势沿用《Red Rock》的原有片段，战中占优时从独立凯旋曲的开头播放。优势中读档或超武插曲结束也回到这首凯旋曲。直接获胜时同样选这首；如已在播放则连续播完。苏军另一首《Battleground of the Bear》占优时仍从原曲 2:23 播放。

Godot 4.7.2 后台音乐专项 146/146。验证了真实对局拆掉五座敌方电厂后转入凯旋、优势存档恢复、超武插曲返回、直接获胜和结算时播放位置连续。检查了实际 MP3 资源与播放位置，扬声器听感待试听。[音乐专项报告](../../../.validation/red-rock-triumph-1795536400477/result.json)

## v0.31.37 超级武器插曲

2026-11-25 起按成功发动的时刻和发射方选曲。玩家使用核弹、闪电风暴、铁幕或超时空传送时，盟军播放 Tim Wynn 的《American Cowboys》，苏军播放 Frank Klepacki 的《The Red Menace》。玩家缴获异阵营发射设施后仍听自己阵营的曲目。敌方发动时播放玩家阵营的《Up Yours》，替代原先在己方发射核弹或敌方核弹落在玩家资产附近时播放的规则。

落空也触发，命中和后续伤害不会重播。友方 AI 的发射、尚未充能和选点失败均不触发。侦察机、空降和力场护盾沿用支援能力规则。既有车队英雄奖励核弹也在成功创建发射记录时按发射方选曲。

每首超武插曲完整播一次，期间战况继续更新。交错发动时先播完当前插曲，对方插曲等待一次，同类连续事件合并。最后回到本局已选战斗曲的当前战况段。离场、胜负结算结束战斗插曲。

Godot 4.7.2 后台隔离存档验证通过。音乐专项 141/141，百合子与配乐联动 120/120。覆盖四种正式超武、玩家缴获发射井、敌方空放、落点不重播、交错发动及原曲播放结束事件接回劣势或优势段。播放结束测试跳到曲尾后等待真实播放器信号，扬声器听感未验。[音乐专项](../../../.validation/superweapon-score-1795536174594/music_regression/result.json) · [实战联动](../../../.validation/superweapon-score-1795536174594/yuriko_score_regression/console.log)

## v0.31.36 战斗音乐

盟军每局等概率抽《Rock and Awe》或《Bring it!》，苏军等概率抽《Red Rock for Mother Russia》或《Battleground of the Bear》。地图探索结束、玩家首次交火时，播放所抽曲目的 0:00–1:17。劣势段为 1:18–2:22，优势段为 2:23–4:08。每段单独循环，重播回到当前段首。读档恢复选曲、战况及判定用的时间窗口，音乐从段首播放。

战况按模拟时间统计玩家亲自造成或承受的敌对击杀。最近 20 秒损失至少 3 个计分单位、击杀数不超过损失的一半，或最近 120 秒损失至少 5 座关键建筑且多于拆掉的敌方关键建筑，进入劣势。最近 120 秒拆掉至少 5 座敌方关键建筑、当前战况已持续至少 20 秒且符合 120 秒重入间隔时，进入优势。优势最多保持 120 秒，新的劣势可提前中断。防御建筑、墙、平民建筑及阵营淘汰清场不计。

本规则取代常规交火固定播放 Combat 1、占优改播独立 Triumphal 的旧做法。RED ALERT 或淘汰敌方阵营触发的 Uprising 在已交火的均势下作一次插曲，战况转劣或占优时让位。百合子、核弹插曲结束后回到当时的战况，正式胜利结算仍有独立凯旋曲。

2026-11-24 使用 Godot 4.7.2 后台和隔离存档运行。音乐专项 120/120，覆盖两个阵营的四首原曲、十二个段落的进入和循环、静音恢复、交火、建筑攻守和读档。百合子与配乐联动回归 118/118。已核对混音总线有输出，淡化听感待试听。[音乐专项报告](../../../.validation/combat-segments-1795535691303/music_regression/result.json) · [百合子与配乐回归](../../../.validation/combat-segments-1795535691303/yuriko_score_regression/console.log)

## 战斗界面与部队选择

| 操作 | 已有实现与验证 |
| --- | --- |
| 看雷达、切生产或编组 | 雷达在右上。选中单位打开编组，点生产页签切回目录，再点该页签或折叠可返回。混编按类型，同型小队显示单车。第 19 关 66 人、8 组的重复框选验证了头像复用；首次框选和整局帧率另看性能记录。[实装侧栏](SESSION_2026-11-23_HUD_CONTEXT_SIDEBAR.md) · [混编头像复用与八项既有失败](SESSION_2026-11-23_EXP19_GROUP_CACHE.md) |
| 排除或找回作战单位 | 排除标记跟随单位实例，F2 和 P 跳过被排除单位，默认 F3 找回。双模式专项 8 项通过，完整回归仍有卡池断言失败。[按键与恢复边界](SESSION_2026-11-23_F2_EXCLUSION.md) |
| 看警戒值与总攻时间 | 最终阵营映射为苏军绿铜槽、盟军蓝灰槽。左环表示总攻剩余时间，180 秒对应 24 格；横灯显示警戒。两阵营控件图形检查 28 项通过，完整战场曾受并行改动干扰。[最终映射](SESSION_2026-11-20_ALERT_FACTION_FINAL_CORRECTION.md) · [实际控件渲染](SESSION_2026-11-20_ALERT_FACTIONS_VERIFIED.md) |
| 收起远征任务面板 | 完全收起时只留主目标进度，点击进度行恢复先前的详情状态。真实场景 31/31，覆盖默认窗口。百科另有独立全屏入口，左侧按任务或人物选条目，右侧读正文。[战中任务摘要](SESSION_2026-11-23_OBJECTIVE_ONLY_HUD.md) · [百科布局](SESSION_2026-11-24_GUIDE_READER_LAYOUT.md) |

旧车辆 HUD 和可点击雷达 SVG 是概念稿。当前界面的控件、输入和截图应从上表的实施记录查起。[车辆概念稿](SESSION_2026-11-23_VEHICLE_HUD_CONCEPT.md) · [雷达原型](SESSION_2026-11-23_RADAR_V2.md)

## 制作约定

- RA2/YR按各单位自己的VXL/HVA/SHP制作，保留轮廓、阵营色和比例；检查体素32向、炮塔／炮口、阴影／选取及SHP动作。样车坐标不通用于其他型号。
- 专属皮肤先明确兵种主部件与招牌动作，主辅节奏、近景连接／材质／挂点／收尾完整；通用换色加粒子不足以替代专属创意。
- TNKD猎隼涡轮先高速旋转、绕圈再喷；最新要求短小粗壮尾焰，覆盖早期长尾焰。选中灯效取消选中后3秒渐缓并保持当时颜色亮度。
- SHP配件逐帧按本兵种关节定位，方向与位置分别校准；单向待机转身按动画帧处理方向及遮挡。
- 夜枭保持原版大小，猎蛛140%；按可见主体标定，不按透明画布。32向独立图、动态灯／旋翼／气流保留，性能不能凭“没用粒子”推断。

来源：[精细化约定](sources/memories/extensions/ad_hoc/notes/20261102-125646-irontide-allied-soviet-model-detail.md)；[皮肤标准](sources/memories/extensions/ad_hoc/notes/20261104-195110-irontide-ra2-skin-design-standard.md)；[短尾焰覆盖决定](sources/memories/extensions/ad_hoc/notes/20261104-200110-irontide-hunter-short-jet-selection.md)；[逐帧挂点](sources/memories/extensions/ad_hoc/notes/20261104-215339-irontide-ra2-infantry-skin-sockets.md)；[夜枭／猎蛛制作避坑](sources/memories_v2/extensions/ad_hoc/notes/2026-11-17-irontide-night-hunter-skin-lessons.md)。

## 夜枭／猎蛛避坑

纹理像素与逻辑尺寸分开；低alpha残留会误导脚底锚点；步态按真实位移推进，堵住／瞬移不算移动；检查图集邻格串色；独立shader显式传入同一阵营色；边界离线缓存，避免每帧扫像素或重建几何。原文具体坐标／阈值不泛化为所有皮肤通用参数。

v0.29.10“仍在免费体验”是历史，后续README记录v0.29.31结束体验。重新处理定价时查当前目录与购买入口，不依据旧免费快照开放权限。

## 状态与冷却显示

- v0.31.30 的战略支援栏用半透明蓝灰遮罩显示剩余冷却。上边缘的亮线随时间自上而下移动，上方逐步露出按钮，就绪时遮罩消失。信物使用真实剩余战斗秒，开场错峰及 240 秒联动另存本次总时长。旧检查点若只存剩余秒，按常规 600 秒绘制信物进度，原有剩余时间照常生效。侦察机、力场护盾等支援使用各自建筑的实际充能，断电暂停充能时进度也停住。
- 信物 408 项与战略支援 124 项专项通过。隔离 OpenGL 战场对同一按钮在剩余 100%、75%、50%、25% 时测得亮线纵坐标依次为 37、45、54、62，实测就绪后遮罩消失。日志、逐帧图与加速动图位于 `%TEMP%/CodexIronTideValidation-support-mask-1795511614562/`。

- 全单位Buff／Debuff／倒计时／叠层统一小图标与状态格、悬停说明。每种效果稳定唯一id，多选不合并不同单位叠层。
- 显示读取真实状态，主副目标分开、有数字不只颜色；不推进计时、不改变伤害／存档，遵守迷雾／死亡／装载边界。
- 冷却圈按真实独立装填武器／炮位，共用弹匣共享圈，只显示当前模式；不另开UI倒计时，不按外观炮管数推算。

来源：[全单位状态](sources/memories_v2/extensions/ad_hoc/notes/2026-11-12-irontide-unit-status.md)；[叠层展示](sources/memories/extensions/ad_hoc/notes/20261105-183154-irontide-talent-stack-display.md)；[冷却圈](sources/memories/extensions/ad_hoc/notes/20261102-162454-irontide-weapon-cooldown-rings.md)。
细节：[MODEL_RENDERING](../../../docs/MODEL_RENDERING.md)、[UNIT_STATUS](../../../docs/UNIT_STATUS.md)。

历史自动回归通过与玩家视觉确认分开，迁移不把待确认改成已验收。
