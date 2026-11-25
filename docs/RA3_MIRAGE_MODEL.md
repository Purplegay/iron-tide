# RA3 原版幻影坦克素材交接

最新光束CPU宽度、透明度和动态渐隐结论见 [RA3_LASER_CPU.md](RA3_LASER_CPU.md)（v0.3.10.1）；下文“CPU未确认”及0.5宽度/末尾smoothstep是已被替代的历史记录。

2026-10-27，当前版本 **v0.3.7.1**（包含 v0.3.6 模型增强及下文致死光束修复）。本轮接入原版语音、蒙皮骨骼动画和 COL 残骸；保留 v0.3.4 的 RA2 体素模型更新。原工作区 `C:\Users\admin\IronTide` / `codex/ra2-independent`，表现状态 `pending_user_visual_confirmation`。未提交、推送、打包或归档。

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

## v0.3.5.1 移动性能修复

三辆混编、Q关闭时，积累的1600条履带痕迹逐条重绘拖慢整帧，骨骼不是主要瓶颈。轨迹改为两个MultiMesh批次，保留原图、方向、数量、淡出、迷雾与读档清理；新痕迹最高30Hz刷新，停留时10Hz刷新。三辆压力场景帧中位数17.604→3.990ms，12辆混编22.000→6.724ms；这不是所有实战的固定帧率保证。

相关4组287项检查通过，最终报告在 `refs/ra3-mirage/integration-test/sdk-closeout/tracks-v0.3.5.1-final/runtime-audit.json`，测试及源码资源指纹前后一致。`tests/ra3_track_perf.tscn` 可复跑压力场景；`vehicle_tracks_regression.tscn` 验证边界。需完全退出旧游戏再启动测试，尚待使用者确认卡顿改善；不自动关闭正在玩的进程。

## 新素材来源

- [Complete Allied Art Source Pack](https://www.moddb.com/mods/red-alert-3-entropy/addons/complete-allied-art-source-pack)：社区 Ace.of.Spades 使用 Bibber Asset Extractor 提取的 EA 原版资源，并非官方示例包。`Allied_Art_Pack.rar` 为 43,537,303 字节，MD5 `2672e16186da69fe919c86bff93e3020` 与发布页一致。只解出 Mirage Tank 目录与 readme；作者明确不保证提取动画完全正确。
- [Allied Vehicles 原版声音包](https://sounds.spriters-resource.com/pc_computer/commandconquerredalert3uprising/asset/440577/)：Sounds Resource 的 RA3 Uprising 分类，CoffeeMaus 上传，ZIP 102,336,287 字节。Mirage Tank 目录有 62 个 WAV；实际启用 SDK 事件引用的 50 段语音及 3 段武器音效。其余 SDK 注释声音、未使用移动机械声不自动启用。
- 本轮没有继续读取、提取或下载试玩版。旧几何/贴图/图标的历史来源不改写；本轮 W3X 和音频来源、SHA256 在 `assets/ra3/mirage/native/{provenance,audio_provenance}.json`。原包/解出作者源位于 Git 忽略的 `refs/ra3-community/`，运行所需文件位于游戏 assets，可随游戏交付。

## 当前运行接入

| 项目 | 已接入 | 边界 |
| --- | --- | --- |
| 模型、骨骼 | 22 根原骨骼、4889 顶点、3552 三角面；双权重蒙皮；整车共用朝向 | TruckDraw 仍没有独立炮塔；FX_WEAPON 随原骨骼动作移动 |
| 动画 | IDLA/MOVA 各 121 帧、30fps；移动切 MOVA，静止恢复 IDLA，暂停/冻结停止推进 | 根据 SDK 的 RESTART_ANIM_WHEN_COMPLETE 重复待机；EXCloakingField 开关动画不在完整包，继续使用已有场表现 |
| 声音 | 选中、移动、攻击、出厂、攻击移动、场模式、战斗选择、受击选择原版回应；3 个原版棱镜声音 | 原版英语；撤退事件已映射但当前无 retreat-to-castle 指令。SDK 注释的 Crec/选择机械声未启用；PitchShift/MinVolume 尚沿用现有音频系统适配 |
| 武器声音 | 只播放原版 MirageFire layer 2，延迟 200–250ms | 共享 layer 1 和场开关/循环音频不在 Mirage 目录，不能称所有共享声音已补齐；普通 RA2 单位保留原声路径 |
| 死亡 | COL 原模型、烧毁贴图、11 个 BONE_D 碎块/15 个表面，履带归各自父碎块 | 只作表现，不产生战斗对象或障碍；质量取 SDK，散落/重力为确定性 Godot 适配，非 SAGE 物理复刻 |
| 生命周期 | 5s 后按 4s 渐隐，取 LifetimeUpdate 中点4.5s并在 SinkDelay 1s后开始下沉，9s绘制结束清除；最多24份 | 与 SDK 多模块时序分别记录。时空抹除不出残骸；读档清理旧残骸及延迟声音；迷雾隐藏残骸 |
| 既有能力 | Q 场、伪装、棱镜光束/命中粒子、图标、履带轨迹继续保留 | 原生精英二级散射、0.1s主伤害延迟、共享场动画/声音仍属未接内容；未改伤害/移动/生产数值 |

W3X 的向量转换为 `(X,Z,-Y)`；动画通道是相对 bind pose 的平移/旋转。V 轴转换 `1-V`，已增加与旧正确静态几何 UV 的逐点比对；首轮截图查出的贴图倒置已经修正。新骨骼不影响 RA2/尤复模型。只在可见屏幕区域推进实时 3D 动画，最高 30Hz 更新视口。

## 重建与验证

```powershell
# Python 需 Pillow，作者源在 refs/ra3-community。
python tools/ra3_mirage/import_community.py --repo . --art "refs/ra3-community/art/Allied Art Pack/Vehicles/Mirage Tank" --audio "refs/ra3-community/audio/Allied/Mirage Tank" --sdk refs/ra3-sdk/installed
powershell -NoProfile -ExecutionPolicy Bypass -File iron_tide/launch_game.ps1 -PrepareOnly
```

导入器校验骨骼、权重、有限数值、各权重坐标一致性、旧正确 bind 几何/索引/UV、残骸父骨骼分组以及 PCM WAV 信息。`import_audio.py` 直接读取 SDK Voice.xml，XML 注释不会成为音频事件。

新增 `tests/ra3_native_regression.tscn`，覆盖 PCM 解码/播放、语音状态、骨骼/蒙皮、待机/移动、炮口、循环、死亡只触发一次、11碎块、24数量上限、时空抹除、生命周期和实际存读档清理。保留此前七组相关功能专项。运行环境为 Godot 4.7.2 / OpenGL Compatibility；验证工程 `refs/ra3-mirage/integration-test/project` 通过 junction 消费真实 scripts/data/assets/tests/shaders，存档隔离为 `CodexIronTideValidation/ra3-mirage-20261027`；未使用网络服务、数据库或端口。

最终证据目录：`refs/ra3-mirage/integration-test/sdk-closeout/native-v0.3.5-final/`。`runtime-audit.json` 记录各套件结果和源码、RA2/RA3运行资产前后哈希；图片位于 `ra3_native_regression-render/native-{model,wreck}.png`。具体总数见 `VERIFICATION.md`。

旧 `audit_sdk.py` 是 **SDK 自身散装媒体** 审计，仍会报告 SDK 89 段引用音频和11项 ART 缺失；不据此否定本轮从社区包取得的素材。社区包的运行来源在新 provenance 文件中分别记录。请勿把旧报告的“原版未接入”继续当作当前状态。

试玩：运行 `iron_tide/launch_game.ps1`，扩展模式→盟军战车工厂+作战实验室→幻影坦克（RA3）；重点确认移动时车身细微晃动、选中/移动/攻击语音、出厂语音、炮口和死亡碎块。视觉/听感需要使用者反馈后再验收和归档。


## 历史交付记录（以以上当前状态为准）

## 已验证

- EA RA3 官方试玩版：社区归档 https://files.cncnz.com/red_alert_3/demo/RedAlert3Demo.exe ，1957939137 字节，MD5 `0be9ffd8e71a13d80f5a6374e40e0c41`。只解包，没有安装或运行试玩版。
- 内部名称 `AUAntiVehicleVehicleTech3`。`Core_5.cab` → `DataStaticStream_big` → `static.manifest/bin`。
- 完整提取本单位的七张 DDS 贴图、COL/FX/SKL 骨架、IDLA/MOVA 动画、车体/履带/特效网格和容器原始块。原始块仍是编译格式，不宣称已恢复为原作者 MAX/W3X。
- Godot 4.7.2 独立预览成功。车体和履带共 4889 顶点、3552 三角面；按原骨骼层级、旋转和平移、双权重还原静态姿态，包围盒与原始值误差小于 0.0001。
- 输出 GLB 后重新导入，顶点/三角形数一致；最终截图来自重新导入的 GLB，日志含 `MIRAGE_PREVIEW_OK`，退出码 0。
- 预览使用原漫反射贴图和普通材质。几何/贴图已目视检查，未发现部件散开。最终游戏内视觉体验尚未验收。

## 本地文件

下载、提取原件和测试输出位于 Git 忽略的 `refs/ra3-mirage/`。运行模型、贴图、头像及无图形回退图位于 `iron_tide/assets/ra3/mirage/`，来源与 SHA256 在其 `provenance.json`；试玩版安装包未加入 Git。

- `original/`：原始编译块、DDS 及解码 PNG。
- `preview/ra3_mirage_bindpose.glb`：可导入的静态模型，含车体和履带及漫反射贴图。
- `preview/preview.png`：Godot 实际渲染截图。
- `preview/geometry.json`：中间几何。
- `local-tools/`：本轮本地提取/转换脚本；依赖本机路径，尚非通用导入器。
- `provenance.json`：来源与主要产物 SHA256。

## v0.3 运行接入与边界

- 扩展模式盟军战车工厂 + 作战实验室解锁「幻影坦克（RA3）」；1600 资金、正常倍速 15 秒。RA2 对照模式不开放该单位，原幻影坦克仍保留。
- `data/ra3_mirage.json` 单独装载；原版 SDK 单位、武器、隐形模板为规则参考。单位 HP500、基础武器200/精英250、射程125/150经2.2倍距离适配，移速80世界单位/秒。护甲使用现有 YR 护甲桥接，不宣称两引擎数值完全一致。
- Q 切换幻影场，2秒切换冷却；开启后禁用主炮，隐藏范围内友方地面单位，不隐藏自己/其他正在开场的坦克/飞行单位。开火或受击暴露，警犬等反隐单位可侦测；场重叠、离场、死亡和存读档均覆盖。
- 主炮与一级散射使用实际炮口光束，普通最多5个散射目标25伤害、精英最多7个40伤害。主炮当前即时命中；原生0.1秒延迟、精英第二级散射、原生压制尚未实现。武器音效和静止伪装树暂复用现有 RA2 资源。
- 图形模式使用 `scripts/units/ra3_unit_model.gd`：原版几何、漫反射/法线/SPM贴图，整车连续旋转、履带UV移动（早期错误的独立炮塔已于 v0.3.2.1 移除），384px透明视口 + 4xMSAA。不可见、屏外或静止姿态避免持续重绘，共享网格和基础纹理。未完成大规模军团GPU压力测试。
- 炮口按原骨骼位置与同一3D相机投影；鼠标命中读取渲染透明度，框选中心取模型投影中心。保存后重新创建渲染节点，特殊模式和冷却沿用现有存档字段。
- 原 SAGE 材质程序与骨架 IDLA/MOVA 动画没有直接移植；FX 的纹理和参数已于后续版本接入，绘制仍是 Godot 适配。没有把32方向图冒称实时3D：方向图只供无图形回退和旧接口。
- 转换重建入口：`tools/ra3_mirage/convert_model.py`；工具说明见同目录 README。运行时不依赖本机 refs 路径。
- 专项：`tests/ra3_mirage_regression.tscn`，图形模式额外校验0.03弧度连续转向、共享网格、五朝向炮口投影和透明区域点击。最终六轮1856项断言通过，正式启动准备Ready；结果见 VERIFICATION.md 与 `refs/ra3-mirage/integration-test/final-v0.3-r2/`。新增内容指纹后建议新开对局，旧版战斗存档仍按原兼容校验处理。

## Art Source Pack 核查

用户提供的 https://www.moddb.com/games/cc-red-alert-3/addons/cc-red-alert-3-allied-art-source-pack 是盟军示例源包，含 MAX/W3X/贴图。页面列出 Cryocopter、Javelin Soldier、Riptide ACV、Airfield、Boot Camp、Seaport，没有幻影坦克。没有为获取幻影坦克而下载此包。

格式参考：SDK `SAGEXML/Allied/Units/AlliedAntiVehicleVehicleTech3.xml`、https://github.com/Qibbi/WrathEd2012 的流/网格结构。RA3 顶点声明是 ASCII 格式（如 `p0:00:3f32`），不能直接套用旧 C&C 的 D3D 声明布局。大块 RefPack 使用 `90 FB` 四字节长度；只支持 `10 FB` 会把压缩数据错当资源。DDS 经 Pillow 解码；Godot `Image.load_from_file` 直接读本批 DDS 失败。

本轮下载的 C&C Asset Extractor GUI 未正常显示，已关闭本轮启动的进程。最终产物由本地解析脚本生成，不依赖其 GUI。

## v0.3.2 原版 UI、轨迹与 FX 接入（2026-10-27）

当前单位生产图为`Button_AlliedAntiVehicleVehicleTech3_on`，选中图为`Portrait_AlliedAntiVehicleVehicleTech3`，Q开/关分别为`AUA_Mirage_GapGenerator`/`AUA_Mirage_StrikeMode`，对应SDK `UI/ButtonStateDataCommon.xml`。此前3D渲染截图头像保留在旧路径作历史产物，运行映射已指向`presentation/`原图。

`tools/ra3_mirage/extract_presentation.py --source refs/ra3-mirage --output iron_tide/assets/ra3/mirage/presentation`从已解包流的PackedTextureImage坐标提取图标，并提取原纹理、力场/伪装几何；`presentation_provenance.json`记录原资源名、atlas裁剪坐标与原块/输出SHA256。

- `Ra3WeaponFx`/`ra3_prism.gdshader`：原版棱镜/精英棱镜纹理，两层反向(0.2,0.3)UV滚动；SDK25宽主光束、缩小的一级散射、25/30秒命中闪光。Godot加法混合，复用既有伤害调用。静态持有纹理，避免绘制调用结束后资源释放造成白色方块。
- `Ra3MirageFx`/`ra3_cloaking.gdshader`：原版242面EXCloakingField、FXCloud03和FXFracTileNRM；原版FXMIRAGEDISGUISE用于切换瞬间。展开/收拢是Godot过渡适配，尚非原始W3D动画通道播放器。范围圈仅作选中提示，已去掉悬空圆圈替代效果。
- `VehicleTracks`：R3MIRAGE采用单位XML指定的EXTireTrack2，五种现有盟军履带战车采用EXTnkTrack；每5世界单位采样双侧轮迹，停驶不增、隐藏/未侦察不留、传送切断，过期淡出和容量上限。`BattleSnapshot.restore`只清理临时轨迹节点，没有新增存档字段或改变移动规则。
- 专项`tests/ra3_presentation_regression.tscn`必须用图形模式，包含真实Q输入、状态图/冷却、实际移动、真实迷雾、帧缓冲轨迹差异、普通/精英武器与临时节点读档清理。

用户最新指示：补完后先让用户测试，再决定归档。不要自行归档或删除原IronTide工作区；本会话没有附着的独立IronTide工作树。当前改动直接在原`codex/ra2-independent`的脏工作区，未提交/推送。原生SAGE着色器、原模型骨骼动画、RA3武器音频和精英二级散射仍不在本次已完成范围；不要声称完整RA3引擎移植。

## v0.3.2.1 纠错：整车朝向与真实发射器

本节取代此前“独立车体/炮塔”的实现说明。用户截图证实旧拆分错误：骨骼2～11承载上半车身，不能当炮塔独立旋转。SDK使用TruckDraw与WeaponSlotHardpoint，没有此独立炮塔；所有车身板件和四组履带共用hull变换，移除move.turret及备用图集的turret映射。原有R3MIRAGE_tur文件仅留历史资源，不再由单位引用。

FX_Weapon名字哈希09bb1f5d对应SKL骨骼6，父链6→5→2→1→0，合成后转换至Godot为(1.23912601,19.39524651,0)。原代码把车头灯20/21的x、z和人为归零的横坐标当炮口，这是错误的。convert_model.py现导出rig.json，实时模型和32方位备用图集都读取这个来源；光束从顶部棱镜发射器出发。

本轮七组1893项断言通过，final-v0.3.2.1-r3/audit.json记录环境及前后相同的源码指纹，交付再次核对一致。新图形断言覆盖五朝向、瞄准方向与车身方向不同/反向时模型像素不变、固定发射器不随假炮塔漂移、来源挂点与真实相机投影一致。早期失败为旧测试仍要求独立炮塔，按用户确认的整车要求替换，并保留失败报告。已查看最终model-3d.png与prism-normal.png；仍需用户实机确认，不归档。


## v0.3.3.1 最新来源校正

以官方SDK优先，勿再把用户印象直接当原始规则。主光束实际Lifetime=1.5s，散射LaserLifetime=0.5s；本单位LaserDraw没有FadeOutTime覆盖，XSD默认0。逐渐衰减来自命中/炮口粒子颜色和伪装光纹Alpha，不给整条光束编造渐隐。此前0.3秒短光束与0.65秒实验渐隐均已废止。数据和来源SHA在data/ra3_mirage_visuals.json，可用tools/ra3_mirage/extract_visual_rules.py --sdk refs/ra3-sdk/installed --output iron_tide/data/ra3_mirage_visuals.json重建。

平时形态按SDK OpacityTarget=0.5做己方车体透明度，与既有TREE01交叉；切换0.7秒为明确标注的适配值，未找到SAGE公开时长。不存在交战车体重复闪隐。1914项最终验证见VERIFICATION.md与final-v0.3.3.1-sdk/audit.json。用户视觉确认仍待完成，继续保留工作区，不归档。

## 2026-10-27 幻影场公开素材排查（未修复）

用户确认问题覆盖整个场的外观、展开与收起，并选择继续找公开原版特效素材包；仍不授权继续读取或提取试玩版。本轮未改运行代码、未运行表现验收，版本保持 v0.3.5.1。

- 本机 SDK `SAGEXML/Allied/Units/AlliedAntiVehicleVehicleTech3.xml` 引用 `ART:EXCloakingField.w3x`。ShieldDraw 在 USER_6 时正播、退出时 ONCE_BACKWARDS。实际动画曲线、帧数、蒙皮和材质绑定不能从调用 XML 推导。
- 当前 `ra3_mirage_fx.gd` 仍用 `delta*2.0` 线性强度和整网格统一缩放，配通用蓝色云雾 shader。这与原版动画接入不是同一件事，保持未完成状态。
- 官方示例 Allied/Uprising Art Source Pack 发布目录仍不含 Mirage 场；已下载的 Complete Allied Art Source Pack 此前全包目录检查也未找到 EXCloakingField。不要因“完整盟军包”名称误报特效齐全。
- 本轮通过 GitHub recursive tree 检查以下公开仓库，返回均非 truncated，路径未找到 EXCloakingField：valorad/RA3Afterdash、xan105/RA3-Mod-UpheavalEx、JingYeD/AN、Evanati/RA3UltimateWar、NordlichtS/GameModCodeShare、HaoJun0823/RA3SDK-U、deezyrix/world-viewer。只是文件路径检查，不等于检查压缩文件或所有文件正文。
- UpheavalEx 的 `Upheaval/Art/Units/Archer Maiden/FXCloakField.dds` 是候选同名贴图，不足以证明属于幻影场；没有采用。
- Bibber 官网 SDK Expansion 下载按钮正常 AJAX 入口本轮返回 HTML，未取得扩展包，不可把它记成已下载/已验包。Upheaval 的 GitHub 扩展源码目录已检查，未下载约138MB原包。
- EA 官方 `electronicarts/CnC_Modding_Support` 的 Red Alert 3/Shaders 已有本地7个源码文件，位于 `refs/ra3-sdk/ea-shaders/`。DistortingObject.fx 是候选折射实现，尚缺 EXCloakingField 网格的材质绑定证据，不能宣称它就是幻影场 shader；未接入运行代码。

公开来源：
- https://github.com/electronicarts/CnC_Modding_Support/tree/main/Red%20Alert%203/Shaders
- https://www.moddb.com/games/cc-red-alert-3/addons/cc-red-alert-3-allied-art-source-pack
- https://github.com/xan105/RA3-Mod-UpheavalEx
- https://bibber.eu/downloads/ra3-mod-sdk-expansion/
- https://www.moddb.com/mods/red-alert-3-upheaval/downloads/red-alert-3-upheaval-116-source-code

后续仍需来源可核查的 EXCloakingField 模型/骨架/动画和材质参数，才可按原版重做。公开检索未命中不代表资源不存在；不以自制动画冒充原版，不自动改走试玩版。保留移动性能修复与用户视觉验收状态。

## v0.3.6.1 · 一击击杀光束消失

根因：Ra3Mirage.shoot 在伤害前已创建 FX，但 Ra3WeaponFx 下一帧检测到任一端死亡便 stopped=true，主目标即时死亡使主光束和散射都在首帧隐藏。改为分别跟随存活端点，死亡/释放端点保留发射时或最后有效位置；寿命仍为主束1.5s、散射0.5s。散射的迷雾起点使用实际主目标地面位置。没有修改伤害、攻击间隔、幻影场或 shader。

新增 `tests/ra3_lethal_beam_regression.tscn`：真实 `_fire_shot` 击杀载具/建筑、主次目标同时死亡、释放发射者、独立端点跟随、寿命回收。旧实现25项中10项逻辑失败。最初整屏像素比较会被死亡动画干扰，不能作为修复证据；最终将实际 beam 绘制节点放入隔离视口，分别确认5481/5476/630个光束像素，排除其他表现干扰。

最终4组276项通过（专项25、presentation54、mirage77、savegame120），无脚本/渲染错误，运行前后代码配置指纹一致。`launch_game.ps1 -PrepareOnly` Ready。最终证据 `refs/ra3-mirage/integration-test/sdk-closeout/lethal-beam-final2/audit.json`，同目录包含原场景与隔离光束截图。

环境为 Godot4.7.2/OpenGL Compatibility、隔离 validation project、CodexIronTideValidation 用户数据；无网络/DB/服务依赖，没有关闭玩家现有进程。表现为 pending_user_visual_confirmation，重启游戏后测试直接击杀及散射击杀。保留并发 v0.3.6 模型增强；本轮未推送、打包、归档。幻影场缺失原版动画的问题仍未解决。


## v0.3.7.1 · SDK 数值与时间单位核对

本节取代早先关于“沿用尤复精英晋升／即时命中”的描述。当前 BattleClock 的 NORMAL_TICKS_PER_SECOND 和 RULE_TICKS_PER_SECOND 均为15；1倍时 Engine.time_scale=1，即一真实秒推进一规则秒。RA3不额外乘15、30或2；共用暂停及用户选择的倍速。Godot物理推进频率不是RA2规则时间换算率。代码未新增另一个全局时钟。

来源为本机官方SDK的单位、Weapon、Locomotor、ExperienceLevels、AttributeModifier、BaseVehicle、GlobalDefines、Armor与CannonNode XML。`tools/ra3_mirage/extract_balance.py --sdk refs/ra3-sdk/installed --output iron_tide/data/ra3_mirage_balance.json`可重复导出原数值、原XML结构和SHA256；运行时晋升读取此文件。不是RA3引擎C++源码，也不代表零售最终补丁版本。

| 参数 | SDK来源值 | 当前接入 |
|---|---|---|
| 价格／BuildTime | 1600／15秒 | 原值；不走尤复按价格推导时间及生产加速表 |
| 基础生命 | 500 | 500；精英及英雄625 |
| FiringDuration／ClipReloadTime | 1.5／0.1秒 | 普通至精英周期1.6秒 |
| 英雄RATE_OF_FIRE | 120% | 适配为射击1.5/1.2＋固定装填0.1＝1.35秒；SDK无SAGE调度器实现，仍需零售版实测验证此组合公式 |
| ActivateLaser Lifetime | 普通与英雄均1.5秒 | 固定1.5秒；不为消除英雄短重叠而自行缩短 |
| 散射LaserLifetime | 0.5秒 | 0.5秒 |
| DamageNugget DelayTimeSeconds | 0.1秒 | 真实待命中队列，读档保留剩余等待与一次性结算 |
| 主武器Damage | 200／英雄武器250 | 原始200／250；老兵起DAMAGE_MULT125%，最终仍受现有目标护甲及伤害取整适配影响 |
| 基础射程 | 125／英雄武器150 | 距离×2.2：275／330；英雄RANGE125%后412.5 |
| Speed | 80 | 距离×2.2：176世界单位/秒；旧80世界单位/秒漏乘比例；不套尤复晋升FASTER |
| AccelerationSeconds | 0.01秒 | 原值；替换旧加速适配 |
| VisionRange／ShroudClearingRange | 200／STANDARD_SHROUD_CLEAR=500 | 当前单一视野服务以清雾半径500×2.2=1100实现；没有冒称已分离视觉侦测200与清雾500 |
| 幻影场范围 | 175 | 385世界单位；不再把这个数当清雾半径 |
| 晋升累计经验 | 4800／8400／14400 | 级间消耗4800／3600／6000，保留四级 |
| 晋升倍率 | Veteran伤害125%；Elite生命125%；Heroic范围/视野/清雾125% | 分级累计；不套尤复装甲1.5及冷却0.6；英雄武器只在第4级启用 |
| 英雄自愈 | 启动1秒，3点/0.5秒；允许交战/受击 | 独立秒计时、血量封顶、计时存档；替换尤复脱战按比例自愈 |

此前错误根因：使用尤复两级晋升与 veteran_rof=0.6，把1.6秒压成0.96秒，主光束仍1.5秒，因此频率和光束表现明显不匹配。修复没有把全部RA2战斗提速，也没有将图形帧率设为15。

已审计但尚未完整接入的原生行为：Locomotor的MaxSpeedDamaged75%、TurnTimeSeconds1与转弯半径/制动/悬挂整套SAGE物理；独立VisionRange与清雾范围；原生PRISM护甲体系（当前跨RA2护甲兼容映射与取整）；英雄二级散射；SUPPRESSABILITY、NO_BRIBE/IMMUNE_TO_BARK及按被击杀者军衔变化的ExperienceAward；原版RA3军衔图标。不能把导出全部XML字段称为全部行为实现。幻影场原版动画/材质缺件仍未解决；未读取新的试玩版素材。

测试保留30/60/120Hz实际开火入口、真实工厂生产、致死光束、分数延迟存档、自愈存档、RA2晋升与实时时钟。模型瞄准像素比较曾只差1个红色字节1/255，已保留前后PNG并将容差限定为最多4个通道各差1，不容许模型或履带位移。表现状态仍为 pending_user_visual_confirmation。


最终8组1158项通过：SDK时序108、致死光束25、presentation54、mirage79、veterancy116、savegame120、battle_clock328、weapon_trail328。证据 `refs/ra3-mirage/integration-test/sdk-closeout/sdk-timing-legacy-final/audit.json`。9个官方SDK来源文件可重复导出，运行配置核心数值与导出一致，balance JSON SHA256 cc40276842690a227c2253a0206e0799e1226b3443cd34bb7a63142508a69ada。

旧存档包含旧单位定义、移动缓存和尤复晋升倍率，加载时仅对未标记native_ra3的R3MIRAGE做一次迁移；原顶级精英映射为原生英雄，保留血量比例、养成倍率、级间经验比例和当前冷却完成比例。原生新档保持精确状态，不重复换算。测试含0.1秒命中剩余等待、自愈剩余等待、旧定义/倍率迁移及再次读档。

本轮并发框选功能将版本推进至v0.3.7，首次final运行检测到project.godot变化而拒绝验收；后续legacy-final在共同源码上重跑8组，运行前后指纹一致。交付版本只再将metadata改为v0.3.7.1，delivery-audit.json记录此唯一运行文件差异及完整复核；没有回退矿车框选更新。Godot4.7.2/OpenGL Compatibility、隔离custom_user_dir、无服务/网络/数据库依赖，不终止玩家进程；未提交、推送、打包或归档。实机射击节奏、移动和特效仍待使用者确认。


## v0.3.8.2：空间比例、独立折射与动态光束

本节替代上文历史记录的2.2倍距离和无收尾渐隐行为。官方SDK原始值保持：Speed80、主炮125/150、CannonNode125/150、场半径175。Godot模型投影是96/64=1.5像素/原单位，此前游戏距离却用2.2；现统一到1.5。普通移速120、射程187.5，英雄主炮含原RANGE125%为281.25；独立折射分别187.5/225，不继承主炮RANGE。折射以第一次命中点为圆心，仍是一跳5/7目标；不是爆炸半径。单一清雾服务750，场262.5，场的绘制与声音距离使用同一换算。此比例是项目坐标适配，不是SDK提供的平衡倍率。

起义Data/Shaders.big中shaders\compiled\laser.fxo，SHA256 `9aba52a55eff34d0351300e6edf6e40110c8698a54d5946964804778ec5bc648`。通过Windows D3DDisassemble得到8436/9684两份像素着色器，均有 `mul r1, r1, r2` 和 `mul r1.w, r1.w, v0.x`：两层贴图相乘、透明度乘顶点输入；9056/10392顶点程序转交v3.x。SDK单位LaserDraw提供正反UV滚动(0.2,0.3)/(-0.2,-0.3)、ColorEmissive=(4,4,4)。原实现相加并放大，会把细节压成亮条，现按乘法修正。重现：`python -B tools/ra3_mirage/audit_laser_shader.py --game <起义目录> --output <本地证据目录>`。

原生引擎怎样生成顶点透明度仍未公开，不能由XSD FadeOutTime默认0推断全程不渐隐。当前Godot适配在原寿命内部收尾，主炮末0.3秒/折射末0.1秒smoothstep渐隐；不改变实际伤害和射击周期。屏幕宽度独立适配0.5，原LaserWidth25/5保留，绘制带宽12.5/2.5，不能声称这是原生像素宽度。敌方迷雾、死亡目标/发射者的末位置保留逻辑不变。

存档使用veteran.adapter_revision=2识别空间迁移，旧native_ra3=true也会刷新定义与移动缓存；旧原生精英不会误升英雄，非原生老档原顶级依旧按原迁移合同保留。保留血量、养成倍率、经验及射击进度，二次读档不重复转换。

验证：`refs/ra3-mirage/integration-test/scale-beam-0382/final/audit.json`。六组435项：SDK时序116、presentation59、致死光束25、mirage79、uprising36、savegame120。覆盖实际一秒移动、折射半径内外0.1边界、原生老档迁移和幂等、独立渲染光束纹理滚动/核心宽度/透明度能量、致死保留及原时序；OpenGL Compatibility/WASAPI，无引擎或脚本错误，前后源码指纹一致。使用隔离custom_user_dir，服务/网络/数据库为none。首次旧类缓存缺ForceFire导致无法加载，重新导入隔离工程后全部重跑；不把0项断言算通过。当前是共享工作区验证，不等于干净Git检出的完整交付包；表现状态 pending_user_visual_confirmation。
