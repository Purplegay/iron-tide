# 2026-11-19 Chatbox 工作记录与交接

范围：本次可见对话的需求、操作及工具实际返回；与 CURRENT_THREAD.md 中同日其他会话记录并存，不代表扫描了今天所有会话。日期按会话环境2026-11-19。未打包、提交、推送，未操作用户运行中的游戏。共享工作区有大量既有未提交修改，不能把全部Git差异归给本次。

## 用户约定

- 工作区 C:/Users/admin/IronTide/iron_tide；仓库根 C:/Users/admin/IronTide。
- 尽量少截图以节省流量，优先源码、日志与状态断言；本次未生成截图。
- 优化按实际消耗时间（self/inclusive）排序，调用次数仅辅助；沿耗时父调用下钻，不把父子inclusive相加，不把self等同于全局原生叶子。
- 正常六家稳定60 FPS，整帧16.67ms，33ms只是中间检查点。四方向：按实际能力更新、准确失效机制减少重算/查询、实测重循环尝试原生批处理、保持兵力/AI/公平性/模拟速度验收图形Release P95/P99及超预算比例。
- 最初仅要求记录计划；之后用户明确授权开始第一轮、子调用诊断和平均帧/P95测试。
- Chatbox长期记忆save_memory两次返回100条上限（优化计划、少截图偏好），未成功持久化到全局记忆。本目录是可读取的持久项目交接。

## 性能诊断：完成基线，未新增生产优化

吸收 docs/memory/README.md、PERFORMANCE/WORKSPACE/VALIDATION等主题页。既有Second.eligible按兵种分派是工作区原有未提交改动，不冒充本轮新实现。

1. 复核现有 expansion_dispatch_regression：961317项通过，0失败，31009正分支/449645负分支；8批局部交错计时，旧244.743ms→当前165.110ms，中位下降32.54%。合成无被动/天赋的资格微基准，不是实战收益。证据仓库.validation/chatbox-dispatch-round1-20261119/reports。
2. 找到真正可用Python C:/Users/admin/AppData/Local/Programs/Python/Python312/python.exe；PATH上的WindowsApps/python.exe只是占位符。Godot编辑器4.7.2位于LOCALAPPDATA/Programs/Godot；工程内IronTideRuntime.exe是Release运行时。
3. 冻结当前scripts/scenes/data/shaders/tests与原slot3/meta，334单位206建筑、玩家+5 AI、yr_isleland、1倍速、15Hz、64补步。串行完成原生脚本profiler、两场完整图形Release、一次Second.tick内部调用点采样。
4. 完整图形Release：私有未激活桌面，实际1600×900，无额外单位/阶段/GPU计时探针，保留游戏自带调用日志。A平均48.159ms/P95 73.100/P99 87.754；B平均51.879/P95 77.165/P99 88.665。各约60秒墙钟，模拟推进63.568/63.619秒，保留此偏差，不能忽略。两场测量窗口没有外部游戏，背景CPU11.90%/14.63%，无90%忙碌样本；源码无漂移。是同版本重复基线，无前后优化因果对照，未达60FPS。
5. frame-only工具未保存逐帧数组及超预算计数，本次超16.67ms比例为“未采集”，不能填零。早期汇总脚本曾算出0，已修正最终报告和summary为null/未采集。
6. 原生脚本profiler导出5475函数条目，但本场有外部用户游戏，作为受干扰辅助证据。Second.tick self62.006ms/inclusive1281.254ms；eligible self303.675/inclusive610.986；Infiltration.tick self21.973/inclusive143.294。公用函数计时不天然等于某一调用边。
7. 另一次Release headless只在Second.tick内部计时，约1/32采样、调用数精确，无外部游戏；父级总估算1305.504ms，eligible741.822ms，Infiltration.tick89.407、Infantry42.002、Submarine41.405、Ground33.200、Soviet31.238，其余能力tick约17–26ms。含探针成本、未校准空探针；低成本小差距不作精确结论。
8. 下一候选按时间优先资格检查，再检查Infiltration.tick的speed/hidden/escort_speed重复查询。尚未实现新候选、行为回归及图形Release ABBA；不重复计已有分派优化。

证据：仓库.validation/second-tick-20261119-171637/report.md、summary.json、diagnostic/functions.json、edges/result.json、graphics-a/b/result.json及environment/source-audit/host-cpu/desktop。原输入来自.validation/slot3-leaf-20261119/inputs，冻结哈希见input.json。性能台账 tools/PERFORMANCE.md已追加。本次工程根新增profile_second_round.py、profile_second_edges.py、summarize_second_round.py、finalize_second_round.py，属于诊断脚手，不是游戏逻辑。

## 友军建筑穿行：失败实验，正式入口已撤回

用户报告肉鸽基地堵塞，建议可穿自己/友军建筑但不能最终停在建筑内。发现现有scripts/units/base_escape.gd已具备卡住后友军基础穿行的兜底。尝试新增scripts/expedition/foundation_transit.gd和测试，并接入unit.gd/battle.gd，未可靠完成验证。

首测因测试缩进错误未执行；后续修正远征上下文后Godot异常退出-1073740940，日志没有脚本错误。未获得原生栈，不能确认是实现还是场景清理/夹具崩溃。所有本轮FoundationTransit生产调用点已从unit.gd/battle.gd撤回，搜索确认无引用；同文件其他既有改动保留。未引用的foundation_transit.gd和tests/expedition_foundation_transit_regression.gd/.tscn草稿仍在，不可当完成实现，也不应直接运行/推广。日志在LOCALAPPDATA/Temp/IronTransit-2d59e28f4dd84db9ba018d28d126c1ab/reports。需求仍待完成。

## 远征商店：等级显示与同店防重

用户截图随军医疗要求购买显示等级且不能重复获取。本次解释并实现为：保留原有最高3级、跨次购买升级设计；同店不重复卡位，旧存档同款只允许最前一张购买，买后后续同款仍拒绝。此解释没有用户另行确认，若用户指“整轮完全不能再获取”需重新核实，不误记为明确设计决定。

修改market.gd增加shop_key/unique_shop_pool及商品保留/生成后去重；run.gd purchase_problem拦截先前同key卡位（含已售）；screen.gd商店显示Lv.当前→Lv.购买后/3、羁绊当前/获得后层数。tests/expedition_regression新增同店首张可买、第二张不可买、装备一级/升至三级/满级拒绝测试。

最终隔离runner PASS 12094项、0失败、source_unchanged=true、无脚本错误，独立用户目录。证据仓库.validation/expedition-shop-levels-pass-20261119/reports；更早失败和超时结果保留，不能记成通过。UI未截图/图形验收。注意当前生成后补位去重实现并非全面性质证明，后续若碰到锁定/特装重复需核查，不能仅凭单轮回归推定全种子正确。

## 仅特装兵种攻防0/5却不能强化

截图左侧超时空军团兵仅持有特装II，攻防0/5但按钮“已满或停用”；右侧幻影坦克5/5已满正常。根因growth.can_upgrade只认run.licenses，不认special_squads。新增growth.upgrade_problem，允许有count>0的特装兵种升级；区分尚未持有、满5级、停用。run.item_problem与screen按钮复用原因；不添加普通招募许可，不改变停用和5级上限。

tests/expedition_growth_regression新增仅特装CLEG资格/升级/满级/停用断言。隔离专项84项通过、0失败，证据Temp/growth-special7-4254794bc2ed4ab980445447a0801b69/reports。早期PowerShell5子进程Get-FileHash不可用未启动游戏，换PowerShell7成功。未以真实用户存档重跑。

## 出战满员禁用与中央大号红字

screen.gd：本关出战CheckBox在未选中且active_roster达到Campaign.slots时disabled，已选项仍可取消，重建后释放名额即可再选，tooltip提示先取消一个。规则层set_active原有上限拒绝保留。

新增show_error，CanvasLayer100上全屏居中Label、36号红字#ff5555、黑色描边8、鼠标IGNORE、2.5秒保持后0.4秒淡出；失败result、配置/商店problem入口接入，原notice文本仍更新。不是所有游戏HUD的全局错误提示改造，仅远征screen。

tests/expedition_roster_ui_regression及tscn新增。初次资源导入超45秒中止；随后夹具兵种不足导致索引越界，补足满编+预备数据后16项通过、0失败。无截图，未测实际图形大字视觉效果。

## 自动列出超限预备兵种

本节记录 11 月 19 日的旧规则。自 v0.31.27 起，预备兵种不限种类；满 8 种出战、另有 6 种预备时，只要符合本章人口和各兵种携带数量，就能部署。[现行编制与回归](EXPEDITION.md#交互及验收)

用户要求截图中的超限提示自动显示多余编制。由于无唯一应删除兵种，army.roster_error保留原超限门槛available.size()>Campaign.slots+4，显示超出几种、需完整遣散至少几种，并列全部未出战预备兵种名称×人数，由玩家决定；不自动遣散、不减少部队。screen.build_army顶部也显示问题。

扩展上述UI测试：排除出战名单、包含超限数和预备人数、展示不改数量；最终19项通过、0失败，退出0。证据Temp/roster-ui-65bc15c0e618421fab04c54a8d221072/reports/overflow.out及result.json。此目录此前复用不同测试，result.json会被后来C4专项覆盖；须看具名日志，勿错认最新result为19项。

## 海豹C4手动命令被停火姿态拦截：已复现并修复一类情况

用户称海豹炸弹用不了，具体现场目标/状态未知。现有机制：GHOST/TANY等C4是右键敌方建筑后的近身动作，没有独立C4按钮；步入占地、安放计时、撤出。普通攻击回归原120项通过。新增测试证实RA2与扩展两模式下停火none＋手动攻击建筑均不能安放（122项中2失败）。不能据此认定用户现场一定同根因。

修复commando_combat.begin_c4：none只拒绝非手动命令；allied_abilities.use在order_move清除攻击状态之前保存explicit_c4，并写special.c4_explicit；can_order允许手动攻击/显式动作继续执行；cancel移除标记。自动寻敌仍遵守停火、保护目标/可见性/CanC4/敌我条件保持。此临时状态在special内，完整存档生命周期未单独加新断言。

最终commando_attack_regression126项、c4_entry_regression136项全部通过，退出0、无stderr；覆盖手动停火C4、自动停火拒绝、取消清理、进入/安放/退出和碰撞恢复。证据同Temp/roster-ui-65bc15c0e618421fab04c54a8d221072/reports/commando_attack_regression-final.out与c4_entry_regression-final.out。未截图，用户现场复验待进行。

## 最新截图异常：未定位

用户贴两架飞机、黑烟、绿色加号/橙色环截图问“什么bug”。仅凭静态图无法判断。助手指出可能烟雾过大/不散、飞机卡住或状态标记异常，询问具体对象、现象和持续时间；用户未补充，尚未启动修复。不要把截图推断记成已复现bug。

## 远征攻防强化商品降价与折扣

用户要求肉鸽增加攻防的商品便宜点，并适当加入打折概率且标出来。实现：`Growth.PRICE`从40降到25；商店`training`商品30%概率触发50%折扣，25×0.5向上取整为13；商品保存`original_price`/`discounted`/`shop_price_applied`，锁定商品不重复抽折扣。screen商店购买按钮显示“限时折扣 -50% · 25 → 13补给”，并加金色折扣说明；战地教范免费强化不受影响。完整远征回归12097项、0失败；折扣专项241项、0失败，120确定性样本折扣36/原价84。早期专项断言误以为折后为12，已更正为Godot ceili后的13并重跑通过。未截图、未打包提交推送。

## 下次接续

- 优化：已有子调用时间与图形平均/P95基线，若继续实施按eligible→Infiltration检查；保持原输入和图形对照，补预算比例采集。
- 穿友军楼不驻留：需求未完成，实验入口已撤回；保留草稿与原生异常缺口。
- 商店“不能重复获取”的整轮/单店含义仍有解释边界；当前实际为同店去重＋允许跨次升级。
- 远征UI与海豹改动已在源码，已运行游戏需重启才能加载；未导出新包，不将局部/无头回归当用户视觉确认。
- 中央烟雾截图：等待用户说明，不乱改。

## 18:21 后续覆盖：友军建筑穿行已接入并通过专项

用户再次明确“做吧”。复查旧测试发现exercise结束调用finish，_ready又调用finish的重复场景释放；删除重复清理后不再出现原生异常。本次不能据此断言旧异常唯一根因，但最终测试退出0。

正式接入foundation_transit.gd、unit.gd和battle.gd：仅远征中玩家ally的地面单位，移动命令期间临时忽略己方/同队建筑碰撞；直线只跨友楼且硬地形可走、终点净空足够时采用直接穿楼路径，否则保留原寻路。地形/敌楼不被开放。移动目标点落在友楼占地时向外找净空点；记录进楼前安全点，楼内停止/警戒立即退回该点（不是在楼内驻留，可能出现短距离位置跳回），出楼清除标记。普通对战不启用。当前不是全地图按阵营的穿楼A*，复杂多障碍路径仍走原有寻路/卡住脱困；不宣称解决全部基地拥堵。

最终expedition_foundation_transit_regression 14项通过：坦克/步兵实际进楼、完整穿越外侧落点、楼内停止与警戒回楼外、落点修正、友方阵营、敌楼阻挡、普通模式不启用、临时碰撞清理及安全点标记清除。既有friendly_infantry_traffic_regression 400项通过（含原base_escape场景），合计414项，均退出0且stderr空。早期夹具测试包含初始基地建筑导致返回端点不安全，失败证据保留；修正为清空无关建筑后通过，没有放宽净空条件。证据Temp/roster-ui-65bc15c0e618421fab04c54a8d221072/reports/transit-delivery.json/.out/.err以及friendly_infantry_traffic_regression-transit-final.json/.out/.err。未截图、未图形视觉验收、未做性能对照，需重启源码版加载，未打包提交。原“正式入口撤回/需求未完成”描述只代表18:00前历史，被本节覆盖。
## 下一阶段候选优化：正确性通过但完整帧淘汰

用户明确要求进入“候选优化、正确性回归、同条件优化前后图形对照”。基于Second.tick调用点耗时，隔离副本尝试两项候选：

1. `progression_expansion_2.eligible`固定兵种名单由线性`id not in [...]`改为固定字典`ELIGIBLE_TYPES`查询；不改动态R.active、passive、talent、status条件。
2. `expansion_2_infiltration.tick`在无shore_speed/shore_cloak/escort_cd/escort_buffs且不具备shore卡时立即返回；不缓存跨帧状态。

两项只写入`.validation/second-candidate-20261119-182808/candidate`隔离副本，生产源码未推广。正确性回归：`expansion_dispatch_regression` 961317项、`progression_expansion_2_infiltration_regression`199项，均0失败。

同冻结slot3/meta、334单位/206建筑、玩家+5 AI、yr_isleland、1倍速、15Hz、64补步、未激活私有桌面1600x900、Release图形、A→B→B→A四场：before-a平均53.494/P95 76.738/P99 91.770，after-a 55.835/78.117/94.934，after-b 52.944/75.380/88.721，before-b 50.538/73.926/82.050ms。超16.67ms计数由测试工具副本采集：before-a1089/1122、after-a1060/1075、after-b1104/1134、before-b1131/1188。两对受AI轨迹/系统噪声影响；第一对候选全项恶化，第二对排列波动，不能归因候选，故明确淘汰、不推广。运行窗口无外部游戏进程、源码无漂移，输入SHA与图形环境保留。完整证据`.validation/second-candidate-20261119-182808/`，台账`tools/PERFORMANCE.md`已追加。

参考核对：本地RA2YR_ReSource commit b01d3cf93db69aca9b5cb5054ba04e4358963828仅作固定分派结构参考；`refs/ts-ra2` commit 898d89188542a3028a232031ce1a0bdc7c605b6f的CloakableTrait仅作实时隐身计时结构参考。两者不是同机性能证据。生产改动仍保持用户/其他并行工作区状态，不能把Git中已有diff归因本轮。
