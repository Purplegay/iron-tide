# RA3 起义素材提取

最新光束CPU宽度、透明度和动态渐隐结论见 [RA3_LASER_CPU.md](RA3_LASER_CPU.md)（v0.3.10.1）；下文“CPU未确认”及0.5宽度/末尾smoothstep是已被替代的历史记录。

## v0.3.11.3：升级军衔白块（2026-10-27）

根因已通过前后实际像素确认：`Ra3Mirage.rank_texture` 原先每次直接 `load` 返回临时引用。`VeterancyIndicator.paint` 返回后，未被 HUD 持有的纹理被释放，画布保留的 RID 失效，三种军衔都呈白色矩形。原 PNG 的金色箭头/双箭头/星形和透明通道正常。旧测试仅查资源路径和选中 HUD，没有覆盖未选中单位的资源生命周期。

采用与尤复 `HpBar.rank_texture` 一致的缓存方式，强引用保留三张原版军衔贴图。没有修改经验、晋升级别、武器、伤害或军衔素材。`ra3_rank_icon_regression` 通过真实 `VeterancyIndicator.paint` 绘制三个未选中单位，不在测试或 HUD 中额外持有 Texture2D；用 Image 解码源图比较透明轮廓和金色像素，跨帧不重绘复查，并验证局部引用释放后资源仍存活。修正前 13/13 失败且截图复现三个白块；修正后 13/13 通过且截图显示原始箭头与星形。

四组 216 项通过：rank_icon13、uprising43、veterancy126、cloak34，无脚本/引擎错误，运行前后源码指纹一致。证据位于 `refs/ra3-mirage/integration-test/rank-icon/{before,final}/`；Godot4.7.2 Compatibility/WASAPI，使用既有隔离测试工程和 user_data，服务/网络/数据库 none。初次专项脚手 WeakRef 类型推断解析失败，显式声明后才生成上述有效前后结果。状态 `pending_user_visual_confirmation`，需要在实际升级场景确认。

## v0.3.11.2：Q 受保护友军的隐形表现（2026-10-27）

根因：`field_conceals` 已参与敌方可见性和目标过滤，但己方单位的绘制没有消费这个状态，仍然完全不透明。此修正不改变目标资格、作用半径、伤害或幻影场壳体。

来源：SDK `AlliedAntiVehicleVehicleTech3.xml` 的 `InvisibilityBroadcastUpdate` 为 175 范围、0.2s 更新、`AffectsSelf=false`，排除空中与正在广播者；`GlobalData/InvisibilityTemplates.xml` 禁止开火中隐形，进入/离开 FX 均为 `FX_None`。`AssetTypeGameObject.xsd` 默认隐形透明度为 0.4 至 0.9，`System/UnitAISettings.xsd` 默认周期 60 帧，SAGEXML 中没有这些透明度字段的覆盖。适配按 RA3 30Hz 换算为 2 秒；周期内余弦插值是明确的 Godot 表现适配，不宣称已验证原生 CPU 插值曲线，也不把自身树木伪装的 `OpacityTarget=0.5` 当作广播隐形参数。

新增 `ra3_cloak_visual.gd`，由既有 `tick_actor -> Ra3Mirage.tick` 驱动。每 0.2s 复用真实 `field_conceals(unit,"enemy")` 判定；透明度周期按游戏 delta 推进，不依赖尤复 15Hz 换算。开火/受伤揭露、死亡、登车、空中与广播者资格在绘制读取时立即排除。状态仅存节点 metadata，不写存档，加载后从实际场重新构造。

实际绘制接入 RA2 SHP/VXL 车体、炮塔和影子、伪装贴图，以及 RA3 3D 车体、树木和影子；没有修改整节点 modulate，选择圈、文字和独立血条层不乘隐形透明度。当前回归覆盖 E1、MTNK、MGTK 伪装和被别的幻影场保护的 R3MIRAGE；无原画资源的旧程序化造型不在这四条素材渲染路径中，本次未将它们声称为验证通过。

六组 576 项全部通过：cloak34、mirage79、uprising43、presentation100、savegame120、allied_abilities200。新专项走真实 Q、`tick_actor`、可见性、存档和 `Unit._draw`，测量模型半透明像素及不透明选择圈，覆盖重叠场、侦测、暴露、进出范围和 Q 关闭。3D 嵌套视口重新挂载后的 Compatibility 测试背景为不透明黑色，先断言两次清屏一致，再以黑底合成 RGB 比例测透明度；其余素材直接测 alpha。第一次该脚手错误地对 3D 黑底测 alpha，修正测量方式后通过，未修改或放宽运行代码。

证据：`refs/ra3-mirage/integration-test/q-cloak/final/audit.json` 及各 case 截图/结果。Godot4.7.2、Compatibility/WASAPI，隔离 user_data `CodexIronTideValidation/ra3-mirage-20261027`；服务、网络、数据库均 none。验证前后脚本/资源指纹一致；共享目录其它任务修改保持原样。状态为 `pending_user_visual_confirmation`，需要用户在当前游戏确认 Q 覆盖友军的隐形观感。

## v0.3.11.1：幻影场空间渐隐修正（2026-10-27）

用户反馈的是幻影场壳体的空间渐变，而非主炮光束尾部。本轮只改`ra3_field_lightning.gdshader`及专项测试，保留原网格、贴图、175源单位作用半径、1.5世界比例、相机和101帧正/倒播曲线。

已确认两处原因：

- 起义FXLightning.fxo的VS13536把`COLOR.rgb * OpacityOverride`与`edge * COLOR.a`分别输出至t0.rgb/t0.a。PS12320才把插值后的t0.rgb与t0.a相乘，并乘HDR和双倍输出。之前提前在VS相乘，`interpolate(rgb*edge)`与`interpolate(rgb)*interpolate(edge)`不等价；原模型仅有7圈顶点、89个黑色顶点，误差会覆盖大段渐变。现在分开传递，World变换后的法线也按原VS直接参与点积，不额外归一化。
- Godot Compatibility把ALBEDO经三次多项式转换为线性，再用近似反变换输出；两者不是严格互逆，较暗尾部被压到0。依据[Godot tonemap实现](https://github.com/godotengine/godot/blob/master/drivers/gles3/shaders/tonemap_inc.glsl)，仅在该材质的Compatibility路径补偿这个往返：原FXO输出是目标，求解引擎输入。使用3次Newton迭代；0.001至4的离线扫描输出误差小于7.6e-8（双精度算法核对，非GPU精度保证）。实际GPU像素另测；这不是提高HDR倍数或扩大技能半径。原始黑色保持0，其它单位材质不受影响。

新增`tests/ra3_field_gradient_regression.tscn`。白贴图隔离云纹，以原VS/PS公式生成独立像素预期；三角形案例覆盖不同RGB/alpha/法线和1/0.5/0.1/0四档动画透明度。完整原生242三角形壳体使用CPU重心插值，累加前后表面，抽样320点（80点×4档，其中满强度54点落在有效亮环）。不是仅检查“存在贴图/非空像素”。旧HEAD着色器17项中12项失败；修正后17项通过。完整壳体四档最大RGB向量误差分别约0.00584/0.00490/0.00345/0，在RGBA8量化范围内；同时保存原贴图前后图和实际战场截图。

旧版对照：`refs/ra3-mirage/integration-test/field-gradient/before-full/`，由只读Git快照通过`IRON_TIDE_FIELD_BEFORE_SHADER`注入专项材质，不切换或覆盖游戏源码。正常验证不设置该变量，直接加载生产着色器。首次测试脚本类型推断失败未计为通过；修正脚手后完成上述旧版对照。

最终五组359项全部通过（gradient17、uprising43、presentation100、mirage79、savegame120），测试前后及交付前脚本/配置/贴图指纹一致。证据：`refs/ra3-mirage/integration-test/field-gradient/stable/audit.json`。Godot4.7.2、OpenGL Compatibility/WASAPI，隔离user_data `CodexIronTideValidation/ra3-mirage-20261027`，服务/网络/数据库均none。第一轮全部断言通过，但检测到另一任务在运行中修改skirmish_ai.gd，因此重跑同样五组确认稳定源码。状态仍为`pending_user_visual_confirmation`；原版透视场景与本工程正交投影存在适配边界，不声称像素级复刻整张原版战场。

## v0.3.9.1：场材质、伪装残留与跨代伤害（2026-10-27）

本节修正下文历史适配结论。起义 FXLightning.fxo SHA256 为 `16001d9db0475b8b5360c5118a0ab52020ef48d0c2b6c9f89a11cacd0c890bdf`；VS13536/PS12320 的算术与本机 D3DX effect pass 对照。`audit_field_effect.py` 使用隐藏 D3D9 窗口，只读原文件；实际状态 SRCBLEND=ONE、DESTBLEND=ONE、CULLMODE=NONE、SRGBWRITEENABLE=0。不是根据纹理外观猜混合。

- EXCloakingField 160顶点中89个纯黑颜色原先在导出时丢失。现在保留COLOR和第二UV，field按顶点遮罩、`smoothstep(0,3,abs(dot))`、两次±45度扰动、0.01×Time×Speed滚动、RGB的2.2次幂、HDR2和双倍输出计算。D3D preshader c15=1/3、c19=0、c21=0；本材质DiffuseCoordOffset=(0,0,5,1)经VS完整运算后基础UV为零，云纹由扰动坐标驱动。此前“zw意味着直接平铺5次”的只读诊断不成立，不能继续沿用。3D视口结果按加法送回2D，不二次乘透明度。
- FXMirageDisguise 用自己的DefaultW3D双UV/Modulate2X/顶点色/阵营色材质。原生SDK Primage_Disguise的20–30帧、后半段淡出、XY增长与阻尼、Z尺寸不增长已消费。进入伪装才触发，揭露即结束；这是为消除普通模式残留的触发修复。不是增加常驻护盾。场正/倒播101帧原曲线、末段保持不变。
- 用户明确选择跨代击杀节奏，尤复HP和其它规则不改。`extract_target_profiles.py` 从SDK单位/建筑XML解析基础HP，从Armor.xml沿继承链解析PRISM倍率；`ra3_mirage_targets.json`保存来源hash。转换为 `武器伤害 × 原版PRISM倍率 × 尤复目标基础HP / RA3同类基础HP`；角色对应与未知类别fallback是项目适配政策，不是RA3官方规则。只作用于RA3_PRISM，已有native_ra3单位不换算，保留实际武器/英雄倍率和目标防御。使用data.hp而非当前HP/max_hp，升级血量与残血不改变单发基准。仅RA3_PRISM保留浮点伤害及近零死亡阈值，避免折射整数截断多打一炮，普通尤复伤害仍原取整。
- 基础对照：GAPILE500↔RA3 Barracks1000，200→100，5炮；MTNK300↔Guardian480，200→125，3炮；E1 125↔Peacekeeper150，约166.67，1炮。IFV的PRISM170%等继承倍率也参与。原生RA3幻影500血仍200/炮。晋升、养成和防御存在时，按已有规则改变这些基础击杀次数。

验证：`refs/ra3-mirage/integration-test/field-damage/final/audit.json`；damage_adapter23、sdk_timing116、presentation59、lethal_beam25、mirage79、uprising43、savegame120、yr_damage1988，共2453项，无脚本/引擎错误，前后源码指纹一致。Godot4.7.2、OpenGL Compatibility、WASAPI，隔离custom_user_dir，通过junction消费当前共享目录；服务、协议、数据库均none。新回归覆盖真实发射到死亡、基础HP不变、残血/升级HP、防御单次消费、英雄伤害、折射分数累积、原版顶点遮罩、UV2、伪装进入/结束/移动揭露。既有30/60/120Hz、在途命中存档、致死光束及尤复伤害回归保持通过。版本元数据随后由共享0.3.9增加第四段为0.3.9.1。最终检查发现另一个任务更新了未提交的production_exit.gd及对应测试；本次未改动它们，按生产消费者补跑mirage79和savegame120项，通过且前后指纹一致，证据post-production-change/audit.json。

引擎续查：OpenSAGE `588ac477367a0022adf29f20a084e8873014e6ce` 的W3dLaserDraw.Update/BuildRenderList仍抛NotImplementedException，不能作已实现的RA3参照；EA Generals Zero Hour `0a05454d8574207440a5fb15241b98ad0b435590` 的LaserUpdate/W3DLaserDraw证实早代引擎动态改变宽度，但不能推出RA3同一包络。SDK Max目录的`.fx`也是编译二进制，不是可读HLSL。现已能直接读起义effect状态/常量；RA3 CPU端光束几何、顶点透明度包络仍无已验证源码。现有0.5宽度及0.3/0.1秒收尾仍是Godot适配，不能宣称原机像素一致。移动还使用通用车辆转向/刹车；SDK TurnTime/FastTurnRadius/CanReverseMove等专用消费者是后续缺口，本次未擅改。

状态：数值/客观回归通过；画面 `pending_user_visual_confirmation`。启动当前游戏，新建扩展遭遇战检查Q开关、普通形态停走/开火与三类目标伤害。没有推送、打包、删除或归档；共享目录其它改动保持原样。

## v0.3.8.1：当前游戏运行接入（2026-10-27）

已从提取转为运行替换，运行素材在 `iron_tide/assets/ra3/mirage/uprising/`，并更新已用的 `presentation/` 图标/贴图与 `native/audio/` 声音。复现入口 `python tools/ra3_mirage/import_uprising_runtime.py`；需本机起义转换结果、官方SDK和先前社区W3X做独立曲线交叉检查。

- 场动画是 Visibility 通道，不包含缩放。101帧、30FPS；0→50帧渐显，50→100帧保持。运行开启正播、关闭倒播；中途反向从当前帧连续推进为Godot防跳变适配。无跨RA2 15帧倍率。
- Delta解码字段来自SDK AssetTypeW3D.xsd；采用16采样自适应差分块，8位数据按有符号读取。对IDLA/MOVA社区W3X交叉检查最大偏差0.010146/0.029392，小于源压缩容差0.03。原生场采样帧15≈0.216、30≈0.648、50/100≈1。这证明数据接入，不等于完整SAGE动画引擎复刻。
- 真实绑定为FXLightning.fx；运行使用原FXCloud03、FXFracTileNRM、HDR2、EdgeFadeOut3等参数的Godot适配。D3D FXO未直接执行；UV扰动和TreeSway高度权重仍为适配，不称像素级一致。
- SDK的两层武器声、场开启/关闭player/world分区和循环已实际播放；18个额外音频样本，第二层延迟200–250ms，循环音调+45～50%。重用本机起义的53段既有语音PCM。播放器是单位子节点；退出、死亡、收纳和迷雾可清理，暂停不会推进延迟。循环关闭0.2秒淡出是Godot适配值。
- 待机默认伪装使用原AP_MIRAGETREE01与材质贴图，不再用RA2 TREE01（图形路径）；SDK Misc/Grass对应此树。其余地形到岩石/雪树/卡车的逻辑仍未实现，未假报完整地形伪装。
- 原军衔2/3/4、头像、生产与技能图标已用于战斗/选中UI。保留既有骨骼、炮口、残骸、武器伤害与时序；EXMIRAGEFIELDBUILDUP虽已提取，但SDK此单位ShieldDraw未调用，未编造额外触发。

验收：`refs/ra3-mirage/integration-test/uprising-runtime/final-wasapi/audit.json`。ra3_uprising 36、presentation 56、native 93、sdk_timing 108、savegame 120、track_perf 3、veterancy 126，共542项通过。OpenGL Compatibility / Godot4.7.2 / WASAPI；隔离用户目录，junction消费本工作区真实源码/资源，无网络/DB依赖；前后指纹一致。三辆混编、1600履带痕迹移动中位3.382ms、P95 5.736ms，仅此场景的本机测量。Dummy音频驱动退出时曾残留RA2/MP3/WAV播放对象，已保留失败日志，正式验收使用WASAPI无退出残留。截图位于同目录ra3_uprising_regression下。

状态：运行接入与上述客观验证完成，`pending_user_visual_confirmation`。用户重启当前游戏、新建扩展遭遇战测试Q、开火、静止伪装与军衔；不归档、不删除工作区。验证来源是当前共享工作区，不能把本轮检查点当作其它未提交功能的验收。

## 2026-10-27：起义正式版缺件提取（运行版本仍为 v0.3.7.1）

按用户指定，从本机 Steam《红色警戒3：起义》1.1 提取；本轮未读取试玩版，未替换游戏运行资源。素材位于 `refs/ra3-mirage/uprising/`（Git 忽略）；后续真正接入的最小运行资源再放入 `iron_tide/assets/ra3/`。下文历史“原版素材缺失”以本节为最新来源状态，但不能据此把旧运行效果标成已还原。

| 之前的缺口 | 本次取得的资源 | 接入状态 |
| --- | --- | --- |
| 幻影场模型、动画、材质 | EXCLOAKINGFIELD 的网格、骨架、101帧/30FPS动画；EXMIRAGEFIELDBUILDUP 的网格、骨架、51帧/30FPS动画 | 原版压缩通道完整保留，尚未移植曲线播放器；不能把线性缩放当原版动画 |
| 场的真实材质 | 网格绑定 **FXLightning.fx**；原参数及 FXCloud03 / FXFracTileNRM，编译 FXO 和依赖表 | 明确排除先前“DistortingObject.fx 候选即实际材质”的猜测；FXO 不是可直接运行的 Godot shader，也不是 HLSL 源码 |
| 武器声音缺第一层 | ALL_Mirage_WeaponFire1 的10段 JUChopp_weapMiss + Fire2 的3段 AUMirag_wea1Fire | 两层 WAV 及事件引用已导出，运行混音尚未接入 |
| 场开启／循环／关闭声音 | SUHamme_leechArma、SUApoca_harpLoop a/b/c、SUHamme_leechUnarma | 全部导出 WAV；保留 player/world 和 multisound 引用，事件参数仍以 SDK 核对 |
| 原版伪装物 | 岩石、两种树、卡车网格及 AP_MirageDisguises01 漫反射/法线/SPM | 已导出，未替换现有伪装逻辑 |
| 原版军衔及 UI | 盟军军衔2/3/4、头像、生产图标、开关技能图标 | 共7个 PNG，已检查图集裁切 |
| 原版骨骼、残骸和附加发光层 | SKL/IDLA/MOVA、COL骨架/两网格、损坏贴图、GLOWFX/LIGHTNINGFX/PLASMAFX | 为已接入社区包提供起义原件与来源校验；本轮未覆盖已用资源 |

共236个资产、643个原始文件、247个转换文件。转换包含77段 WAV、30张贴图（另保留30份DDS）、7个图标、15份网格、5份骨架、4份动画和音频事件映射。骨架/网格 JSON 保留 SAGE 坐标、骨骼局部顶点和权重；不是已经可直接替换的 Godot 场景。Timecoded 通道解出关键帧，Delta 通道保留 Scale/Init/NumBits/CompressedValues，未猜解播放曲线。

来源和验证：`extraction.json` 记录原包、原资产引用、原块大小/SHA256；`converted/conversion.json` 记录转换结果；`verification.json` 验证全部890个记录的哈希、动画块完整性/骨骼索引、77段 WAV 与原描述一致的采样率和样本数、官方音频解码器下载哈希，并记录四个 BIG、SkuDef、SDK单位XML和W3D XSD的哈希。选定素材依赖无缺失；这不代表全游戏资产或所有规则均已解译。

复现入口：`tools/ra3_mirage/extract_uprising.py`、`convert_uprising_media.py`、`verify_uprising_media.py`，命令见工具 README。解码器为官方 vgmstream r2168（下载URL与校验值在验证记录）。当前还需做 Godot 幻影场动画/材质、双层武器音频、原版伪装物与军衔UI的运行接入及表现验收；英雄二级散射、完整SAGE物理等是代码实现缺口，不能靠提取素材宣称完成。


## Installed Uprising extraction (2026-10-27)

Run from the IronTide root. Requires Python 3 + Pillow, the installed Uprising
1.1 game, and the official vgmstream CLI. Local originals and decoder stay under
ignored `refs/`; no game installation files or runtime assets are changed.

```powershell
python -B tools/ra3_mirage/extract_uprising.py --game "C:/Program Files (x86)/Steam/steamapps/common/Command and Conquer Red Alert 3 Uprising" --output refs/ra3-mirage/uprising
python -B tools/ra3_mirage/convert_uprising_media.py --source refs/ra3-mirage/uprising --audio-decoder refs/ra3-mirage/vgmstream/vgmstream-cli.exe
python -B tools/ra3_mirage/verify_uprising_media.py
```

The extractor reads BIG/RefPack and manifest v7, follows the selected presentation
and audio references, and preserves bin/relo/imp/cdata plus compiled shader files.
It never expands the full game into copies. The converter writes native DDS/PNG,
cropped icons, WAV, mesh/material/bone JSON, animation channels and audio mappings.
Delta channels are preserved, not guessed into curves; Timecoded keys are decoded.
Meshes retain source coordinates and bone-local attributes, not baked Godot poses.
FXO is compiled D3D shader bytecode, not portable shader source.

The verification entry targets this scoped extraction and the locally installed
SDK. It also expects `refs/ra3-mirage/vgmstream/release-asset.json` from the official
[vgmstream GitHub release](https://github.com/vgmstream/vgmstream/releases/tag/r2168)
and `package.zip`; it verifies the archive against that release asset digest.
`verification.json` records source hashes and limitations. Output thumbnails are
in `converted/icon-contact-sheet.png`; all converted file hashes are in
`converted/conversion.json`. Do not present these checks as game visual acceptance.
