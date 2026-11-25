# 起义未来坦克／先锋质子炮特效对照 · v0.5.0.8

用户现象：初始中子球有方形贴片、扩张后的透明度不对，质子炮扰动与原版不同。本次检查范围是两条攻击特效链，不能据此称全部单位或 SAGE 引擎均已复刻。

## 权威来源与素材包实查

- EA 官方 [CnC_Modding_Support](https://github.com/electronicarts/CnC_Modding_Support/tree/3aad8e412961ab543192ae70f8503dc8e178e095/Uprising)，本机 `refs/ea-modding-support`，提交 `3aad8e412961ab543192ae70f8503dc8e178e095`；使用 Uprising 分支目录的 XML、Schemas、Shaders。
- 已下载的 [EA Uprising Art Source Pack 镜像](https://www.cnclabs.com/downloads/details/1763/)：`refs/ra3-expansion/official-art/UprisingArtSourcePack.zip`，19,312,713 字节，299 项；SHA256 `633fec2ca7acdb0208457af593a291292cb4d8ed233f8337463fcc38857967d5`。重新检查目录，只有 Archer Maiden、Steel Ronin、Mortar Cycle，**没有未来坦克或先锋炮艇及本次特效**。未将其他素材谎称为该包内容。
- 两单位实际网格、纹理、动画和材质常量来自本机 Steam《起义》零售资源，现有提取目录 `refs/ra3-expansion/uprising`、`future-extra`。未来坦克来源及生成物哈希在 `iron_tide/assets/ra3/expansion/future/fx/provenance.json`。没有使用试玩版。
- 原生粒子时间按 30 帧／秒；原距离至本地图为 1.5 倍。视觉尺寸与武器伤害范围不是同一个字段。

## XML → 着色器 → 当前调用

路径以 EA 仓库 `Uprising/` 为根；运行脚本在 `iron_tide/scripts/units/`，着色器在 `iron_tide/shaders/`。

| 原始定义／逻辑 | 对照发现 | 当前修正与边界 |
|---|---|---|
| `AlliedFutureTankNeutronScramblerNode.xml` 引用 `AlliedFutureTankNode`，Drawable `FXFUTUREPROJECTILE`；10 个初始粒子、35 帧寿命 | 并非一个普通透明球；含 AURA 与 GEOSPHERE。Alpha 的中间键值范围为 0.5～1，旧解释器总取 Low | `ra3_future_particles.gd` 保留数量、寿命和原网格；每粒子创建时抽样一次 Alpha，各相对年龄键之间插值，不逐帧重新抽样 |
| `AlliedFutureTankHit_XP`：延迟 35 帧，寿命 40 帧，Size 2、每帧增 0.28，Alpha 0.5→0 | 扩张球不能按 6 秒伤害节点寿命或伤害半径直接缩放 | 按原曲线播放；视觉结束停止空视口更新，伤害节点不受影响。普通／英雄资源沿用原引用 |
| `FXShield.fx`：顶点视角 → Falloff/LUT；OpacityOverride → 顶点 RGB；PS 的贴图 GammaToLinear、Emissive×2 | 旧实现重新在像素阶段算角度，离屏结果再乘 Alpha，改变球壳轮廓和淡出 | `ra3_future_shield.gdshader` 从顶点传递角度衰减，LUT 按原坐标采样，RGB 只乘一次透明度；OpacityOverrideEnable 分支保留源码使用 Key1 的行为，不启用注释中的 Key2 插值 |
| `FXShield.fx` 深度交线：OUTLINE_SCALE=5、TextureFadeOut、IntersectionMultiplier | 旧实现没有原交线 | 从材质读取 IntersectionMultiplier，补水平地面解析深度差；对应当前平地。单位、建筑仍是 2D 贴片，没有它们的场景深度；不是全场景软粒子复刻 |
| FXShield／FXLightning／Proton 的 ONE+ONE 混合 | 3D 离屏已经生成光能 RGB，随后用普通 2D Alpha 混合会露出暗色矩形，并再次衰减亮度 | `ra3_fx_composite.gdshader` 以加法合成 RGB；覆盖 Alpha 不再重复相乘。用于 Future 粒子、Gunship 命中及独立弹体特效，不用于整个单位模型 |
| `CommonParticle.fxh`：VertexCorners 为 ±0.5 | GPU `Size` 是完整宽度，旧 QuadMesh=2 及 2D Size×3 都导致翻倍 | GPU QuadMesh=1，2D 宽度=Size×1.5；修正中子光晕、质子闪光、扰动和 Future Q 首尾光晕。Drawable 原始网格不套这个缩放 |
| `GpuParticle.fx`：GammaToLinear(texture×Color×ColorScale) | 旧 StandardMaterial 的 albedo/emission 路径不同；首个颜色键之前的处理也不一致 | `ra3_gpu_particle.gdshader` 按原计算顺序；按 XML Color 键插值并固定采样 ColorScale；GPU 平面使用相机朝向或原地面朝向、原角度 |
| `AlliedGunshipAircraftWeaponProjectile.xml` onDeath → `FX_AlliedGunshipProtonHit(Vet)` | 原 FXList、10 个系统及 43 粒子已在运行链，问题集中在渲染解释 | 保留调用、数量、每粒子寿命、普通／英雄素材和独立于弹体的命中节点；不以减少粒子数掩盖亮度问题 |
| `FXLightning.fx` VS：顶点 Alpha×fadeOut、RGB×OpacityOverride；PS：color×顶点 Alpha、GammaToLinear、RGB×2 | 旧移植把边缘因子平方；原 ONE+ONE 并不会再用输出 Alpha 乘 RGB | `ra3_gunship_fx.gdshader` 改成单次顶点插值边缘因子，保留单次 OpacityOverride |
| 同文件 `fxprotoncollider` 分支：MaskTexCoord.z=(OpacityOverride×3)-1 | 此透明度实际驱动遮罩侵蚀，不能当普通 Alpha 淡出 | 保留双纹理及世界坐标扰动、遮罩移动；专项断言不会再把整层 RGB 乘该透明度 |
| `FXAlliedGunshipProtonDist`／`VetDist`：GPUParticleDistortion，25 帧、Size 33、增量 3、阻尼 0.99、Z=15、Alpha 50%前为1后到0 | 不是另一份 `GpuParticleDistort.fx`；旧移植忽略归一化与角度、使用自行定义径向遮罩与3像素偏移 | `ra3_gunship_distortion.gdshader` 解码并归一化原法线，按粒子角度旋转，覆盖率=纹理Alpha×原Alpha曲线 |
| `PostFX_Distortion.fx`：解码扰动，maxOffset=0.08 屏幕 UV | 旧实现固定像素偏移且对最终画面再次 Alpha 混合；背景缓存可能不是本次效果前的画面 | 使用归一化屏幕 UV 偏移，只应用一次覆盖率；BackBufferCopy 在自己的发光层之前更新背景。直接连续计算偏移，不引入原8位中性缓冲解码所需的1/255量化补偿。仍是逐效果合成，非全局扰动缓冲 |

## 不能隐去的差异

1. **HDR 与最终曝光**：官方 `PostFX_LookupTable.fx` 在曝光后包含 TONEMAPPER=2（white=6）及可选 LUT；调用受宏、technique 与运行状态影响，不能只粘一条公式就声称恢复了整条链。Godot Compatibility 没有内部 HDR，离屏高光可能先被截断，亮度和饱和区域仍可能不同。依据 [Godot 4.7 渲染架构](https://docs.godotengine.org/en/4.7/engine_details/architecture/internal_rendering_architecture.html)；本轮没有擅自切换整个游戏渲染器或添加猜测曝光。v0.5.0.6 Q 光晕的 SDR 亮度适配保留并明确属于定制。
2. **深度与遮挡**：球壳只有平地交线；2D 地形／建筑／单位不提供原版全场景3D深度。光源只影响隔离3D对象，不能照亮整张2D地图。
3. **统一扰动缓冲**：多个爆炸重叠时，当前逐效果 BackBufferCopy 与原版先汇总所有扰动再采样一次不是同一管线；不能把单个法线公式通过等同于全场景一致。
4. **原引擎 CPU**：XML 与公开 shaders 不包含全部粒子求解、动画混合、碰撞和后处理调度 CPU。当前差异不能通过“素材已导入”或截图非空来关闭。

## 验证与复现

状态：`pending_user_visual_confirmation`，未宣称原版实机逐像素一致。

- `ra3_fx_contract_regression` 19：独立按官方公式计算预期，对实际 GPU 像素断言 Shield／Lightning 三档透明度、Proton mask、GPU Gamma 顺序、黑贴片不遮底、不同覆盖 Alpha 不二次削弱光能、法线归一化与 0.08 UV 偏移、随机 Alpha 范围及大球淡出曲线。
- 既有专项：future_presentation 58、gunship_presentation 40、future_glow 12、expansion 63、native 93。共 **285 项通过**，全部退出0，无脚本错误、资源泄漏，前后源码／资源指纹一致。
- 汇总 `refs/ra3-expansion/native-fx-final/audit.json`，各 suite 含 run.log/result.json。Future 专项增加 `neutron-battle-{0.2,1.2,1.8,2.4}.png`；Gunship 专项增加 `impact-battle-{0.1,0.5,1.1}.png`。已查看战场球壳和质子炮阶段画面，不只看透明离屏图。
- 实际环境：Godot 4.7.2 Compatibility、WASAPI；隔离项目 `refs/ra3-mirage/integration-test/project` 通过既有 junction 使用本工作区代码／资源；独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`，网络／服务／数据库均为 none。
- 重跑单个场景前先创建报告目录，再设置 `IRON_TIDE_REPORT_DIR` 为其绝对路径；Godot 参数 `--path refs/ra3-mirage/integration-test/project --rendering-method gl_compatibility --audio-driver WASAPI --scene res://tests/ra3_fx_contract_regression.tscn`。不能只看退出码，必须同时核对 result.json 失败数与日志。

本次没有调整伤害、射程、技能冷却或移动速度；没有提交、推送或打包。重启当前游戏并新开战局后可复测普通／英雄中子球、质子炮命中与多个效果叠加。
