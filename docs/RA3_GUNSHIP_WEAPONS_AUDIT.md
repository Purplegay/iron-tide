# 先锋炮艇武器与表现对照 · v0.5.6.4

## v0.5.6.4 范围问题的实际根因

用户再次反馈大面积光圈。此前 v0.5.6.2 只核对 XML／网格及提升缓冲清晰度，未解决 CPU 取值差异；“参数一致”不能说明执行相同。

本次读取本机 Steam 正式版《起义》1.1 `Data/ra3ep1_1.1.game`，SHA256 `b1da83efd229570bab9de3a14e48b2d1e6128e302bd52384858fa8a413ae330b`。`RenderObjectParticleUpdateModule` 构造函数 `0x6e9720` 调用 `0x633640`：后者在 `0x633670–0x63369f` 计算 High-Low，仅正区间进入 RNG，否则返回 High。不是交换上下限，也不是倒序线性插值。

普通 `FXAlliedGunshipProtonSW` 与英雄 `FXAlliedGunshipVetSW` 的 SizeRate.y/z 都是 Low=.75、High=.1。旧 Godot helper 在 .1–.75 随机，原程序固定 .1；这是径向扩张最高 7.5 倍的来源。修正共用 `range_value`，保持原资产不变。`0x6dd9e0` 的逐帧加 rate 再乘 damping 支持径向渐近尺度 `.1/(1-.95)=2`；不以此宣称 30Hz 粒子调度已完整还原。

回归用相同测试场景、镜头和随机种子采样 0.1／0.5／1.1 秒，旧实现 15 项中 8 项失败，新实现普通／英雄波纹尺寸均通过。共享 helper 另覆盖未来坦克／炮艇重伤火焰负区间。原炮击伤害及半径完全未改。原程序静态证据由 `tools/ra3_mirage/audit_particle_range_cpu.py` 固定 SHA 和指令断言复查；它不是执行原游戏的 oracle。

证据目录 `refs/ra3-expansion/shockwave-range/`：`before/`、`after/` 的六张同场景 PNG 和 footprints.json、`native-cpu.json`、专项结果。HDR 曝光、场景深度、粒子完整调度及原生随机流仍为 Godot 适配，状态 **pending_user_visual_confirmation**。

## v0.5.6.2 历史对照（下方当时未确认的范围问题已由上节更新）

2026-10-28。用户反馈炮击特效范围大、不清晰，要求按 Upheaval 核对机枪及各种武器状态。本轮修改在 `C:/Users/admin/IronTide` 的 `codex/ra2-independent` 共享 checkout 内，保留已有未提交工作，没有提交、推送或打包。

## 来源

- [Bibber Upheaval 1.16 源码](https://bibber.eu/downloads/ra3-upheaval-source-code/)，感谢 Bibber。包 SHA256 `8bb4cea9d15d8c00f153b169b64de292873038a602e65fd5451306aa1825588f`。这是社区移植，不是起义引擎 CPU 源码。
- 包内 `Upheaval/Data/Mod/Units/Harbinger Gunship/{GameObject,WeaponTemplate,FXList,FXParticleSystemTemplate}.xml` 和 `Art/Units/Harbinger Gunship/*.w3x`。
- EA `CnC_Modding_Support` 提交 `3aad8e412961ab543192ae70f8503dc8e178e095`，`Uprising/Xml/GlobalData/{FXListSoviet,DamageFX}.xml`、三个 `FXParticleSystems/{BulletHitAlliesSpark,BulletHitAlliesFlash,CritHitS}.xml`、`Schemas/Modules/TracerDraw.xsd`、`Shaders/{FXLightning,GpuParticle}.fx`、`CommonParticle.fxh`。
- Upheaval 引用基础游戏的 FXTracer、FXTracerHeroic、FXBulletHit、FXLenzFlare03、FXStreak，没有在炮艇包里另附这些基础纹理。使用本机 Steam 正式版起义提取，未用替代绘图。
- `tools/ra3_mirage/import_gunship_weapons.py` 直接读取 ZIP 中的原 XML，输出 `assets/ra3/expansion/fx/gunship_weapons.json`，记录来源哈希；导入同时核对已有炮击粒子定义和原始核心／冲击波顶点。

## 已核对／接入

| 状态或字段 | XML 事实 | 本轮处理 |
| --- | --- | --- |
| 默认炮击 | SkinGuns + Cylinder01；槽 2/3；FXGun_FR/BR、FXMuzzle_FR/BR | 保留原几何、双炮口、FireLight、普通／英雄弹体与 FXList |
| `WEAPONSET_TOGGLE_1` | 显示 SkinMachinegun，隐藏双炮；槽 1、FXGun_FRONT、FXMuzzleFront | 保留真实模式切换，不调用 XML 未引用的 DEPLOY 动画 |
| 三个 `TurretSettings` | TurnRate 360、PitchRate 180、MinimumPitch -45°、PitchHeight 90% | 原实现转向 180，前机枪俯仰 20／限 30；改为原值。侧炮待机扫描 0–45° 不再误作攻击限制 |
| 普通曳光 | FXTracer；15–30 长、8 宽、20–25 速度、35 帧、每帧 .5–.8 | 读取原 XML。发射数量按 30Hz 累积分数，跨发保留余数，修正每发取整导致恒定两条 |
| 英雄曳光 | FXTracerHeroic；20–35 长，红头白尾；WEAPON_UPGRADED_01 | 读取原纹理／颜色／尺寸，视觉射到端点后触发 TracerHitFx |
| 普通伤害 FX | SOVIET_MACHINEGUN → FX_BulletHitSoviet；50ms throttle | 真实伤害路径补 BulletHitAlliesSpark/Flash，在致命伤害前捕获位置，死亡后效果仍存在 |
| 动画火花 | FXBulletHit，8×8／64 帧，Size 8–10，延迟 4 帧后存活 8 帧 | 原始纹理、原色、30Hz 图集帧插值；图集列数不放大四边形 |
| 命中闪光 | FXLenzFlare03，Size 10，增长 3，存活 4 帧，颜色衰减至黑 | 按 XML 采样，不画手工圆圈 |
| 英雄命中 | FX_BulletHitSovietVet 继承基础命中并追加 CritHitS | 原 FXStreak、5–6 粒、2 帧尾迹、颜色／速度／寿命范围；纯表现，不再施加第二次伤害 |
| 清晰度 | 原生纹理没有缩成 384；固定 384 是本项目离屏缓冲 | 按画布、镜头和显示 stretch 计算实际像素密度；128 像素档位、单效果上限 1536、同时效果 8M 像素预算；同一效果保留高水位，预算降低时才缩小 |
| 生命周期 | 子效果应独立于目标／弹体存在 | 爆炸、曳光、命中节点都有数量上限和寿命；读档清空上一时间线的表现节点 |

## “范围过大”的结论与边界

炮击伤害半径为原 50 单位（本项目 75），波纹有自己的 StartSize、SizeRate、SizeDamping 和寿命，不能把伤害半径当作它的视觉边界。Upheaval 的 20 个普通／英雄命中粒子定义与本项目导入定义逐字段一致。核心与冲击波 W3X 顶点逐点对照误差小于 0.000001；控制骨骼、容器无额外整体缩放。此次没有找到“导入时多乘一个尺寸”的证据，未通过任意缩放掩盖问题，也没有扩大伤害范围。

这不证明运行表现与起义逐帧相同：DRAWABLE 的 CPU 更新、HDR 曝光／色调映射、场景深度软交界仍有适配差异。现有扩张积分保留，不把它写成已核实的原引擎实现。大面积波纹仍保留，视觉范围是否需要进一步调整，须结合原版实机和用户复核。

机枪 `SweepSpeed=3` 在 XML/schema 中存在但缺 CPU 单位和算法；已保留来源，未编造横扫算法。当前曳光为 2D 投影适配，Ricochet／OrientToObject 使用入射平面方向，未复刻三维碰撞法线。继承的 Impact_Bullet 音频与水面专属波纹未在本轮新增。炮口闪光持续时间仍是此前短闪适配，不宣称来自 XML。

Upheaval 的机枪射程 400、最小射程 100，跟 EA 起义原值不同。用户本轮要求武器表现，继续保留已确认的 EA 战斗规则、价格、射程、伤害／跨代适配，不隐含导入 MOD 平衡改动。

## 验证

目标环境 Godot 4.7.2 / OpenGL Compatibility / RTX 5060 Ti / WASAPI；隔离项目 `refs/ra3-mirage/integration-test/project` 指向当前源码，用户目录 `CodexIronTideValidation/ra3-mirage-20261027`。窗口指定 1600×900，没有修改用户显示配置；网络、端口、数据库和服务为 none。

专项：`tests/ra3_gunship_weapons_regression.tscn` 覆盖模式俯仰、超出待机扫描角的攻击瞄准、两种军衔、分数发射率、英雄专属命中、致命伤害、图集延迟／尺寸、实际镜头密度、缓冲上限、读档清理。另跑 gunship presentation／flight、expansion、future presentation、savegame、GM damage 共 7 组。最终证据与计数登记在 `VERIFICATION.md`。

客观检查与截图不等于用户视觉验收；状态 `pending_user_visual_confirmation`。
