# 起义时刻音乐逻辑核对

核对日期：2026-11-19。此次只调查，未更改游戏逻辑。

## 证据及限制

事实源为本地 EA Modding Support Uprising XML：
- ../../refs/ea-modding-support/Uprising/Xml/PathMusic/StandardPathMusicGameDynamicState.xml
- ../../refs/ea-modding-support/Uprising/Xml/PathMusic/PathMusicEvents.xml
- ../../refs/ea-modding-support/Uprising/Xml/PathMusic/BasePathMusicEvent.xml

这是官方配置审计，不是已经完成游戏可执行文件的反汇编验证。Standard_Full 是标准自动状态集合，文件说明通常用于多人地图，也可能用于战役。特定地图有 Scripted/EP1 状态集，因此不能泛称所有挑战关卡都只使用标准规则。

## 标准状态

BaseBuilding -> ThreatLevel1/GeneralCombat -> EvenCombat/DisadvantageCombat/AdvantageCombat。

GeneralCombat 是常规战斗入口，EnterEvent=Combat。
AdvantageCombat 的官方注释：玩家优势明确、即将获胜，音乐应足够史诗，不用于小规模胜利。EnterEvent=SetAdvantagePlayer。
DisadvantageCombat=SetAdvantageEnemy；EvenCombat=ResetAdvantage。
结果曲另有 StatsWinTrack、S_EndMissionWin 事件，不能等同占优状态。

## 进入占优状态

GeneralCombat_to_AdvantageCombat_Allowed 同时要求：
- 当前 GeneralCombat。
- 进入 GeneralCombat 至少 20 秒。
- PlayerDestroyedManyImportantStructures：120 秒窗口内，本地玩家击杀 5 个符合关键建筑过滤器的目标。
- 当前未处于 AdvantageCombat。
- 距退出 AdvantageCombat 至少 120 秒。

EvenCombat/DisadvantageCombat 也有进入占优状态的转移，要求对应状态已进入至少 20 秒、上述关键建筑击杀条件及占优重入间隔。

关键建筑过滤器 Include=STRUCTURE，排除 FS_BASE_DEFENSE、各种墙及 SUMMONED。

没有在上述标准配置中发现“全场存活单位多 30%”或“击杀初始数量的一半”条件。

## 占优持续及其他战斗条件

AdvantageCombat 进入至少 120 秒后才退出：最近 60 秒有交战则回 EvenCombat，否则回 ThreatLevel1_1。

劣势条件：最近 20 秒本地玩家击杀比 <=0.5，且敌方对本地玩家至少 3 次击杀。
从劣势回均势：最近 20 秒本地玩家击杀比 >=2，且本地玩家至少 3 次击杀。
另有 EvenBattle=击杀比 0.9..1.1 的条件定义，不能据其存在认定所有转移都使用它。

SkirmishMediumOnScreen：双方各自满足 Count=3、Time=20s、ON_SCREEN 的 EngagementCount；检查间隔 0.5 秒。EngagementCount 的底层精确计数语义未反汇编确认，不等同断言屏幕同时存活三名士兵。

## Red Alert

Anywhere_to_RedAlert 条件 PlayerActiavtedRedAlert（原配置拼写如此），类型 LocalPlayerHitRedAlertButton，按钮事件后 5 秒内返回 true。
RedAlert 状态 EnterEvent=RedAlert，官方注释为玩家按下按钮后进入 panicky 状态。
RedAlert 进入至少 60 秒后转 ThreatLevel1_1。

这证明按钮接入战斗音乐状态，不是新远征配置入口。仅凭音乐配置无法断定挑战模式按钮的全部单位强化、代价、UI 效果或可用次数。
GlobalData/RedAlerts.xml 另有旧式 RedAlertTemplate 数值，但未验证挑战模式运行时实际使用该模板，不应直接移植其建筑掉血等参数。

## 过渡与资源

BasePathMusicEvent 引用 AUDIO:Pathfinder\\RA3EPMus\\PC\\RA3EPMus.h。
XML 发送 Combat/SetAdvantagePlayer/ResetAdvantage/RedAlert 等事件；本地未找到该 Pathfinder 工程/头文件。
因此尚未核实事件到 Triumphal MP3 的逐首映射、节拍/乐句切点、桥段长度及交叉淡化时长。现有 MP3 的淡出淡入只是适配方案，不是已核实原版过渡。
Uprising 是资料片曲目来源命名，本次未发现官方状态叫 Uprising，更没有证明需要先普通曲再起义曲。

## 当前项目差异

当前实现的 1.3 倍存活单位优势、初始单位/建筑累计损失过半、一次性锁定 Triumphal，均为项目适配规则，不能归为原版规则。
远征菜单 Red Alert 按钮播放开场动画再打开新远征配置，未实现原版战斗 RedAlert 音乐状态。
本次保留这些实现不变，避免将未验证的原版规则直接覆盖用户明确的 30% 兵力方案。
