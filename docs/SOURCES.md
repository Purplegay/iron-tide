# 来源记录

参考仓库：[huangkaoya/ts-redalert2](https://github.com/huangkaoya/ts-redalert2)，固定版本：
`898d89188542a3028a232031ce1a0bdc7c605b6f`。

该版本 [LICENSE](https://github.com/huangkaoya/ts-redalert2/blob/898d89188542a3028a232031ce1a0bdc7c605b6f/LICENSE)
明确声明：其中 Chrono Divide 派生材料未获权利人许可，不能依据仓库 README 将整仓视为 GPL 授权。
它也不是 EA 发布的 RA2 官方源码。

用户已确认改为 Godot 独立实现机制与行为对照。本次新规则策略、回归及修复未翻译/复制参考项目的实现。
`refs/ts-ra2` 作为本地固定参考，不纳入游戏加载或源码发布。

已有游戏源码、数据转换工具、`tools/ra2bundle.mjs`、INI、图片和音频均从用户原工作区接管。
历史工具与资源的完整权利链尚未核验；本次接管不为它们新增授权。`ra2bundle.mjs` 仅保留为历史提取依赖，
当前游戏运行、机制测试和 INI 导出不依赖该 bundle。

`source-lock.json` 记录本次参考版本、许可证及关键本地输入哈希。资源恢复只针对原本已有本地导入缓存，
验证恢复前后的解码像素一致；这不是下载新素材或许可证明。

## 尤里的复仇机制参考（2026-10-21）

用户指定 [Ritanlisa/RA2YR_ReSource](https://github.com/Ritanlisa/RA2YR_ReSource)，
已克隆到被忽略的 `refs/ra2yr-resource`，固定 `b01d3cf93db69aca9b5cb5054ba04e4358963828`。
仓库自述为从 `gamemd.exe` 逆向重建 C++ 引擎；不是 EA 发布的 RA2/YR 官方源码。
其 LICENSE.md 声明 GPL v3 和 EA 附加条款，文件开头描述 EA 开放的 Command & Conquer Red Alert；
这不作为尤复游戏美术、音频或逆向材料的统一授权证明。许可原文件哈希记录于 source-lock.json。

本地核对发现 GetWeapon、加特林升速、奴隶转移等接口仍为空实现；可编译不等于完整行为可用。
该 checkout 不含 rulesmd.ini、artmd.ini、MIX、SHP、VXL 游戏资源。
仅作为后续机制定位资料，未编译/执行其 EXE、DLL 或注入工具，未复制/翻译其 C++ 实现进入 Godot。
独立实现路线不变。接入进度、缺失输入和检查入口见 [YR_INTEGRATION.md](YR_INTEGRATION.md)。

## 2026-10-26 海军朝向与普通生产资格

`ra2pipe/vehicle_facings.mjs ... naval` 从用户已安装的 Steam 尤复 MIX 读取 DEST/AEGIS/CARRIER/LCRF VXL 和
unittem.pal，独立重新渲染 32 个朝向及共用画布的阴影；未插值补帧，未改海豚原 SHP 动画。
候选目录的 source-audit.json 记录五个输入和十六个产物哈希；生成输出须是仓库/游戏安装目录以外的新目录。

`ra2pipe/production_rules.mjs <YR目录> <新candidate.json>` 只提取现有盟军目录 30 个单位的 TechLevel、Spawned、
RequiresStolen*Tech，导入为 data/yr_production.json，不替换战斗表和已有单位身份。
来源 rulesmd.ini（expandmd01.mix），SHA256 为
3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef。
实际禁止普通生产的场景单位 CDEST TechLevel=-1；CCOMAND 要求 AlliedTech，PTROOP 要求 ThirdTech。
秘密科技渗透尚未实现，当前只展示原因并阻止无条件生产，不宣称已经实现秘密兵种解锁。

2026-10-26 后续模型核对：`vehicle_facings.mjs ... all` 已使用本机 VXL/HVA 重新生成全部 61 个单位目录项，
同时处理 FV 换装炮塔；夜鹰使用原 HVA 两个姿态。布局来源、算法修正与仍存在的原版渲染差异见
[MODEL_RENDERING.md](MODEL_RENDERING.md)。这取代前述只对四艘船进行 32 朝向转换的素材状态。

2026-10-26 精英武器：`ra2pipe/elite_weapon_fixture.mjs <本机尤复目录> <不存在的fixture.json>` 从 MIX 内的
rulesmd.ini 读取 31 个单位和 70 个关联武器的原始字段，保留弹头/弹体与来源哈希，独立于运行时归一化数据。
夹具为 `iron_tide/tests/fixtures/elite_weapon_source.json`，SHA256 仍为上列 3d341e…72ef。
BFRT 有 VeteranAbilities/EliteAbilities 而没有 ElitePrimary；HORNET 有 ElitePrimary=HornetBombE。
Para.Anim 是八向 MGUN，105mmE/SABOTE 的 Anim=VTMUZZLE，GRIZAPE/UltraAPE 的 AnimList=VTEXPLOD。
这些事实来自本机配置；没有把网上模组新增行为当作尤复原版规则，也未改动持久化配置摘要所依赖的数据表。

## 2026-10-26 支援建筑和闪电风暴资源

本机 Steam Yuri Revenge（Command & Conquer Red Alert II）为规则与素材来源。新增独立导出器 ra2pipe/support_assets.mjs，输入本机目录，输出全新的外部候选目录；不覆盖原始 MIX。rulesmd.ini 来源 expandmd01.mix > 0x8218f9f4，SHA256 3d341ef8a13a4b5ab24af2eef48ac94931ac2bb87d950fe3330a07e2d25672ef。按原始字段导出 PrismSupport*、Chrono* 和 GAGAP/GASPYSAT/GADEPT/GAOREP 到 support_rules.json。

新增 WCCLOUD1/2/3 与 EXPLOLB SHP 图集，记录原始 SHP SHA256。artmd.ini 的云层 AltPalette=yes 对应 UNIT 类调色板，本机温带使用 UNITTEM.PAL；初版统一 ANIM.PAL 产生黄绿色边，渲染发现后已修正。EXPLOLB 使用 ANIM.PAL。Rate/60 沿用项目动画时间适配；云层 Rate=375 -> 6.25 fps。并非原引擎光照/透明混合逐像素复现。

候选和八项输入指纹：C:/Users/admin/Temp/iron-tide-support-assets-20261026-v2/source-audit.json。运行时代码为独立 Godot 实现；只核对本机 INI 字段、SHP/PAL 格式与参考实现对 AltPalette 的解释，没有搬运受限参考仓库派生代码。

## 2026-10-26 飞机弹药图标

新增独立提取器 ra2pipe/ammo_pips.mjs，从本机 Steam 尤复 MIX 导出 PIPS2.SHP 第 12 帧及 PALETTE.PAL，保留原始 6x13 像素。资源和输入档案/哈希记录在 iron_tide/assets/ra2/pips/ammo.png、ammo.json。SHP SHA256 为 0afe9935160c04bdabed5bfefd0d55aad645ae38ec7dddeb5b3f4f2b2d2712d4，PAL SHA256 为 e85c535002573b5f95f7c361c4bdb95ee43e4914ddc926afda9ace995c54242b。

参考资料仅用于核对图标帧、调色板、选中/悬停与逐发显示约定；Godot 绘制逻辑独立实现，位置按现有血条与镜头适配，不声称与原引擎位置逐像素一致，未复制受限参考仓库渲染实现。

2026-10-26 出售动画：复用已提取的本机原版建筑 Buildup SHP 和 General.BuildupTime。参考实现元数据中 UNBUILD 与 BUILDUP 使用同一 Buildup 资源，UNBUILD 设置 Reverse=yes；据此独立实现 Godot 逐帧倒放，未复制参考渲染器代码。独立视觉节点不改变当前出售退款/移除时机，不声称完整复刻原引擎出售模拟时序。

2026-10-26 导弹轨迹显示：复用本机原始 artmd 的 UseLineTrail/LineTrailColor/LineTrailColorDecrement/Rotates 与已有 DRAGON/MEDUSA 32 帧图集。逐帧检查本地原图确认 0 北、8 西、16 南、24 东；旋转与渐隐由独立 Godot 代码实现。抬升曲线为展示层适配，不是对受限参考仓库 MissileLocomotor 代码的翻译，也不声称复刻原始三维加速/锁航向物理。详细参数和保持不变的判定边界见 VERIFICATION 对应小节。

### 2026-10-26 空旷地载具转弯适配
保留已有原始 ROT 换算和移动速度（本地 refs/ts-ra2/src/game/rules/ObjectRules.ts 旋转单位说明作为对照），不复制参考实现。vehicle_steering.gd 的导航走廊、实体净空判定以及 35°/65° 自适应减速包络是独立 Godot 实现；没有将它描述为尤复原始 locomotor 的逐行复刻。证据和边界见 VERIFICATION.md 同日载具转弯条目。

### 2026-10-26 移动命令线
只读核对本地 refs/ts-ra2/src/engine/renderable/entity/WaypointLines.ts 与 WaypointLine.ts 中的源点/当前目的地/后续点组织、黄绿色虚线及固定屏幕线宽表现。未搬运其代码；Godot MovementOrderPreview 直接读取本工程 move_target/order_queue，使用独立 draw_dashed_line 绘制。为己方选中命令持续显示，当前没有复刻参考实现的流动虚线动画。说明与证据见 VERIFICATION.md 同日条目。

### 2026-10-26 飞行速度与飞行兵朝向
本地 data/ra2/units.json 的原始规则：JUMPJET JumpjetSpeed=30、JumpJetAccel=10、JumpJetTurnRate=10；SHAD 为 30/12/6。assets/ra2/shp/JUMPJET.seq.json 保留 RocketeerSequence 的 Fly/Hover=292,6,6 和 FireFly=370,6,6，均为 8 朝向。原 SHP 没有 32 个独立视角；本轮不修改素材。

只读对照 refs/ts-ra2/src/game/gameobject/locomotor/JumpjetLocomotor.ts 的每逻辑帧速度积分与转弯圆处理，以及 refs/ra2yr-resource/src/misc/locomotion.hpp 的 Accel/Speed 字段。参考重实现中水平增量硬编码为 2，不能当作原 EXE 消费 JumpJetAccel 的精确证据。本工程继续使用已有 JumpJetAccel 配置适配，修正秒与帧的量纲；20° 转弯限速开关、到点刹车均为独立 Godot 实现，不复制受限仓库算法，也不声称逐行复刻尤复引擎。验证见 VERIFICATION 同日条目。

## 2026-10-26 GACSPH 完整固定结构

只读源：本机 Steam Command & Conquer Red Alert II 的 ra2.mix > snow.mix > GACSPH.SHP（SHA256 cc52cdabc1c8f561ecd2f092cfbfcd443afc6997a46f1f7f064c1792cc212471）和 GACSPH_E.SHP（015f8c2684f623a35bc72cfc5e7d2f002daea782b5e698964046805d75dbca53）；UNITTEM.PAL 沿用 art_build 的盟军调色，不替换原版单位模型。extracted/art.ini [GACSPH_E]/[GACSPH_ED] 明确固定帧 0/1、Rate=0、Shadow=yes。

`node ra2pipe/chronosphere_structure.mjs <本机YR目录> <新的外部候选目录>` 仅输出 GACSPH.png/json 和 source-audit.json；采用 building_shapes.mjs 与正式 art_build 共用的完整结构合成，再将审核后的两项资源放回项目。此次两个一致候选为 C:/Users/admin/Temp/iron-chrono-structure-source-20261026-v1、v2。充能 F/G/H 动画、原始 E 源资源、MIX 安装文件保持。

## 2026-10-26 GADEPT 机械臂阶段

依据现有 extracted/art.ini：[GADEPT] 的 SpecialAnim/Two/Three 和 IdleAnim 分别指向 GADEPT_A/B/C/D；原文注释为 extending/working/retracting/idle。A/C 正常 Start=0、受损 Start=10、End=10（原注释明确为帧数），Rate=200；B 正常 LoopStart/End=0/19，受损 20/39。独立运行时只显示一个阶段，沿用现有 Rate/60 的秒适配。未搬运参考仓库派生实现，也未修改原始 SHP 图集。
## 2026-10-26 GAAIRC 四个停机坪

本地 extracted/art.ini [GAAIRC]：Foundation=3x2、BibShape=GAAIRCBB，DockingOffset0..3 为 (0,-128,0)、(0,128,0)、(256,-128,0)、(256,128,0)。现有 188x162 原版合成画布中的停机坪中心测量为 (124,110)、(94,125)、(154,125)、(124,140)。独立 Godot 适配使用每 256 leptons 对应横向 30、纵向 15 像素的投影，画布基点 (109,117.5)，并扣除已有 VXL origins 与绘制锚点的偏差。该基点为本工程画布校准值，不称为原 EXE 的内部坐标；没有修改原素材或搬运参考仓库代码。
## 2026-10-26 GAWEAP_A 旗帜健康分段

只读核对本机 Steam 尤复 ra2.mix > snow.mix 的 GAWEAP_A.SHP，SHA256 d45895fec166613464e61ca0664367c7495a4a702e299f801d1ab14dc0e939fd。60 帧图集实际为 15 正常、15 受损、30 阴影；正常末帧 14 与受损首帧 15 的原始裁剪矩形和姿态明显不同。独立导出适配按实际素材修正 art.ini 的 0..15 / 16..29 分段偏差，没有复制引擎实现或改动原始像素。
