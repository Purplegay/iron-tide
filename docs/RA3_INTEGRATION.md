# RA3 交互风格与 RA2 素材整合

2026-10-21 用户调整优先级：使用 RA3 的 UI 风格，保留 RA2 素材；先优化经济/生产、对局规则、地图/迷雾、画面/资源。

## 当前实施范围

2026-10-28 · v0.5.1：右侧生产浮动说明改为固定情报区，显示当前悬停卡片的头像、状态与完整解锁链；移入详情可滚动阅读，切换目录／工厂清空旧引用。维修／出售、分类、工厂和队列提示同步接入；解锁路线打开时隐藏情报区，关闭恢复。保留原生产卡片、圆形进度、就绪闪烁、批量与暂停操作。参考本地官方 SDK UI 包中 TacticalHUDMainCommandBar / TacticalHUDSelectionDetails 的职责拆分；固定右栏排版、156px 高度及悬停保持是 Godot 适配设计，不声称直接移植原版 APT 界面。素材沿用已有 RA2 头像和侧栏；无新增下载资源。运行与画面证据见 VERIFICATION 的同版本记录，`pending_user_visual_confirmation`。

2026-10-23：生产侧栏新增常驻「维修 K / 出售 L」。不需先选单位；点击建筑操作，模式持续，重复按钮、右键或 Esc 退出；收起单位菜单仍可使用。鼠标使用本地 MOUSE.SHP 的 repair 170–189 / sell 129–138 及禁用帧，映射参考 [OpenRA/ra2 cursors.yaml](https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml)。维修读取 General 的 RepairStep=8、RepairRate=.016 分钟、RepairPercent=15%（已核对本地 YR rulesmd.ini），扣费采用项目浮点资金与实际恢复血量；不足暂停且不积攒维修时间，到账后继续，满血停止，并显示状态、播放维修 EVA。出售遵守原有主基地保护与 Unsellable，拒绝敌方、未完成、死亡和重复目标；退还配置 RefundPercent=50% 及生产队列实际已付费用，清除占地、电力、集结点与选择，不触发死亡爆炸/击杀事件。本次为即时出售，尚未实现逆向建造出售动画或原版乘员逃生。最终专项 102 项通过（含真实点击、原始语音流、扣费边界）；此前同批布局 576、鼠标 62 项通过，随后仅补维修 EVA 调用并重跑专项。各次隔离存档、源码前后稳定、退出码 0、无错误/警告；服务/端口/数据库 none。真实启动目录资源导入通过，既有 22 个非日志存档文件哈希未变。证据：`C:/Users/admin/Temp/iron-tide-building-actions-20261023/`。画面和操作体验仍为 `pending_user_visual_confirmation`。

2026-10-23：按用户最新要求，收起底部单位菜单时只隐藏详情、指令与增益栏，保留可点击的技能栏并贴到底部；雷达和生产栏保持。技能面板独立于被隐藏的详情父节点，按实际最小高度留足底边距。切换单位更新技能但不展开详情，展开后恢复当前单位状态。没有技能的选择不显示空技能栏。`hud_layout_regression` 在两种模式、1280×720 至 2560×1440 四种分辨率下共 576 项断言通过，包含技能按钮真实点击、Q 施放、隐藏区域鼠标穿透、切换单位/增益刷新、边距与恢复布局。实际渲染截图已检查，源码前后稳定、退出码 0，使用隔离项目和存档；服务/端口/数据库 none。报告：`C:/Users/admin/Temp/iron-tide-collapse-skills-20261023/final-hud_layout_regression/reports`。首轮检测到技能面板最小高度超出预设边距，并修正无技能 E1 的旧测试假设后重跑通过；实际操作体验仍为 `pending_user_visual_confirmation`。此前将技能一并隐藏的行为已被本次要求替代。

- 界面：雷达、生产、选中详情和技能分区；使用本地 RA2 cameo 与 SIDEC01 侧栏贴图，保持 QWER 技能、鼠标生产、解锁原因与路线引导。
- 经济：采矿量不能超过货舱剩余容量；异常负时间/负采矿量不能创造矿石或负货物；保留矿场付费生产矿车和门口短距离倒车。
- 规则：遭遇战支持建筑/基地车短局与全部单位歼灭；同时覆灭为平局，平局不结算扩展养成奖励；战役仍保护主基地。
- 视野：可选战争迷雾，双方独立当前视野与探索记录；地图、雷达、目标获取和选取使用共同判定。开局提供各自最近矿区的地形情报（仅探索记录，不提供敌军视野），保证矿车可以自动开始采矿；雷达金色为已知矿区、青色为当前可见矿区。首版使用现有 sight 世界距离，不宣称原版视野换算或地形遮挡等价。
- 验证：使用隔离 Godot 项目和独立存档；自动断言、渲染截图与实际体验确认分别记录。

本批最终 15 组共 1,754 项断言通过，测试副本与实际启动目录源码一致，玩家存档未变；
实际项目导入通过。继续使用 `iron_tide/启动游戏.bat`，关闭旧游戏后重开即可加载。
详细证据见 [VERIFICATION.md](VERIFICATION.md)，画面与操作体验仍待实际确认。

## 本地参考工具

下载来源：[CNCNZ 的 RA3 下载归档](https://cncnz.com/downloads/red-alert-3-downloads/)，[C&C Labs SDK v3 目录](https://www.cnclabs.com/downloads/details/1513/)。软件由 EA Los Angeles 发布，当前下载使用社区归档镜像。

| 文件 | 大小（字节） | SHA256 |
|---|---:|---|
| `refs/ra3-sdk/RA3ModSDK.exe` | 136752107 | `ad7240f8b7d0dbd4d4b67c164e18ce5d41c247f252cf1c3a01d42864306a7fbc` |
| `refs/ra3-sdk/RA3SDK_UI_ScreensPack.rar` | 247047136 | `82e29a9035039aa323dd4ea19ff62a9e0afd516732f2f27e1bdd1cc3d8772d7c` |

SDK 已于 2026-10-21 部署到 `refs/ra3-sdk/installed`，采用项目内便携安装，不注册虚假的 RA3 游戏路径。原 InstallShield 静默安装返回 -5；使用其 `/s /extract_all:<路径>` 展开，再用 UniExtract2 所带 unshield 提取 CAB。安装内容包括官方文档、SAGEXML、Schemas、Art、Audio、示例 Mod、BinaryAssetBuilder、MakeBig 和 ModStudio。

本机缺旧版 .NET 2.0，便携目录的编译器、打包器和 ModStudio 配置为使用已有 .NET 4；编译器及 ModStudio 的 CLR 标志设为 32-bit-required，以加载 x86 混合模式库。修改只限便携副本，原 EXE 与完整解包文件保留；没有安装系统组件、修改系统注册表或游戏文件。原装 Builtmods 文件组按官方 Common_Issues.htm 放到 `BuiltMods/SageXML`。安装文件清单与兼容修改记录见 `refs/ra3-sdk/installation.json`。

`tools/check-ra3-sdk.ps1` 已通过独立 ArmorTemplate XML 编译和 BIG 打包，两个工具退出码均为 0，编译日志无 Error/Critical；结果在 `installed/validation/20261021-164622/result.json`。官方 SampleMod 能产生输出，但原包缺少部分引用美术并报 Error，不能视为完整示例验收通过。本机未找到 RA3 游戏安装，未验证 ModStudio GUI、游戏内加载或 3ds Max 插件；完整 RA3 Mod 运行仍需对应游戏环境。

UI 包完整可读，已抽取 TacticalHUDRadar、TacticalHUDMainCommandBar、TacticalHUDSelectionDetails 到 `refs/ra3-sdk/ui-reference` 供本地参考。参考文件不并入 Godot 运行资源；SDK 也不是 Godot 插件。WorldBuilder 尚未下载。

## 尤里的复仇补充单位语音

来源为 [Vector 在 CnCNet 发布的 YR 单位语音补充包](https://forums.cncnet.org/topic/13001-how-to-implement-yr-unit-voice-lines-in-vanilla-ra2/)，发布于 2025-01-19，下载存于 `refs/yr-voices/RA2-YR-Voicelines.zip`（155795714 字节，SHA256 `83cf28566376fa7c05a04adf23bb31b0a066ad90f2ebd0ca7a734f29beec73e0`）。这是社区整理的游戏语音，保留本地参考资源边界，不把来源文件当作开源素材许可。

`ra2pipe/yr_voice_build.py` 只比较现有单位的 Voice* / 部署应答字段；不导入包内经济、武器、科技和其它规则。9 种单位（AMCV、CARRIER、AEGIS、LCRF、TNKD、CMIN、SREF、MGTK、FV）新增 23 组应答、124 段 WAV，6576806 字节。原版已有而未变化的应答、死亡音和 EVA 保留。两模式共用这套表现扩展；当前工程没有接入的尤里新兵种及尤里阵营 EVA 不在本批范围。

独立文件 `data/ra2/yr_voice_pack.json` 保存映射、源文件 SHA256 及输出音频 SHA256；音频放在 `assets/ra2/sfx/yr/`，条目采用 `yr_` 前缀。GameData 加载可选补充包，Ra2Sfx 优先选择对应应答；无包或无映射回退原 RA2 语音，不改单位配置对象。重建命令：

```powershell
python ra2pipe/yr_voice_build.py 'refs/yr-voices/source/RA2 YR Voicelines'
```

124 段 IMA 解码结果与 CPython audioop 独立实现逐字节一致；音频回归 426 项、音频生命周期回归 78 项通过。详细范围见 VERIFICATION.md。实际试听状态为 `pending_user_visual_confirmation`。

## 第二批：经济与生产细节

2026-10-21：RA2 模式将货舱数量和资金价值分开。读取本地 rules.ini 的 Riparius.Value=25、
Cruentus.Value=50、CMIN.Storage=20、HARV.Storage=40；当前可用盟军矿车满载普通矿为 500、
满载宝石为 1,000，混装按两种资源的实际数量计价。界面同时显示装载量与当前货物价值。
扩展模式保持容量 500、采集速率 22 和等待 4 秒后入账的旧经济适配。

RA2 采集速度为本工程适配的 0.88 单位/秒，卸货为 5 单位/秒，按单位分批入账；
这些时间不是原版 EXE 的逐帧还原。部分卸货后矿场失效，剩余货物保留，改投其他矿场必须重新返场并完成进站；
矿点失效后也必须先走到新矿点，不能远程取矿。矿车被毁时清空剩余货物，不发放资金。

RA2 三种生成地图的中央加入有限宝石区；普通矿显示金色，宝石显示蓝色，仍使用现有程序化矿体。
基地附近普通矿的总价值保留；宝石不再生。扩展模式保留约 50 秒线性回满适配；RA2 模式已改为下节的离散增长/扩散适配。暂停和结束对局不继续再生资源。

RA2 同阵营、已就绪且能生产同一单位的工厂应用 MultipleFactory=0.8 的累计工期倍率，
两座速度 1.25 倍、三座 1.5625 倍；多个建造场也加速建筑队列。工厂在建、展开中、被毁或需要电力但断电时不计入。
倍率只改变后续推进速度，已完成比例、已付费用和取消退款不跳变；低电惩罚继续生效。
保留每座工厂的既有独立队列，并非原版共享队列的完整复刻。
扩展模式不增加这项倍率；用户定制的矿场制造矿车也不参与加速。

经济参数由 `ra2pipe/economy.mjs` 从本地 INI 单独导出，完整 `ra2pipe/build.mjs` 也调用此步骤。
导出文件带原始 INI SHA256；不依赖参考项目的引擎源码。验证详情见 VERIFICATION.md。
本批最终 12 组、1,471 项断言通过，已测源码与实际启动目录一致；实际项目导入通过。
测试使用独立存储，控制台仍有部分既有 ObjectDB 退出警告，详情保留在验证记录。

## 第三批：基地切栏、卸矿表现、地表矿石和 GI 部署射击

针对本轮实际反馈，点选己方建造场自动打开建筑页；再次点选同一基地也会切回。
后续手动切页保留，敌方建筑、在建建筑和矿场不会强制跳建筑页。
矿场仅在同阵营矿车锁定本泊位、抵达且有货卸载时播放 GAREFNOR；
同时保留 active 层，避免洗矿时烟囱等常驻部件消失。离站、空货、死亡后恢复常态。

矿物由程序化高水晶改为本地 TIB01–03.TEM / GEM01–03.TEM 原始覆盖物，
使用专用 TEMPERAT.PAL，12 档密度随剩余数量切换，采空不画矿片。
独立导出入口为 `node ra2pipe/art_build.mjs resources`，
输出 provenance.json 保存原 MIX 来源、原素材、调色板和 PNG 哈希。
普通地表、单位与矿物调色板不能混用；调色板分类核对参考
[WAE 的资源加载实现](https://github.com/CnCNet/WorldAlteringEditor/blob/master/src/TSMapEditor/Rendering/TheaterGraphics.cs)，
以及 WAE v1.9.7 YR 配置中的 TiberiumPaletteName=temperat.pal。
当前本地 MIX 包缺少此调色板，使用 Advanced SHP Editor 随附的 RA2 原始调色板，
来源和固定 blob 记录在 ra2pipe/palettes/provenance.json；未使用地形或单位调色板替代。
运行时代码仍独立实现。矿石/宝石现已作为可通行覆盖层处理，见下面的 2026-10-23 追加记录；增长/扩散使用后文的连续世界适配。

### 2026-10-23：矿车侧身采矿修正

采集分支原来先扣矿，再调用武器瞄准函数 `_face`；该函数的 `_weapon_uses_hull` 明确排除矿车，所以车身一直保持驶入方向。现采集时停车并独立请求车身转向，仍由既有 `_limit_turn` 限制转速；实际车头与矿点方向误差不超过 2° 才扣矿、装载及刷新吸矿粒子。转向过程清除旧粒子，未选中的矿车也重绘；资源恰好位于车底时保留朝向并允许采集，满载仍正常返场。

来源核对：本机尤复 rulesmd.ini 的 CMIN 为 Harvester=yes、ROT=5、Storage=20、Speed=4，原规则哈希与下节相同；未改变导入数值。[OpenRA/ra2 的 CMIN](https://github.com/OpenRA/ra2/blob/master/mods/ra2/rules/allied-vehicles.yaml) 将采矿覆盖效果放在车体局部坐标；[OpenRA HarvestResource](https://github.com/OpenRA/OpenRA/blob/bleed/OpenRA.Mods.Common/Activities/HarvestResource.cs) 将可选采集朝向的转向放在扣除资源之前。OpenRA/ra2 的 CMIN 没有配置 HarvestFacings，且是在资源格内采集；本工程在矿点附近停车、对准矿点中心的 2° 门槛是连续世界适配，不宣称原版 EXE 采用相同门槛，也未搬运参考源码。

扩展 `harvest_fx_regression`：真实矿车物理入口覆盖八方向、左右 90° 与 180° 偏转、ROT 限速、转向时停止位移/扣矿/特效、资源守恒、目标方向改变、车底矿点和满载返场。修正前基线 150 项中 18 项失败；修正后含新增边界共 156 项通过。八方向素材回归 32 项、实际采矿往返/制造矿车 86 项、卸货口交通 44 项通过，总计 318 项。

证据：`C:/Users/admin/Temp/iron-tide-harvest-facing-20261023/`，四个专项均为独立项目/存档，源码运行前后不变、退出码 0，当前源码与测试副本一致。无服务、端口或数据库依赖。已检查八方向实际渲染截图；玩家实战观感仍为 `pending_user_visual_confirmation`。

### 2026-10-23：矿区通行修正

原问题是寻路没有封锁资源格，但 ResourceNode 使用 StaticBody2D 和半径 radius×0.85 的圆形碰撞，导致实际单位撞在矿区边缘。现改为 Node2D，不生成矿石实体碰撞；radius 继续用于绘制、采集拾取和禁止建筑占矿区。单位、建筑和岩体的碰撞掩码均未修改。

依据本机尤复 rulesmd.ini：TIB01/GEM01 为 Tiberium=yes 的覆盖物，[Tiberium] 的 Foot=90%、Track=70%、Wheel=50% 均非零，Buildable=no。原始规则 SHA256 为 `3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef`。同时核对 [OpenRA/ra2 的 Locomotor 与矿层配置](https://github.com/OpenRA/ra2/blob/master/mods/ra2/rules/world.yaml)，其 Ore/Gems 也为可通行地形。OpenRA 的部分速度值与原版不同，本次只修通行阻挡，没有照抄复刻项目的速度或宣称矿区减速已还原。

新增 `ore_passage_regression` 使用真实地图矿格生成、单位移动命令、A-star 和物理碰撞：双方步兵/灰熊/超时空矿车，在两种模式分别走入密集矿石和宝石中央再穿过；确认资源不被踩掉、采矿点击仍有效、建造禁区仍在、岩石和建筑仍阻挡。场景冻结时单独启用被测物体的物理空间，避免误把关闭物理当作可通行。初次脚手未启用物理空间的结果作废；有效修正前基线 171 项中 104 项失败，修正后 171 项全过。

同时通过采矿往返/制造矿车 86 项、卸货口交通 44 项，共 **301** 项。报告根 `C:/Users/admin/Temp/iron-tide-ore-passage-20261023/`，最终三个目录为 `ore_passage_regression`、`harvester_regression`、`refinery_traffic_regression`；均使用隔离项目/独立存档，退出码 0、运行前后源码一致，当前 resource_node.gd 指纹复核一致。服务、端口、数据库为 none。矿区专项退出有 2 个 ObjectDB 未回收实例告警；未将该告警当作零告警结果。此处验证逻辑通行，不代替玩家实战手感体验。

美国大兵部署后切换 Para / 精英 ParaE，对应 SSA 弹头和 GIAttackDeployed 音效，
八朝向实际播放 GISequence.DeployedFire；枪口火焰来自原序列，
不叠加站立 M60 的 MGUN 动画。起身恢复 M60 / M60E，清除旧射击动画和连发状态。
两模式共用正确武器，扩展模式的额外部署倍率仍保留，RA2 模式倍率为 1。
导表支持 `node ra2pipe/faction.mjs --gi-weapons-only`，只更新 E1 两个部署武器字段。

以上表现仍为 `pending_user_visual_confirmation`，自动验证结果见 VERIFICATION.md。

## 第四批：多工厂独立生产标签

### 2026-10-23：恢复生产分类、双入口矿车与科技开关

按本机尤复 rulesmd.ini 核对：JUMPJET 属 InfantryTypes、前置 GAPILE/RADAR；SHAD、CMIN 属 VehicleTypes，分别需要 GAWEAP、GAWEAP/PROC。现在按生产建筑分类而非飞行标签分类：火箭飞行兵回步兵栏，夜鹰和矿车回载具栏，空军只展示机场生产单位；六个主分类及每厂独立标签继续保留。移动、对空判定、素材和武器标签不变。参考交叉核对：[OpenRA/ra2 步兵](https://github.com/OpenRA/ra2/blob/master/mods/ra2/rules/allied-infantry.yaml)、[载具](https://github.com/OpenRA/ra2/blob/master/mods/ra2/rules/allied-vehicles.yaml)，没有复制参考实现。

建筑目录及真实建造通道统一消费已导入的 BuildCat：GACSPH、GAWEAT、GASPYSAT 的 Combat 归防御栏，解锁引导跳转也使用同一分类。GASAND 原 TechLevel=-1，按用户要求移除建造项并拒绝双方下单和进入放置；保留已有地图/测试使用的素材与定义。

CMIN 的 built_at 恢复 GAWEAP，载具卡只路由战车工厂，不会因为地图上选着矿场而把订单送到矿场。矿场仍有一辆容量的独立制造动作，接入本局、分阵营的 `refinery_miner` 科技节点。`GM.unlock_production_tech=true` 是当前调试默认值，GM 控制台可关闭；关闭后显示“需要科技：矿场矿车制造”，禁用按钮和入队，已有在产暂停并保留实付进度、仍可取消退款。正常战车厂矿车不受该科技限制，仍检查原前置、按原价付费。节点支持真实按阵营授予，不跨局残留；完整研究界面、研究费用和前置分支尚未设计，本次没有虚构收费或存档解锁。敌方补矿车统计两类生产队列，科技未解锁时使用战车厂。

验证：`factory_tabs_regression` 310、`harvester_regression` 104、`dual_build_regression` 70、`unlock_navigation_regression` 58，共 542 项通过。覆盖全部现有盟军单位生产分类，真实鼠标下单/长按、出厂/精确扣费、矿车自动找矿场、同厂阻断不转单、科技默认/关闭/授予/两阵营隔离/跨局隔离/在产暂停，以及建筑双通道和引导跳转。报告根 `C:/Users/admin/Temp/iron-tide-production-tabs-20261023/`：最终前三项在 `final-<suite>`，引导在 `render-unlock_navigation_regression`。均独立项目及存档，源码运行前后不变、当前脚本一致、退出码 0；服务/端口/数据库 none。双通道测试退出有 5 个 ObjectDB 实例告警。首轮工厂测试因冻结 fixture 未执行矿车第一次物理 tick 而失败，修正为真实入口后通过；引导首次误用 headless 等待渲染帧，已停止该测试并 Render 重跑，不计入通过。分类和矿场制造截图已检查；实际布局体验仍为 `pending_user_visual_confirmation`。

以下为早期标签实现记录；其中“混合空军目录”已由上述生产分类替代。

两模式的步兵、载具、空军、海军目录新增工厂小标签，沿用 RA2 面板样式。
每座己方生产建筑有稳定编号、独立进度条、队列数量和状态；施工、缺钱、
缺电、缺前置、出口受阻等使用原有生产状态文案，详细信息在悬停提示中。
多个标签按三列换行，位于对应生产目录上方。
空军页保留真实生产归属：飞行兵由兵营制造、运输直升机由战车工厂制造、
战机由机场制造；标签显示真实建筑类型。首次打开优先机场，手动选择后记住该厂。

2026-10-23 修正混合空军目录的跨类型下单：当前机场不支持飞行兵/夜鹰时，
可使用已存在的对应生产建筑，卡片显示“由盟军兵营/盟军战车工厂生产”，
点击后明确切换工厂标签并把订单加入其队列。原先仅检查当前机场而显示
“无法生产该单位”的拦截已移除。当前工厂本身支持该单位时仍锁定它，
不会绕过队列满、施工或前置限制转投同类工厂；缺少真实生产建筑仍显示缺失原因。
专项 224、生产拒绝原因 56、批量/集结 38，共 318 项断言通过，覆盖真实点击、
跨厂长按恰好 5 个、火箭飞行兵/夜鹰实际出厂及按原价扣款。各轮独立存档、
源文件前后稳定且 HUD 源码一致；没有连接网络服务或数据库。报告与实景截图：
`C:/Users/admin/Temp/iron-tide-air-production-20261023/`。旧生产原因测试无条件等待
渲染帧，首次 headless 运行因此终止，未计入通过；最终以 Render 重跑通过。
实际交互体验仍为 `pending_user_visual_confirmation`。

每个兵种类别记住上次选中的工厂。点选地图上的生产建筑会同步标签；
点击标签只切生产上下文，不改变战场上的部队选择。生产卡下单、
卡面进度和数量、页脚队列与右键取消使用同一工厂；选中队列满时不能暗中
转投其他工厂，空闲工厂也不会被另一座忙碌工厂自动替换。
工厂新增会出现新标签；被毁或转为非己方后移除，选择回退至有效工厂。
切换工厂时取消旧的长按手势，避免批量订单落到错误工厂。

复用原有 Building 独立队列、实际扣款/退款、出生出口和各自集结点；
没有新增一套生产状态机。现行 RA2 多工厂速度倍率与扩展模式规则保留。
建筑/防御现按下节拆分独立建造通道，矿场制造矿车仍保留独立技能入口。
自动验证见 VERIFICATION.md；界面与交互体验为 pending_user_visual_confirmation。

## 建筑与防御独立建造

两模式均可同时建造一个普通建筑和一个防御建筑。同类依次排队，各自最多 9 项；
沿用现有 defense 标签分类。两个页签分别显示本类进度、等待数量和就绪数量，
解锁引导同步区分本类“建造中 / 排队中”，不再显示不相关的工厂空闲状态。
右键取消只退款对应项目；建造完成后各自保留待放置数量，放置不重复扣款。

资金、电力和建造场共用，价格、建造时间、缺电及多建造场倍率沿用现有规则。
无资金或失去建造场时暂停；资金不足以支付两个通道时按普通建筑、再防御顺序分配，
不会重复花费。敌方后端同样支持双通道，现有 AI 的普通建筑规划不被防御队列阻挡；
本批没有新增 AI 主动选择防御建筑的战略。自动验证见 VERIFICATION.md，
界面与操作体验仍为 pending_user_visual_confirmation。

## 开火暴露位置

2026-10-23 迷雾表现调整：原实现每 0.1 秒直接切换遮罩，已探索区域从透明瞬间变成
68% 不透明。现在失去视野后地形保持 0.6 秒，再用 0.6 秒线性渐暗至 45%；
遮罩使用中性黑色及线性纹理采样，柔化 40 世界单位网格的硬边。再次获得视野立即清除，
普通 rebuild 不重置渐暗计时，暂停/终局冻结推进。未探索区域仍为不透明黑幕。
视觉缓冲只影响地形和共用该纹理的小地图；真实 visible/explored、敌军显隐、点击、
索敌、施工位置检查以及开火暴露 3 秒规则保持不变。

参考边界：[公开的原版 rulesmd.ini 文本](https://gist.github.com/Mirage-Zero-Nine/0c2df4046c279a15ee1f80e6d1608e7d)
及本地参考 rules.ini 都列有 FogOfWar=no、ShroudGrow=no、FogRate=.01。
这些字段不能证明原版启用了动态回填，更不能证明其 GPU/精灵淡出时长；本次保留用户已启用的
动态迷雾，0.6+0.6 秒和 45% 是项目的表现调校值，不宣称原版像素级复刻。
`fog_rules_regression -Render` 共 491 项通过，覆盖渐暗时序、重复重建、暂停、重返视野、
敌人不泄漏、攻击暴露、两阵营规则、起始矿区和终局规则，并检查两模式的分阶段截图。
各轮独立项目/存档，未使用网络服务、端口或数据库；实际工程导入和源文件稳定性核验通过。
报告：`C:/Users/admin/Temp/iron-tide-fog-visual-20261023/fog-first/reports`。
体验仍为 `pending_user_visual_confirmation`。

战争迷雾开启时，普通单位和防御建筑实际开火会向受攻击方暴露开火点周围
120 世界单位范围，持续 3 秒；同一攻击者再次开火更新位置与持续时间。
暴露立即进入双方共用视野，主画面、小地图、选取及反击目标判定同步生效。
双方规则相同；停火后恢复迷雾，保留地形探索，不追踪离开开火区域的隐蔽单位。
暂停时倒计时冻结。开火判定失败不会暴露，闪避不会阻止暴露；光棱支援束也暴露支援塔。
本项为用户要求的交互/规则适配，不宣称原版 RA2/RA3 暴露时长等价；
超武和其它主动技能仍沿用各自现有视野规则。

## 鼠标选取与攻击图标（2026-10-21）

战场鼠标已接入本地 MOUSE.SHP / MOUSEPAL.PAL，共导出 45 帧，包含普通箭头、
单选悬停、移动、攻击、禁用、采矿、攻击移动和拖屏。帧号/调色板交叉核对
[OpenRA RA2 cursor definitions](https://github.com/OpenRA/ra2/blob/master/mods/ra2/cursors.yaml) 与
[palette definitions](https://github.com/OpenRA/ra2/blob/master/mods/ra2/rules/palettes.yaml)；
只参考素材映射，运行时状态判断独立实现，动画采用本项目 15 FPS。
重建入口为 `node ra2pipe/cursor_art.mjs`，需提供本地 RA2_MIX_DIR；
产物 mouse.json 保存原素材、调色板及 PNG SHA256。

己方可选单位/建筑显示单选动画；选中部队悬停可攻击敌人时显示攻击图标，
武器空地类型不支持或仅选择无武器/采矿单位时显示禁用图标。
混合编队只要存在可攻击成员即可提示攻击，不把射程外可追击目标判为不可攻击。
图标查询复用可见像素拾取及战争迷雾；每帧重新查询，不依赖过期 hover_entity。
命令和技能/建造瞄准优先，原有采集优先级、左键选取、右键指令和伤害逻辑不变。

光标在独立屏幕层渲染，原图 55×43，不随相机缩放、旋转或等距投影变形。
侧栏、暂停、结算、失焦和离开视口时恢复系统指针；退出战场释放鼠标显示状态。
离屏测试视口不控制桌面指针。现阶段不是全部原版特殊技能/滚屏方向光标的完整复刻；
截图与断言记录见 VERIFICATION.md，实际体验仍为 pending_user_visual_confirmation。

## 单位军衔与作战经验（2026-10-21）

两模式沿用本局新兵 / 老兵 / 精英三个阶段，对应界面 Lv.1 / Lv.2 / Lv.3。
普通投射物通过弱引用将击杀经验传回存活开火单位；单位和建筑只在首次死亡时
按目标造价结算经验，友军击杀、出售/无来源销毁不计经验，删除或死亡的发射者不获追授。
保留现有 VeteranRatio、升级门槛、能力倍率与精英武器；Trainable=no 和无升级配置
的单位不晋升。炮塔等无军衔接口的建筑不会因这项改动获得单位等级。

选中单位显示等级、军衔、本级经验、下一级差额和经验条；经验增长原地刷新，
晋升时同步刷新军衔、属性与实际精英武器说明，不需要重新选取。
多选部队头像新增军衔角标，战场继续使用既有血条旁军衔标和晋升提示。
精英明确显示满级，不虚构后续等级；无法晋升者显示原因。此为本局作战经验，
不改变局外养成和存档。断言与截图见 VERIFICATION.md，体验待用户确认。

## 2026-10-21 经济链与基地迁移

用户指定顺序：超时空矿车返场 → 精炼器加成 → 矿石增长扩散 → 建造场收起 → RA3 画面与操作。
本轮在 Godot 中独立实现，不搬运参考引擎代码；规则来源为本地 `extracted/rules.ini`，导出入口 `ra2pipe/economy.mjs`。

- CMIN 有货且远离矿场入口时准备传送；按 `ChronoMinimumDelay=16` / 15 得到约 1.07 秒工程适配。传送到矿场前的安全停靠准备点，之后保留短距离倒车及实际卸货。水面、建筑、矿体、障碍和地面单位均阻挡落点；入口占用就等待，不重叠、不提前入账。手动移动和更换矿场清除旧充能。空车、去矿区及其他单位不借此传送。
- GAOREP 正确标为 `purifier`，从矿场标签和 PROC 前置候选中移除。双方各自每座存活、完成展开、未被干扰且电力正常的精炼器，为实际卸货收入增加 `PurifierBonus=.25`；数量和货物基础价值不变，部分卸货按当时有效加成结算。精炼器不卸矿、不生产矿车，也不放大出售/退款等普通入账。
- RA2 普通矿按 `GrowthRate=5` 分钟周期增长，现有非空矿每次增长容量的 6%。周期开始时已满的矿格才可扩散，每周期最多 `ceil(满矿格数*0.06)` 个邻格，创建密度一帧的矿或重新播种相邻空矿格。四向间距按连续世界碰撞尺寸适配，拒绝水域、建筑、障碍、单位和已有矿格重叠，总节点上限 512；同一周期不连锁扩散。采空且没有满矿邻居的矿不凭空回满，宝石有限不再生。扩展模式保留旧线性再生。原版 Growth/Spread 的内部帧调度与地图格算法未声称等价。
- 选中己方建造场可用按钮或 D 收起 AMCV，再用原 D 部署展开。保留生命比例，不走死亡、经验、退款或重新付款路径。没有其他建造场时建筑/防御两条队列保持已付进度并暂停；重新展开后接着推进。落点被占、正在展开、暂停或战役要求保留最后主基地时拒绝，并展示原因。遭遇战 MCV 继续计入存活资产。
- RA3 风格交互首轮：复用 RA2 基地车图标，新增带状态/禁用原因的收起按钮；矿车生命条下常驻当前活动、货舱价值、精炼加成与装载条，悬停展示预计结算；精炼器显示运行/缺电/干扰和本方总加成。保留多工厂标签、建筑/防御独立队列及 QWER 技能入口，移除过期 B 建筑页提示。

对应专项 `economy_chain_regression` 覆盖双方、两种模式、传送阻挡/取消、收益守恒、增长周期/合法扩散、收起再展开及 UI 实时状态。画面、传送音效和实际操作体验仍为 `pending_user_visual_confirmation`，不将自动断言或截图当作用户确认。此轮是经济/基地操作区打磨，整体 RA3 界面重排、统一动效和剩余资源仍属后续工作。

## 后续缺口

原版矿层几何/逐帧调度与可穿行矿层、原始地图格式、地形遮挡/潜隐探测、敌方建筑侦察快照、剩余占位素材与精确武器挂点仍需独立实施。旧的 `Ra3Skin` 名称本身不作为 RA3 UI 完成证明；本批画面与操作结论保留 `pending_user_visual_confirmation`。

超时空返回、精炼器、矿石增长和建造场收起已完成本批实现；后续补完整对局规则；
再处理地形遮挡、侦察记忆与地图资源；持续修整 UI 贴图缩放、剩余占位资源和武器挂点。


## 2026-10-21 背景音乐与指定曲目

用户确认指定 Tim Wynn 的《Rock and Awe》。默认清单 `iron_tide/data/music.json` 只登记这首曲目，加载路径为 `iron_tide/assets/music/rock-and-awe.mp3`。当前没有该音频文件，官方 SoundCloud 页面未开放下载；不得将其他样例改名并声称已装入指定曲目。用户提供 MP3 并放到该路径后，重启原启动脚本即可读取。

Music autoload 复用一个播放器，主菜单与战斗切换不叠加/重启，单曲结束自动循环；独立音量和静音设置保存在 `user://audio_settings.cfg`，不修改局外存档。战斗、暂停/结算适当降低音乐，EVA 和单位应答期间进一步压低，武器音效不触发语音压低。主菜单和战斗设置使用同一控制组件；缺文件时显示待放入提示、完整路径悬停说明，并禁用重播。

此前下载的作曲者公开试听片段及官方 SDK 音频样例均不加入默认曲单。SDK 样例仅用于隔离测试的真实 MP3 解码、混音、循环与音量断言，不作为 Rock and Awe 曲目验证。曲目文件尚缺，音乐实听仍待用户验证。
