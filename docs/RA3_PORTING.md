# RA3 起义单位移植：未来坦克与先锋炮艇

<a id="soviet-ra3-v011"></a>
## v0.11 苏联三单位首批可玩迁移

2026-11-02 用户调整顺序并授权开始。首批测试曾仅要求 NAWEAP。当前扩展生产规则为：RA3 天启需要苏联战车工厂和苏联作战实验室，收割者和磁暴坦克需要苏联战车工厂和反应堆（使用已实装的苏联核子反应炉 NANRCT，对应 SovietPowerPlantAdvanced）。磁暴坦克的生产条件为扩展模式设定，GM 也可生成。各单位使用独立 R3 ID，经典模式生产目录继续按尤复规则筛选。

| 单位 | 官方定义与素材 | 已接入的玩法 |
|---|---|---|
| 磁暴坦克 R3TESLA | RA3 SDK SovietAntiVehicleVehicleTech2；Uprising 1.1 RVTESLATANK | 两发100磁暴、间隔0.2秒、装填2秒。Q 切换驻停短路放电，附近敌方地面载具受到 EMP。TeslaLinkGun 通过现有磁暴线圈充电接口运行。 |
| 天启坦克 R3APOC | RA3 SDK SovietAntiVehicleVehicleTech3；SUANTIVEHICLEVEHICLETECH3_SKN | 双炮、英雄爆炸弹、磁力鱼叉切换、载具牵引与接触碾碎、向建筑移动并持续研磨。打开鱼叉时采用官方模式视野加成。 |
| 收割者 R3REAPER | EA EP1 SovietHeavyWalkerVehicle、SovietHeavyWalkerWeaponSet、SovietHeavyWalkerDeployedTurret；SUHEAVYWALKERVEHICLE_SKN | 三门有射界的榴弹炮、一座十发火箭架、对空拦截、高度范围伤害。Q 选地，接近施放距离，起跳、落地点伤害、永久替换成 R3REAPERTURRET。炮塔是可被攻击的建筑，私有武器控制节点重用原骨架与弹匣，不占第二个单位名额。 |

生成工具 `tools/ra3_mirage/import_soviet.py` 消费既有 `extract_uprising.py` 和 `convert_uprising_media.py` 导出的 Steam Uprising 1.1 素材。提取目录为 `refs/ra3-soviet/{retail,fire,icons,ranks}`。导入支持收割者双骨骼顶点，使用原权重归一化及每个骨骼自己的绑定坐标。生产包为 `iron_tide/data/ra3_soviet.json`，模型、音频和来源指纹在 `iron_tide/assets/ra3/soviet`。技能逻辑与武器节奏见 `ra3_soviet.gd`，固定炮塔由 `ra3_reaper_emplacement.gd` 驱动。

实测覆盖工厂扣费出厂、经典模式排除、GM 名单、图标／语音解析、最高军衔、普攻伤害、技能槽、鱼叉锁定、EMP、跳跃中途恢复、旧工厂菜单、固定炮塔恢复后对空及四类 COL 碎块。隔离 Godot 渲染专项 51 项通过，截图与结果在 `refs/ra3-soviet/delivery/`。同时运行原有 GM、生产目录、RA3 军衔、盟军 RA3 行为及存档回归。复用同一快照编码器连续抓取时已重建对象表，避免沿用上一局对象引用。

本版的适配范围：磁暴和鱼叉使用 Godot 光束，炮弹使用连续地图弹道和命中表现。四个炮位有各自的弹匣和射界，当前围绕同一攻击指令目标开火。鱼叉碰撞／牵引、跳跃曲线与落地推挤、军衔收益和跨代伤害沿用本工程适配。原生 SAGE 特效全链、各炮位独立搜索不同目标、跳跃断腿独立物件和原版逐帧观感仍待补齐或对照。下方的排期为本次开始前的来源记录。

## 高清化完成后的苏联批次（2026-11-02）

先完成既定 RA2／尤复模型精细化，再接 RA3 磁暴坦克、RA3 天启坦克和《起义》收割者。分别注册 RA3 单位身份并沿用 GM 自动靶标约定。磁暴坦克在常规生产中的开放条件、苏联 RA3 科技与现有尤复科技的对应关系留待制作时确定。

| 待移植单位 | 官方对象及文件 | 首轮对照重点 |
|---|---|---|
| 磁暴坦克 | RA3 SDK `Soviet/Units/SovietAntiVehicleVehicleTech2.xml`，肖像和选中音均指向 TeslaTank | 2200／22秒／750血。追踪 TeslaGun 和 TeslaLinkGun 的目标过滤、武器状态与放电特效。 |
| 天启坦克 | RA3 SDK `Soviet/Units/SovietAntiVehicleVehicleTech3.xml`，选中音为 Apocalypse | 2000／20秒／3000血。普通／升级炮、Harpoon、牵引与碾磨状态分开验证。 |
| 收割者 | EA Uprising `Xml/EP1/Soviet/Units/SovietHeavyWalkerVehicle.xml` 及同目录 `SovietHeavyWalkerDeployedTurret.xml` | 1200／10秒／600血。追踪两种弹药、起跳、落地武器、断腿、替换为固定炮塔和死亡残骸。 |

### Insurrection 1.73 与既有来源

审计输入为本机 `C:/baidunetdiskdownload/Insurrection_1.73_SourceCodes.7z`，SHA256 `1b644b5f26955e334b5f82adb0063c944df5fa739b0d9b042a164c8310f1cd62`。比较对象为 EA RA3 SDK、EA Uprising XML 和 Bibber Upheaval 1.16 源包。以下以对象 ID、XML 调用与包内文件名为依据。素材计数限各自 Reaper 命名目录，本次未执行或导入 MOD。

| 对象 | 对照结果及用途 |
|---|---|
| 收割者规则 | 三份定义（EA 起义、Upheaval、Insurrection）的本体均为1200／10秒／600血。对应榴弹和火箭射程均225，两种弹头伤害／半径分别为15／20和7／10，跳跃武器射程350。官方本体通过 `ProjectileReplaceSelfSpecialAbility` 引用跳跃武器，替换目标为 `SovietHeavyWalkerDeployedTurret`。两个社区包的本体均引用中间对象 `SovietHeavyWalkerVehicleDummy`。实际移植按官方链验证落地与替换。 |
| 收割者素材 | Insurrection 的 Reaper 命名目录有42个 W3X、5个 DDS、103个 WAV，Upheaval 对应41、8、161。按 W3X 文件名集合比对，前者多出 `SUHEAVYWALKERVEHICLE_JMPC.w3x`。Insurrection 的 `Reaper/W3X.xml` 与 `GameObject.xml` 可追到 JMPA、JMPB 和 JMPC_LEGS，尚无启用单独 JMPC 的调用证据。两包声音和贴图数量不代表独立素材质量。 |
| 先锋炮艇 | 三份定义均为3600／40秒。官方与 Upheaval 生命5000，Insurrection 为4000。官方前机炮射程300，两个社区包均400；主炮射程三者均400。规则取官方，社区包辅助查模型、声音与开火挂点。 |
| 未来坦克 X-1 | 三者本体均为3000／30秒／3000血。Insurrection 定义了逐级扩散武器，例如第一、二段伤害／半径为20／24和19／37；Upheaval 的 IncrementalWeapon 定义为20／150。核对官方中子节点时须追踪各自触发链，勿按相似名称替换。IronTide 已确认的 Q 建筑伤害系数仍单独管理。 |
| 磁暴、天启与既有幻影 | 两个社区包均未找到这三者的独立同名单元目录。Insurrection 的苏联载具目录包含 Hammer Tank、Grinder、Reaper、Terror Drone 等修改。其它对象可引用基础游戏单位。磁暴和天启优先从 RA3 SDK 的上述对象定位资源，幻影沿用现有 SDK／起义资料。 |

## v0.5.7.5 三单位集中检查

后续 **v0.5.9.1** 已落实英雄第二跳、幻影附加FX与伪装变体、炮艇独立炮位、曲线炮弹及空中坠毁链。当前状态、原XML映射与剩余引擎边界见[差距补齐记录](RA3_COMPLETION.md)。下面的v0.5.7.5段落保留历史审计结论，不代表这些功能仍全部缺失。

幻影、未来坦克、先锋炮艇的来源、消费者、运行覆盖和明确遗漏统一见[三单位检查](RA3_THREE_UNIT_AUDIT.md)。本轮补齐未来坦克基础回血及 RA3 军衔经验栏文字，并新增生命周期／持续射击回归。原作差距仍包括幻影英雄第二跳、炮艇独立炮位及坠毁链，不将既有回归通过当作全部移植完成。下方各版本为历史记录，最新行为及证据以该检查和对应专项的新版本记录为准。

## 长期要求：逐项分析 XML，按实际调用补齐缺口

用户于 2026-10-28 明确要求所有 RA3 复刻逐项分析 XML 做了什么，再对照实现补缺。后续以单位／系统为范围追踪 Includes、继承、覆盖、默认值及引用链，建立“源文件／对象或字段 → 作用及触发条件 → 当前代码／资源 → 验证证据 → 缺口”的对应。检查相关模型状态、动画过渡和脚本、骨骼炮口、移动、武器、技能全周期、粒子材质、音效、出厂、死亡、晋升及英雄变体，不能只复制主文件数值或导入模型。

范围内有原版依据的遗漏主动补齐，不等用户逐个指出；仅 Include、注释内容、空事件或未被调用的素材不能自行启用。明确区分素材存在、运行调用已接、逻辑已验证、表现已获用户确认。无法确认的 SAGE CPU 行为及资源缺口逐项记录，标明 Godot 适配，不宣称原版一致。保留用户已确认的跨代定制；原版与定制冲突须说明后处理。本条是后续工作要求，不代表现有全部 RA3 单位已经完成全量审计。

## v0.5.4 Upheaval 受损状态对照与 GM 测试场

未来坦克与炮艇的受损烟火／贴图接到原骨骼和 ActiveBody 默认阈值；未来坦克 MaxSpeedDamaged=75% 接入实际移动。主菜单后台或 Ctrl+G 可直接测试单位、军衔、血量、冷却与敌方静止靶标；专用测试场不结算奖励。来源差异、明确适配和操作见 [RA3_UPHEAVAL_GM_AUDIT.md](RA3_UPHEAVAL_GM_AUDIT.md)。

## v0.5.0.9 Q 接近与伤害时序

以官方 BeamSpecialAbilityUpdate／LaserSweepWeapon 为权威，同时按用户提供链接下载并对照 Bibber Upheaval 1.16。新增 `ra3_riot_rules.json` 从 XML＋schema 默认值提取，`ra3_riot.gd` 接入真实移动命令、技能请求、投射物更新与存档。距离不足先接近，失败或取消不扣冷却；沿线伤害与延迟末端伤害各自维护固定时间事件游标。完整对照、已验证行为、保留的跨代规则及尚未确认的 SAGE CPU 几何见 [RA3_RIOT_AUDIT.md](RA3_RIOT_AUDIT.md)。

2026-10-28：riot 31、future_presentation 58、expansion 63、savegame 120、allied_abilities 200、native 93、future_glow 12，共 577 项通过，无脚本错误／泄漏；前后源码资源指纹一致，证据 `refs/ra3-expansion/riot-final/audit.json`。实际 Compatibility 图形测试使用既有隔离工程、独立用户目录；网络／服务／数据库为 none。逻辑测试通过，用户操作与表现仍为 `pending_user_visual_confirmation`。未提交、推送或打包。

## v0.5.0.8 中子球与质子炮材质对照

本轮按官方包目录、EA Uprising XML、零售材质常量和着色器逐项核对。修正 GPU 尺寸翻倍、透明度二次合成、FXLightning 边缘因子平方、随机 Alpha 固定取下限、GPU 颜色计算以及质子炮扰动公式。完整对应及剩余缺口见 [RA3_FX_AUDIT.md](RA3_FX_AUDIT.md)。下文旧版本的尺寸／深度缺口以本节为准：GPU Size 现在是完整宽度；球体补水平地面的解析交线，仍没有单位／建筑的 3D 深度。

2026-10-28 验证：fx_contract 19、future_presentation 58、gunship_presentation 40、future_glow 12、expansion 63、native 93，共 285 项通过，全部退出 0，无脚本错误或泄漏，运行前后源码／资源指纹无变化。证据 `refs/ra3-expansion/native-fx-final/audit.json`；普通攻击球和质子炮增加实际战场阶段截图。仅修表现，伤害节点、技能时序及原生 30 帧换算保持；不是完整原版引擎验收，状态 `pending_user_visual_confirmation`。共享工程已有另一项 v0.5.0.7 修复，本轮保留它并顺延到 v0.5.0.8。

## v0.5.0.6 Q 末端光晕过曝

用户反馈 v0.5.0.5 的 Q 末端强光遮挡目标。逐项核对：两个 LaserState 各自引用 AlliedFutureStartGlow / AlliedFutureGlow；末端 Lifetime=30、Size=20、BurstCount=1、ColorScale=10，炮口 ColorScale=5、BurstDelay=1..5。GpuParticle.fx / CommonParticle.fxh 在原引擎中以粒子颜色曲线和强度参与渲染，不能直接把这些高动态范围值当成普通 2D 画布的显示亮度。原移植直接把 RGB 乘 10 后加法混合，持续粒子又重叠，60 FPS 连续推进可复现大片饱和白色。

保留原始 XML、纹理、粒子数和寿命；仅在 `ra3_future_beam.gd` 的绘制端区分四个发射点，各点按存活粒子数归一叠加，使用保持色相的 `native_rgb / (1 + peak) * 0.35` 显示映射，叠加后仍按粒子年龄衰减。这是针对 Compatibility SDR 合成的明确适配，不冒称复刻了完整 SAGE HDR 曝光或软粒子深度。普通蓝色和英雄暖色都覆盖；激光本体 shader、扫掠、伤害和冷却不改。

新增 `ra3_future_glow_regression` 用同一批实际粒子重放旧绘制方法，与新方法比较渲染像素，覆盖连续发射、饱和白区域、保留可见光晕及停止后的渐隐；不以“截图非空”代替过曝断言。观感状态 `pending_user_visual_confirmation`。

2026-10-28 验证：光晕专项 12＋既有未来坦克表现专项 58，共 70 项通过，退出码均为 0，无脚本错误或资源泄漏，前后源码／资源指纹一致。相同粒子在隔离透明视口中每两像素采样：旧绘制普通／英雄有 4250／5742 个饱和白采样点，新绘制均为 0，仍有 2645／4318 个可见光晕采样点；实战阶段截图可见目标，不再被大白球遮挡。证据 `refs/ra3-expansion/future-glow-final/audit.json` 及两组 result.json、前后截图。Godot 4.7.2 Compatibility / WASAPI，沿用隔离工程及用户目录，无网络／服务／数据库依赖。仅表现合成变更，未扩大到战斗数值；未提交或推送。

## v0.5.0.5 未来坦克动画、Q 冷却与原生武器表现

来源仍为 EA Uprising 源提交 `3aad8e412961ab543192ae70f8503dc8e178e095`（正文权威来源节），核对 `AlliedFutureTank.xml`、`EP1/GlobalData/Weapon_EP1.xml`、`AlliedFutureTankNeutronScramblerNode.xml`、`FXListAllied.xml`、`FXParticleSystems/AlliedFuture*.xml` 和 `Laser.fx` / `FXShield.fx`。官方美术包不含未来坦克，实际模型／纹理／动画来自本机 Steam 起义，不是临时替代品。

- Q 冷却原来保存在 `special.ra3_riot_cd`，通用按钮却调用了默认零冷却的 Ability.ready。现在实际按钮、快捷键共用 RA3 info.ready，15 秒、施法后倒数及存档恢复经过真实 HUD 测试。
- `ra3_future_state.gd` 在真实 `_try_fire_ready` 消耗弹药之前执行新目标 0.1 秒预攻击，使用 ATKG；每炮使用原始 ATKE/ATKF 的 151 帧 30 FPS ONCE。工厂实际产出设置 JUST_BUILT=2.5s，播放 XMOVA，调试生成与读档不冒充出厂。
- 瞄准 Q 时正播 BATB，完成后静止保持 ATKD、移动保持 BATB 末帧；取消／收起倒播 BATB，部分展开反转从当前帧继续。移动、停止不再重置这一过渡。点击目标后的准备时间是 max(0.5s, 1s−已瞄准时间)，随后发射 1 秒、打包 1 秒。原 XML 的退出 Selected 分支只显式播放 ArmPrimaryWeapon；这里按用户要求统一补上倒播收起，是明确的 Godot 行为选择。
- 两个 `EXFutureTankCharge` 挂原 FX_Laser01/02，包含 Cylinder、Geosphere、Plane。Visibility 为连续浮点透明度曲线，不能按布尔值或 0.5 阈值隐藏。PREATTACK 播原速；攻击时两侧交替 4 秒正播／1 秒倒播。DefaultW3D 的 NumTextures=1 不再误乘第二纹理。开火光使用 AlliedFutureTankFireLight 的 3 帧、150 半径、原色与强度。
- Q 的两个 FX_WEAPON 骨骼是真实发射点。LaserDraw 的宽度 20 × 地图尺度 1.5、FXAlliedFutureLaser × FXAlienLaser、第二层 VTile=0.8/1、每秒滚动、普通／英雄 emissive 均已接入；Polygon2D 必须传像素 UV，shader 再接收规范化 UV。首尾原始光晕独立延续，攻击节点结束不会立刻切掉尾光。读档清理旧表现节点，活动攻击按保存时间重建。
- 普攻球补入原始 AURA＋GEOSPHERE，以及初始十个 Node、小光晕和两段光源。延迟 35/30 秒、大球寿命 40/30 秒、初始 scale=2、每原生帧增加 0.28、alpha 0.5→0，视觉不再跟伤害球 25→180 的半径绑定。普通／英雄分别使用原版素材；SDK 将 Hit_LightVet 引用到声明 Hit_Lightvet，索引按 SAGE 忽略大小写处理。实际伤害节点仍沿用既有 6 秒和伤害周期，本轮没有调整伤害。
- `ALL_FutureTank_PreFireChargeUp` 在原 SoundEffects.xml 和零售编译资源中都是空事件，候选 samples 被注释；保留该事实，不拼造充能音效。补入真正存在的武器切换及大小命中声，声音导出总计 119 段。

资源重建：先使用既有 `uprising/converted`，另以 `W3DContainer:FXFutureProjectile02(_Vet)?`、`Texture:FXAlienLaser`、`FXList:FX_Allied_FutureTank_Hit(Vet)?` 和 `FXParticleSystemTemplate:AlliedFuture(StartGlow|Glow)(Vet)?` 为 seed 提取至 `refs/ra3-expansion/future-extra` 并转换；随后运行 `python tools/ra3_mirage/import_future_presentation.py`、`python tools/ra3_mirage/extract_expansion_rules.py`。运行资源在 `assets/ra3/expansion/future/fx/`，provenance 记录原始容器、转换数据、XML 和生成 JSON 哈希，共 5 容器、13 网格、17 粒子定义。FXFutureProjectile02 的飞行网格也保留，但武器原速 999999 下仍采用瞬时到达，不人为延长飞行。

保留的适配边界：不是完整 SAGE CPU 扫掠轨迹／碰撞、所有动画混合、粒子解释器或场景深度实现；炮口／命中光源只照隔离 3D 对象，不能照亮 2D 战场。原资源按 30 FPS／秒换算，不套尤复 15 帧规则。状态 `pending_user_visual_confirmation`。

2026-10-28 最终验证：future_presentation 58、expansion 63、gunship_presentation 40、savegame 120、ra3_native 93、allied_abilities 200，共 **574 项通过**；六进程退出 0，日志无脚本错误或资源泄漏，前后源码／资源指纹无变化。新增专项通过实际武器入口、真实 HUD、独立光束像素、纹理滚动、部分展开反转、移动打断、英雄资源、保存冷却和活动光束恢复验证；球体视觉结束后停止空视口更新，保留伤害节点。53 个源文件及生成资源哈希核对一致。报告、阶段图和 audit.json 位于 `refs/ra3-expansion/future-presentation-final/`；Godot 4.7.2 Compatibility / WASAPI，隔离工程和用户数据同下文，无服务、网络或数据库依赖。主工程资源导入退出 0；未关闭现有游戏进程，用户需重启后新开战局确认画面。没有提交、推送或打包。

## v0.5.0.4 先锋模型状态、炮口与命中特效

权威仍是 `refs/ea-modding-support` 的 EA Uprising XML / Shaders（commit `3aad8e412961ab543192ae70f8503dc8e178e095`），资产来自本机 Steam Uprising 1.1。此次没有使用试玩版。`import_expansion.py` 保留原材质常量、UV2、顶点颜色、FXList 和粒子 XML 树及来源哈希，原始文件在忽略目录，运行资源在 `iron_tide/assets/ra3/expansion`。

- `AlliedGunshipAircraft.xml` 的 STATE_cannons / STATE_machinegun 的 AnimationName 都为空；虽 Include DEPLOY，状态并不调用它。已移除错误的模式动画，以 XML 脚本切换 SkinGuns、SkinMachinegun、Cylinder01。全部八个 SKN 子对象现已导入，FXMuzzleFront、FXMuzzle_FR/BR 和 FX_LIGHTS02 不再被通用 FX 过滤器删掉。被注释掉的 AUGunship_FX 独立 Draw 仍不启用。
- 炮塔按自然角 270°、两侧 45° 限制、180°/秒旋转；机炮 20°/秒俯仰且最低 -30°，对撞炮 180°/秒且最低 -45°、90% 高度瞄准。Godot 负责连续旋转插值。开火光源取 AlliedGunshipFireLight 的 3 帧寿命、150 半径和颜色；未假称恢复未知 CPU 的炮口寿命／后坐求解器，炮口网格采用短时闪光适配。
- `AlliedGunshipAircraftWeaponProjectile.xml` 的 onDeath FXList 现在真实触发。普通／英雄共 16 套命中 drawable 网格、两种弹体、16 条爆炸音频接入；每次陆地命中按原 BurstCount / SystemLifetime 创建 43 个粒子，包含十个系统，30 帧换算秒。冲击波的 X 轴沿向上速度旋转；材质移植 FXLightning 和 fxprotoncollider 的双纹理、世界坐标扰动、GammaToLinear、顶点颜色、`(OpacityOverride*3)-1` 遮罩偏移，不能改为普通透明度淡出。屏幕折射仍是 Godot 2D 合成适配。
- 命中节点归 Battle 所有，不随 Projectile 销毁，按各自寿命释放；16 个命中节点上限，几何/纹理缓存复用，一个爆炸一个视口，30 Hz 更新；视口按实际展开 AABB 调整，避免冲击波截边。读档清除旧时间线的纯表现节点。
- 机炮使用 FXTracer / FXTracerHeroic 的移动短曳光、原宽度/长度/速度/密度，独立于瞬时伤害节点；尾迹挂 FXCon_R/L，FireHawkConTrail 的 TrailLife=15、Size=1，停止后自然消退。补充三张纹理的本机提取在 `refs/ra3-expansion/gunship-trails`，需先以 `Texture:FXTracer(Heroic)?` 和 `FXParticleSystemTemplate:FireHawkConTrail` 为 seed 提取转换，再运行 importer。

仍未等同于完整起义引擎：BezierProjectile 的 FireStraightDistance/曲线追踪 CPU、准确后坐弹簧、独立炮塔 AI 扫描、DAMAGED/REALLYDAMAGED 烟火、水面专用爆炸和完整空中坠毁未在本轮补齐；当前伤害、射程、弹速、冷却、经验及飞行规则没有改动。新增表现需用户实测，状态 `pending_user_visual_confirmation`。

2026-10-28 最终验证：gunship_presentation 40、gunship_flight 15、flight_motion 810、expansion 63、savegame 120、ra3_native 93，共 **1141 项通过**，六进程全部退出 0，日志无脚本错误／资源泄漏。新增专项包含真正开火/切换、两个炮口显隐、侧向炮塔及俯仰、十系统命中、英雄材质、展开各阶段像素、渲染边界、遮罩渐隐、粒子释放、曳光、双骨骼尾迹和读档清理。报告与阶段图在 `refs/ra3-expansion/gunship-presentation-final/`，`audit.json` 的运行前后源码指纹无变化，生成资源哈希全部一致。Godot 4.7.2 Compatibility / WASAPI，既有隔离工程和用户数据；网络／服务／数据库为 none。共享工程其它未提交工作保留；本轮未提交、推送或打包。

## v0.5.0.3 先锋炮艇连续盘旋

官方 `AlliedGunshipAircraft.xml` 的 JetAI 使用 `GunshipJetAIStateMachine`、`NeedsRunway=false`、`AutoAcquireEnemiesWhenIdle=NO`、`CirclesForAttack=false`；Locomotor 明确 `MinSpeed=100%`、`MinTurnSpeed=100%`、`CirclingRadius=290`、`CirclingSpeed=80%`、`TurnTimeSeconds=2.5s`。通用 CirclesForAttack 布尔值不能代替该专用 CPU 状态机的行为。

本次删除该单位在射程内减速至零的悬停分支，专用 `ra3_gunship_flight.gd` 从现有官方规则数据消费盘旋半径和速度，按地图距离 1.5 换算：半径 435、盘旋 144/秒、转场上限 180/秒。实际位置沿限速转向的机头方向积分，炮塔独立瞄准；未把移动效果伪装为只旋转模型。到达指令表示加入目的地区域的等待圈，不再要求固定翼停在一个点上。S 取消攻击/路径任务但保留飞行速度，并建立附近等待圈。目标死亡、武器切换仍持续飞行；既有选择、射程、友军溅射和冷却判定不变。地图边缘将圆心内移以容纳整圈。

轨迹向量场、转场/到达定义和边界内移是明确的 Godot 适配，源 XML 不提供这些 CPU 方程。没有声称完整还原原版最低速度约束、JetAI、倾侧动力学或坠毁过程。持久状态仅在既有 special 中保存 `ra3_flight_center` / `ra3_flight_mode`，沿用真实位置、速度与朝向的存档字段。RA2 飞行控制保持原实现。

2026-10-28 验证：`ra3_gunship_flight_regression` 15、`flight_motion_regression` 810、`ra3_expansion_regression` 63，共 **888 项通过**。真实 `_physics_process` 推进待机整圈、攻击整圈与伤害、机炮切换、停止、移动、目标死亡、真实存读档和地图边缘；均保持方向/转速/速度约束。原有飞行测试只将 R3HARBINGER 的到达断言改为原生半径的等待圈，RA2 点到达/悬停断言保持。证据 `refs/ra3-expansion/flight-final/audit.json` 及各 suite；新专项输出 flight-traces.json。Godot 4.7.2 Compatibility / WASAPI，隔离用户目录同下文，无服务或数据库。实机盘旋观感仍为 `pending_user_visual_confirmation`。

## v0.5.0.2 未来坦克选择动画与官方包核对

已从 [EA 美术包镜像](https://www.cnclabs.com/downloads/details/1763/) 下载 `refs/ra3-expansion/official-art/UprisingArtSourcePack.zip`，19,312,713 字节，SHA256 `633fec2ca7acdb0208457af593a291292cb4d8ed233f8337463fcc38857967d5`。ZIP 目录实际核对共 299 项，只有 Archer Maiden、Steel Ronin、Mortar Cycle；不包含未来坦克。只保存包，不运行其中任何程序，不将包放入游戏运行目录。

规则依据是 EA 官方 [AlliedFutureTank.xml](https://github.com/electronicarts/CnC_Modding_Support/blob/3aad8e412961ab543192ae70f8503dc8e178e095/Uprising/Xml/EP1/Allied/Units/AlliedFutureTank.xml)；已用 ls-remote 核对远端 HEAD 与本地源一致。源码 TruckDraw 条件和本地 14 段原始动画逐一对照：缺的是调用，不是这些动画文件。

| 源动画 / 条件 | 当时情况（v0.5.0.5 更新见开头） |
|---|---|
| BIDA / STATE_Bored | 未选中待机，已接 |
| BATA / TRANS_boredToAttention | 本次补齐；选中从闲置过渡，31 帧 30 FPS |
| AIDA / STATE_SelectedPose | 选中待机已接；完整 15 帧混合/AnimationMustCompleteBlend 尚未复刻 |
| ABTA / TRANS_attentionToBored | 本次补齐；取消选中后收起，46 帧 30 FPS。XML 也允许打断正在展开的 BATA |
| MOVA / MOVING | 已接；移动优先，可打断选择过渡，停止后按选择状态进入待机/收起 |
| XMOVA / JUST_BUILT | 素材已导入，出厂专属条件尚未接 |
| BATB / 两个 LaserWeapon 过渡 | 素材已导入，Q 准备正播与退出倒播尚未接；当前仍直接切 ATKD |
| ATKD / SPECIAL_POWER_SELECTED_PENDING、USER_1 | 当前仅施法后的姿态已接，瞄准期间的 MANUAL 末帧调用链不完整 |
| ATKG / PREATTACK_A | 素材已导入，预攻击循环尚未接 |
| ATKE / ATKF / ATTACKING + 枪管编号 | 已有攻击入口，但原完整 ONCE 时长、预充能声与 charge 特效链不完整 |
| ATKA / ATKB / ATKC | 在 Includes 中，但当前官方 TruckDraw 没有 AnimationState 使用；不凭文件名自行播放 |
| EXFutureTankCharge | 副 Draw 的原版充能特效模型/动画，未接完整状态链，不属于这 14 段主体动画 |

本次只修选择表现，不改武器、攻击结算或技能时序。测试使用真实 Battle 选择/清选入口，校验 BATA/ABTA 时间边界、实际枪臂骨骼变动、渲染像素差异、快速切换和移动打断。Godot 4.7.2 Compatibility，隔离项目与用户目录同下文；`refs/ra3-expansion/selection-animation/` 中 63 项通过，退出码 0，无脚本错误或资源泄漏。四张 `future-*.png` 已人工查看；最终状态仍为 `pending_user_visual_confirmation`。

## v0.5.0.1 UI 图用途修正

按用户确认的 IronTide 用法，RA3 幻影、未来坦克、先锋炮艇：生产卡片及生产队列使用 `Portrait`，选中单位列表使用原版 `Button`（幻影资源文件名为 `cameo.png`）。资源包 `art.portrait` 明确登记生产头像，`art.cameo` 保留按钮图；缺少 portrait 的 RA2 单位继续使用原有 cameo。共用 UnitIcon 由生产调用点显式传入用途，不再硬编码幻影坦克的覆盖图。没有更改基地科技分组。

图形专项 `ra3_presentation_regression` 110 项通过，含三种 RA3 单位及 MTNK 的真实生产卡片、队列、选择图标资源路径；Godot 4.7.2 Compatibility，无脚本错误或退出资源泄漏。证据 `refs/ra3-expansion/icon-fix/result.json` 与 run.log。原图已人工查看，最终缩小效果仍待用户实机确认。

## v0.5 的入口

选择 **Iron Tide 扩展**，使用盟军。选中已建成的基地，在单位信息区购买高级许可，再购买最高许可；建造作战实验室后，可在战车工厂生产未来坦克，在空指部生产先锋武装炮艇。

| 内容 | 金额 | 1 倍速时间 | 前置 |
|---|---:|---:|---|
| 高级许可 T2 | 1500 | 15 秒 | 已建成盟军矿石精炼场 |
| 最高许可 T3 | 3000 | 60 秒 | 当前基地 T2 |
| 未来坦克 X-1 | 3000 | 30 秒 | 工厂获得 T3、作战实验室 |
| 先锋武装炮艇 | 3600 | 40 秒 | 空指部获得 T3、作战实验室 |

按用户确认，现有作战实验室兼作 Defense Bureau；没有新增防卫局建筑。RA3 幻影坦克改走 T3，不再额外要求作战实验室。RA2 单位的科技前置不变。许可属于本局基地对象，独立于局外养成；按源 XML 的矩形范围投射给附近生产建筑，源码半径 600 换算为地图坐标 900。基地收起时保存许可但停止投射，重新展开恢复投射；摧毁或离开投射范围会阻止对应生产。

升级逐步付款，无钱停顿。按钮右键第一次暂停、第二次取消退款，暂停后左键继续。许可、升级进度、单位模式、弹匣和在途攻击使用已有存档字段；规则变更前的存档仍遵守原内容指纹检查，不保证旧版本存档可载入，建议新开战局。

未来坦克 Q 为指定地面位置的暴乱光束，准备、交叉扫射、收起后恢复普通攻击。先锋炮艇 Q 在双对撞炮和前部机炮之间切换；两种武器均为对地，使用独立弹匣自动装填，不使用尤复机场回补弹药。原版头像、按钮、语音、车辆骨骼、履带、炮口和 COL 碎块已接入。晋升使用 RA3 三档图标、经验与倍率。

## 权威来源与重建步骤

规则、动画调用与着色器参考 EA 官方 [CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support/tree/3aad8e412961ab543192ae70f8503dc8e178e095/Uprising)，本轮固定提交 `3aad8e412961ab543192ae70f8503dc8e178e095`。本地只读源位于 `refs/ea-modding-support/Uprising`。模型、贴图、音频来自本机 Steam 起义 1.1；不是试玩版，也没有临时模型替代。

1. 从 `Xml/EP1/Allied/Units/AlliedFutureTank.xml`、`AlliedGunshipAircraft.xml` 列出模型、骨骼、武器、SpecialPower、声音、死亡 OCL、升级和生产前置。追踪 `Weapon_EP1.xml`、`ExperienceLevels_EP1.xml`、基础 Armor、Upgrade、AttributeModifier 及继承关系，不只抄主单位数值。
2. `extract_uprising.py` 按显式名称种子提取并遍历资源引用；保留 extraction.json 的归档来源及哈希。
3. `convert_uprising_media.py` 解码原始资源；音频用 vgmstream。保留转换清单，HDR DDS 的 PNG 预览不替代原始 DDS。
4. `import_expansion.py` 转换皮肤、骨骼、动画、COL、图标和原版特效模型；输出 `assets/ra3/expansion`，保留 provenance.json。`extract_expansion_rules.py` 生成两单位配置、规则证据、装甲对照和 89 段语音/音效。
5. 在 GameData 中限定资源包命名空间；注册生产、技能布局、目标域、伤害、模型/选择/炮口、晋升、残骸、保存状态。所有时间使用秒，不套尤复 15 tick 的武器/移动转换。
6. 运行真实 Battle 专项，验证前置、付款、命令、伤害、存读档、取消/死亡、模型像素；再运行原幻影、生产、保存和晋升回归。最后由用户验收画面、音效和手感。

从仓库根执行（替换自己的合法游戏目录及解码器路径）：

```powershell
python tools/ra3_mirage/extract_uprising.py --game "C:/Program Files (x86)/Steam/steamapps/common/Command and Conquer Red Alert 3 Uprising" --output refs/ra3-expansion/uprising --pattern "FutureTank|Gunship|AlliedTech[23]|UpgradeMortar"
python tools/ra3_mirage/convert_uprising_media.py --source refs/ra3-expansion/uprising --audio-decoder refs/ra3-mirage/vgmstream/vgmstream-cli.exe
python tools/ra3_mirage/import_expansion.py
python tools/ra3_mirage/extract_expansion_rules.py
```

源码和生成资源进入 Git；游戏安装包、原始提取缓存和临时测试项目不进入 Git。

## 避免重犯的格式问题

- 编译后 mesh 顶点已经包含 FixupMatrix 作者缩放，再乘一次会把未来坦克炮塔拉长。本轮所有主体网格重建边界与原始编译网格相差小于 0.002。
- 无蒙皮网格不能全部挂在根骨骼。必须读取 W3DContainer 的子对象 BoneIndex，例如 COL.TREADS。
- Poid 骨骼名称是大小写折叠后的 SuperFastHash。保留原始哈希，按 XML 名称解析，不能猜编号。
- Timecoded 动画是 frame_and_binary_flag 与平铺 values；Delta 动画用既有解码器。统一 SAGE XYZ → Godot x,z,-y，同时转换四元数、法线、绕序、绑定姿态。
- 同一套模型投影用于绘制、鼠标命中和枪口；不要另外凭肉眼写枪口坐标。纹理/网格共享，动态骨骼与视口按单位独立，30 Hz 更新且离屏停绘。

## 明确的适配边界和后续缺口

这是一版可试玩移植，不是完整 SAGE CPU 引擎复刻。规则数字和原始素材有来源，以下部分不能宣称和起义实机完全一致：

- 距离统一乘 1.5；跨代攻击沿用用户批准的角色护甲和基准血量归一化，保留尤复目标血量及其它防御规则。原生 RA3 目标不套这层血量归一化。
- DamageSphereUpdate 未公开内部 CPU 伤害更新频率；当前将 XML 明确的展开前 0.25 秒周期延续至展开后。球体六秒寿命、1.35 秒展开、25→180 半径、125/秒扩张有源数据。不能据此声称完整伤害节奏已对齐。
- 交叉光束的连续世界扫掠/命中为独立实现；未来坦克主武器、Q、充能和英雄粒子已在 v0.5.0.5 接入，未实现通用原版粒子解释器。先锋的命中系统已在 v0.5.0.4 接入，见开头。原版 FXShield 的双纹理、噪声位移、边缘 LUT 已移植；原版场景深度交叠高亮无法在隔离 3D 视口中读取 2D 战场深度。
- 先锋在 v0.5.0.3 改为按源半径/速度持续盘旋，见本文开头；没有复刻完整 JetAIStateMachine、倾侧动力学和原版空中坠毁过程。当前死亡显示原始 COL 碎块，碎块运动为 Godot 表现适配。
- 导入了未来坦克 14 段动画、炮艇 DEPLOY；未来坦克未完整移植所有条件/过渡状态；炮艇按实际 XML 状态调用切换子对象，不再播放仅 Include 但未调用的 DEPLOY。音效池保留原始声音，但多层 Multisound 暂折为采样池。
- 原版许可图标 Button_UpgradeMortar 未在本次提取中找到；许可按钮使用明确文字，不伪造原版图标。

主要实现：`ra3_clearance.gd`、`ra3_clearance_panel.gd`、`ra3_expansion.gd`、`ra3_expansion_model.gd`、`ra3_expansion_fx.gd`、`ra3_wreck.gd`。新增专项 `tests/ra3_expansion_regression.tscn`。表现验收状态：`pending_user_visual_confirmation`。

## 本轮验证与交接

2026-10-28，原 checkout `C:/Users/admin/IronTide`，分支 `codex/ra2-independent`。共享工作区已有大量未提交修改；本轮没有提交、推送或重新打包，保留其它工作。

Godot 4.7.2，OpenGL Compatibility，RTX 5060 Ti，WASAPI。隔离项目 `refs/ra3-mirage/integration-test/project` 的代码/数据/资源指向本工作区，用户数据 `CodexIronTideValidation/ra3-mirage-20261027`；无网络、数据库和服务依赖。7 组图形回归：expansion 53、cloak 34、uprising 43、native 93、production_hold 72、savegame 120、veterancy 126，共 **541 项通过**；退出码全部 0，日志无脚本错误或资源泄漏，测试前后脚本、着色器、配置、RA3 资源和测试源码指纹无变化。项目版本标记随后仍为 0.5；隔离测试项目自己的旧版本文本不参与规则执行。

报告和图形采样：`refs/ra3-expansion/validation/audit.json` 及各 suite 子目录。执行器 `refs/ra3-expansion/run_validation.py` 是本机临时编排，不作为可交付源码；可复用的测试源保留在 `iron_tide/tests/ra3_expansion_regression.gd/.tscn`，用既有隔离测试流程加载场景。最后一轮前修正了 Node2D 的 material 属性重名；早期失败输出不作为通过证据。既有 uprising 图形测试须给视口真实渲染时间，不使用固定 60 FPS 强制推进五帧替代 0.1 秒刷新窗口。

交付检查发现共享 selection_regression.gd 在首轮结束后更新，因此对当前工作区重新跑完上述 7 组；仍为 541 项通过，最终运行期间和结束后复核均无源漂移。报告已以这次重跑为准。

用户待验收：许可入口是否方便，未来坦克炮口/扫射/扩散球、炮艇高度/侧向攻击/切换动作、语音及帧率。下一轮优先完善上面的原版动画条件链、完整粒子及 JetAI 适配，不把这次 541 项通过写成这些未覆盖项目已还原。


## 2026-10-28 · 炮艇武器表现后续 v0.5.6.2

Upheaval武器状态、原始资产、未确认的CPU边界及本轮验证见 [RA3_GUNSHIP_WEAPONS_AUDIT](RA3_GUNSHIP_WEAPONS_AUDIT.md)。机枪新增普通／英雄命中效果；爆炸采用屏幕像素密度自适应离屏缓冲。7组431项通过，但观感仍待用户确认。不要把待机扫描角度当作炮台攻击角限制；不要把伤害半径当作视觉波纹半径；图集shader选帧不会改变Sprite四边形尺寸。

### 收割者跳跃部署（v0.11.1.3）

- 《起义》EP1 的 `SovietHeavyWalkerVehicle.xml` 将双倍速 JMPA 绑定到 UNPACKING、循环 JMPB 绑定到 THROWN_PROJECTILE，另列 PackTime=3s；共用 schema 的 UnpackTime 缺省为 0。新跳跃从指令生效立即播放 JMPA，第 35/30/2 秒到达最后一帧并起飞。旧版将 3 秒 PackTime 用作起跳前等待，现仅为已在途的旧存档保留这个时钟。该起飞点是 IronTide 对齐动画与位移的适配，未用零售实机逐帧测时。起跳武器速度为 300，贝塞尔控制点在距离的 40% 和 60%，高度 150–160、100–110，项目按 1.5 换算距离及弧长。
- 部署建筑的 CAN_ATTACK 和独立武器组通过建筑选中与命令入口使用。单选落地后保留选择，右键敌人或 A 点目标通过炮台射程与目标类型判定；手选敌人优先于自动扫描。
- 部署建筑 XML 的有效默认姿势是 AIDB，JMPC 所在的 STRUCTURE_UNPACKING 块已被注释。落地另由 SUHeavyWalkerVehicle_Legs_OCL 创建 JMPC_LEGS，单独使用其零售模型、骨骼动画和消退时间。触地伤害和替换按同一模拟事件执行。
- 骨骼平移增量须经该关节的静置旋转换算。可交叉对照 EA 公开的 [W3D HTree 动画矩阵实现](https://github.com/electronicarts/CnC_Generals_Zero_Hour/blob/main/Generals/Code/Libraries/Source/WWVegas/WW3D2/htree.cpp#L420-L427)。本轮在收割者本体与落地腿部复核了这一点。短跳、满距离跳跃和腿部清理由 ra3_reaper_jump_regression 覆盖，在途存读由 ra3_soviet_regression 覆盖。

### 天启与磁暴坦克的战斗表现

以《起义》SovietAntiVehicleVehicleTech2 / Tech3.xml、Weapon.xml、苏联炮弹对象、DamageFX.xml 和各自引用的 FXList、FXParticleSystem、Shader 为源。导入工具 import_soviet_weapons.py 保存 XML 和三个相关着色器的 SHA-256，网格、纹理、音频从本机《起义》提取。

| 原版触发 | IronTide 实现及验证 |
| --- | --- |
| 天启 ShotsPerBarrel=1、B_BARREL、FX_MuzzleFlash | 双管分开计时，普通和英雄发射不同的 FX_AlliedTankGun 列表。射击测试读取实际骨骼变换、两个炮口世界坐标和原版炮焰纹理。 |
| 普通／英雄炮弹的 Model 均为空 | 弹体模拟飞行，按载具正侧后命中、其他单位命中、普通落地和英雄 onDeath 分派列表。英雄军衔在出膛时锁定。 |
| WEAPONSTATE_ONE 与 LaserState | DOOROPEN 正倒播，进行中反向沿当前帧返回。牵引由 FX_Harpoon 连到目标，读取三层 Laser.fx 宽度、滚动速度与材质，接上端点粒子及接触研磨。 |
| 磁暴主武器与 TeslaLinkGun | 两次射击交替使用 FX_Weapon_01、02。每发包含两组各两层的 TeslaFireLightning，伤害调用 FX_TeslaHit。给友方线圈充能时跟随线圈顶部。XML 中磁暴炮后坐骨骼被注释。 |
| 磁暴 WEAPONSTATE_ONE、两车 MOVING、ACCELERATE、DAMAGED、REALLYDAMAGED | 短路按原版 EXLIGHTNINGRING 发散，履带区分左右转，排气和受损粒子按绑定点生成，修复后恢复正常贴图。天启受损骨骼来自单独的 Tech3_FX 骨架。 |

无窗口回归入口为 ra3_tank_weapons_regression、ra3_soviet_regression、soviet_defense_regression、ra3_reaper_jump_regression。第一项直接构建真实骨架与材质检查，两车的特殊状态和中途读档也通过同一入口。Godot 的后坐回弹、二维轨迹、粒子混合及侧后命中表现角度为适配；本次未逐帧对拍零售版。原版手柄震动、模式循环音和特殊命令语音未在这次视觉修复中接入。

- 短路武器 SovietHeavyAntiVehicleInfantryShortCircuit 在《起义》Weapon.xml 中设置 ParalyzeType=EMP、DurationSeconds=1.1s 和 ParalyzeFX=FX_None。IronTide 在实际受瘫痪的敌方载具上附加等时长的电弧和状态提示。发射端继续使用 SovietTesla_EMP 的 EXLIGHTNINGRING。RA3 模型的选中遮罩仅渲染实体网格，武器、火光、电环和后加的粒子不进入描边。

### 收割者协同瞄准

这是扩展模式的收割者专属天赋。在「驻防基地 → 商店」每 1200 军需券兑换 1 个通用天赋点，在「单位改造」选中兵种后开启天赋格。各兵种初始 0 格，第 1 格 1200 军需券，第 2 格 2400 军需券。每项天赋占用 1 格和 1 个通用天赋点。「协同瞄准」与「分区射击」各自永久占用已投入的点数和格子，效果可独立开关，新对局读取启用状态。旧版已购买的科技迁为已分配，并退回原价 1200 军需券。移动收割者停下交战时、部署炮台持续交战时都可转向当前地面目标。起义 SovietHeavyWalkerWeaponSet.xml 中三门榴弹炮的自然朝向为 0°、270° 和 90°，各可向两侧偏转 90°。正前方是三门射界的交点。行走与部署形态共用 XML 导出的炮位偏角；开火与模型转向读取同一对机械限位。榴弹与火箭均使用 Weapon_EP1.xml 中 20 至 225 的射距（地图距离 30 至 337.5）。车体按现有转速逐步对准，移动命令与对空火箭不依赖该转向，四个炮位仍按各自的射界和装填开火。

「分区射击」是 Iron Tide 扩展天赋。玩家手动指定主攻击目标后，移动与部署形态的 E 才可用。自动索敌不解锁 E。瞄准时显示左右侧炮的原生射界，左键指定扇形内另一名可见地面敌人，右键或 Esc 取消选点。每次只抽调覆盖副目标的一门侧炮；两侧均可覆盖时优先选空闲侧炮。主目标在空中时，0 级天赋即允许未被 E 占用的榴弹炮自动攻击各自射界内最近的可见敌方地面单位，自动选点排除建筑。导弹保留空中主目标。对地主目标仍按原射界分配。各炮保留自己的装填进度。选点和有效分火期间暂停协同转向，副目标离开可用射界或主目标改变时恢复。

### 天启坦克行驶碾压

《起义》SovietAntiVehicleVehicleTech3.xml 的 CrusherInfo 为攻击等级 30、自身抗性 31、碾压减速 80%。Weapon.xml 的 SovietCrushWeapon 基础 CRUSH 伤害为 999999，并带 IGNORE_WALL_RELATIONSHIP。BaseVehicle 的常规抗性为 20，BaseWallPiece 为 25；未来坦克为 31。普通建筑不满足条件。天启继承 BaseVehicle.xml 的 CrusherInfo.DefaultCrushKillDelay（1.5 秒）；Steam《起义》1.1 的天启编译对象也包含该值。SIMPLE_OBJECT_PROP 另有 0.5 秒规则，当前可碾单位与围墙不属于该类。铁潮在前进方向持续接触同一可碾目标时计时，期间暂停卡住绕行，命中后按本车的加速规则恢复；不会隔着单位或建筑扫描击杀。

混战时，尤复天启、战斗要塞以及 OmniCrushResistant 单位保留抗性，其他地面步兵、车辆按类型映射。只有 RA3 天启的陆地路径把墙视为可穿越；保持水域、建筑和岩石遮挡。行驶碾压独立于鱼叉牵引和研磨。专项 ra3_apocalypse_crush_regression 从移动命令验证实际碰撞、死亡、经验、墙体和寻路。

## v0.12.1.9 苏联车辆表面

天启、磁暴坦克及收割者的 ObjectsSoviet 和 ObjectsAlliedTread 材质以 EA《起义》Shaders/Objects.fxh 的 PS_H、RotateEnvironmentMap.fx 和 SDK GlobalData/EnvironmentMaps.xml 为对照。Steam 1.1 的 Shaders.big 中 objectssoviet.fxo 的高画质像素程序也使用环境立方体、法线及反光遮罩。环境图取自 StaticStream.big 的主 static 流 Texture:EVDefault，保留内嵌 DDS 的全部字节，SHA-256 为 92c5f96fc442cc5a1eaa92d192b8223c27c7639166dd9e49b50d258cfa78a62b。运行时按六面 64×64 RGBA 半精度读取，使用当前地图下午光照，并按视角把反射变换到主光源坐标系。

Godot 表面着色器使用 SPM 红通道控制环境反射、蓝通道控制阵营染色，法线切平面分量乘 1.5，按材质开关应用 96/255 透明阈值。使用项目的切线、相机与色彩输出适配；原版全场景阴影、遮蔽及后处理未在此版本复现。ra3_model_resolution_regression 包含立方体格式、履带透明测试和受损贴图切换检查。

## v0.12.1.12 盟军车辆与炮口照明

《起义》ObjectsAllied.fx 和 ObjectsAlliedTread.fx 与 ObjectsSoviet.fx 共同包含 Objects.fxh。盟军与苏联的高画质路径都用 1.5 法线强度、0.1 环境光系数和 SPM 红通道调制的环境反射。材质读取运行时模型的 AlphaTestEnable；幻影在原始 NEWSKIN、NEWSKIN_TREADS 上均启用。DefaultW3D、MuzzleFlash 等单独的武器网格继续用其原映射。点光的漫反射角度和平方距离衰减对照 Common.fxh 的 CalculatePointLightDiffuse；位置、颜色、亮度随原有炮口骨骼和三帧开火状态更新。

FXLenzflareHDR01.dds 直接使用本机 StaticStream 的半精度纹理，覆盖命中与坠毁粒子的纹理入口。ra3_gunship_weapons_regression 从实际炮艇命中粒子材质读回峰值 2.736328125。验证的是材质输入，场景曝光与最终颜色映射仍是 Godot 适配。ra3_model_resolution_regression 的盟军案例比较同一姿态启用和关闭炮口点光时的实际渲染像素。

## v0.13 机体受影与局部强光测量

Objects.fxh 高画质路径把主方向光的漫反射及环境反射乘阴影系数。这里由 Godot 主光源生成动态几何阴影，环境光、补光和炮口光单列。遮挡保留比例使用 lighting.json 的 0.5。单位投到平面地表的轮廓继续使用原有实现。建筑是二维图像，机体接收的建筑阴影使用只投影的体积，平面尺寸来自实时占地，高度来自 RA2/YR artmd.ini 中美术小节的 Height。shadow_heights.json 保存 31 个建筑类型，12 模型单位／级为本项目比例。每个机体使用附近最多四个可见、建成的遮挡建筑；飞行高度用于相对地面位置，屋顶细节不在这个近似内。

Uprising InGame.scrape 和 PostFX_LookupTable.fx 把战场曝光置于后处理阶段。Godot 在 HUD 下方的画面层按亮粒子的亮度、投影面积与屏幕交集做事件测光，响应与恢复时间常数分别为 0.045 与 0.32 秒，最大压低 0.85 档。这是 SDR 输出的适配，未运行 SAGE 全帧 HDR。未来坦克的持续中子节点只驱动特效视口的局部点光，不参与全战场测光；普攻与 Q 的远处地面亮度由 ra3_future_glow_regression 采样验证。ra3_scene_light_regression 校验真实渲染像素、阴影随建筑移动、飞行高度、屏外闪光、HUD 隔离、暂停与存读清理。
