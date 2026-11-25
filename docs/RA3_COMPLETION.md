# v0.5.9.1 · 三个 RA3 单位差距补齐

后续v0.5.10.1补固定挂点开火门槛：`Unit._weapon_uses_hull()`原来仅识别RA2数据标记，RA3幻影未带该标记，导致`_face()`不转车身且`_weapon_aligned()`直接放行。现显式识别Ra3Mirage，并从`Ra3Mirage.balance.raw.weapons`读取对应普通／英雄主炮的`AcceptableAimDelta=10d`。不能把旧实现描述成“已经用车身瞄准、只是2°过严”；它实际跳过了检查。原单位XML的`WeaponSlotHardpoint`及`Weapon.xml`两种主炮为依据；RA2炮塔和现有转速适配不变。

本次接续 [三单位审计](RA3_THREE_UNIT_AUDIT.md)，将已确认遗漏落实到游戏消费者。平衡仍以 EA 起义 XML 为准，Upheaval 只用于查漏；继续保留已确认的跨代目标血量适配。未来坦克没有因本次补齐再改伤害或任意更换炮口英雄颜色，其主炮、Q、晋升、状态动画和存档继续纳入回归。

## 来源与实际接入

官方 XML 位于 `refs/ea-modding-support/Uprising/Xml`，EA 来源版本 `3aad8e412961ab543192ae70f8503dc8e178e095`。`tools/ra3_mirage/extract_completion_rules.py` 提取原始字段及引用链，并记录8份源文件哈希，输出 `data/ra3_completion_rules.json`。媒体来自本机正版 Steam Uprising 1.1，不使用试玩版。

| 来源／触发 | 本次消费者与变化 | 验证 |
|---|---|---|
| Mirage CannonNodeRegular；英雄 Veteran1 → Veteran2 → End | `ra3_scatter.gd`：普通首跳5个，英雄首跳7个；英雄下一层每支最多3个，75原单位射程，20 CANNON，0.1秒延迟。PRISM和CANNON分别走原装甲映射与跨代适配，不把第二跳误当25 PRISM | 实际射击入口、第一／第二跳目标、延迟、单次英雄倍率、友军／空中排除 |
| Mirage Draw 附加网格及 DISGUISED ParticleSysBone | `ra3_mirage_extras.gd`：LIGHTNINGFX、GLOWFX、PLASMAFX绑定原骨骼；双耳原射线按30帧粒子时间、初始延迟、寿命、大小与透明度键发射 | 原3网格＋4伪装模型资源、双耳发射、暴露停止、实际渲染截图 |
| SpecialDisguiseUpdate TerrainData、附近道具及 TRANS_FromField | 树、雪树、岩石、卡车原网格；模拟层保存伪装选择。关闭场先执行IDLA一次，再回行进／待机；重新开场可打断过渡 | 地形映射、原动画循环边界、重开打断 |
| Harbinger三个WeaponSlotTurret、原武器模板 | `ra3_gunship_mounts.gd`：前机枪、侧前炮、侧后炮独立目标／弹夹／冷却／闪光；原转速、俯仰边界和1°／5°开火容差。停机不能绕过后勤开火门槛 | 真正Unit开火入口、一炮装填时另一炮开火、切换、旧状态迁移、读档、GM全炮位重置；持续射击跨完整弹夹 |
| WeaponProjectile BezierProjectile | `ra3_gunship_shell.gd`：炮口切线、空中起点、地面终点、500原速度、300原单位每秒追踪、固定散布；15Hz距离累计并连续显示，原弹体网格随切线朝向 | 曲线几何、15／60／120Hz同到达时刻、追踪速度、命中结算 |
| CreateObjectDie → AlliedGunshipAircraft_Dying → FireWeaponWhenDead → COL | `ra3_gunship_crash.gd`＋`ra3_wreck.gd`：空中完整残骸坠落，触地一次300 EXPLOSIVE、50原单位半径、友军半伤，然后分块；坠落过程为存档中的Projectile | 无提前伤害、中途读档、友军半伤、空中目标排除、触地不重复、停机／超时空抹除边界 |
| 炮弹及坠毁MetaImpactNugget | `ra3_meta_impact.gd`：原冲击半径／推力／衰减区域，运行时有界击退，调用真实Godot碰撞；已击退／冻结／登载等状态不叠加 | 真实位移、无额外伤害、有界回收 |
| FX_AlliedBomberDie四个粒子系统 | `import_crash_media.py`＋`ra3_crash_fx.gd`：原爆闪、火焰动画图集、烟雾图集及LightSource；发射数量、寿命、颜色、速度、大小取原XML。LightSource接照明，不能画成巨大光斑 | 42个原发射实例、图形截图、读档清理旧时间线特效 |

`import_completion_media.py`记录22项模型／纹理／声明指纹；`import_crash_media.py`另记录原死亡FX及纹理指纹。只读提取的新Fire03纹理由 `extract_uprising.py --pattern '^Texture:FXFire03$'`、`convert_uprising_media.py`生成；原始文件和转换报告在忽略目录 `refs/ra3-expansion/crash-media/`。

## 不能混淆为原引擎完全一致的边界

- 炮弹已有曲线飞行；当前三次曲线使用原百分比控制参数、炮口切线和直飞距离上限。SAGE `FIRE_STRAIGHT_THEN_CURVE` 的完整分段CPU求解器尚未确认，因此不能声称已经逐帧复刻该算法。
- 散射候选按距离排序，一条链不回溯、不重复命中；这是显式Godot仲裁。原CPU对多个分支争用同一目标的内部仲裁未确认。
- 坠落重力180、冲击质量换算、0.25秒速度衰减和水平碰撞是显式适配，未复刻SAGE完整刚体和地形碰撞。原MaxX/YRotationVelocity=50保留。DYING阶段骨骼持续火烟尚未完整接到COL原骨骼；本次已接死亡瞬间及触地的原爆炸，不能将两者混称。
- 当前地图默认Misc，已支持地形元数据及附近原生道具分类；没有新增完整SAGE地形分类／任意场景道具复制系统。附加网格和TRANS_FromField已接，完整组合状态优先级和昼夜车灯仍有引擎差异。
- 死亡爆炸采用2D粒子和PointLight2D，保留原图集／数值，不等于完整HDR、3D场景照明和GPU折射。跨子视口模型不会自动接受同一盏2D灯。
- 本次不是完整SAGE引擎移植；没有相应系统的继承模块、悬挂及任意地形深度不能仅凭导入XML宣称完成。

## 回归入口

新增 `iron_tide/tests/ra3_completion_regression.tscn` 从真实战斗场景、Unit、Projectile、Snapshot和渲染器验证本次链路。旧弹匣测试改用真实独立炮位状态准备；没有删除原持续射击、伤害、动画或存档断言。共用不可变车身网格测试从固定子节点下标改为MeshInstance3D筛选，附加FX节点不再误计为车身。

环境为 Godot 4.7.2 / OpenGL Compatibility / WASAPI；隔离项目 `refs/ra3-mirage/integration-test/project` 通过junction消费实际 `iron_tide`，独立用户目录 `CodexIronTideValidation/ra3-mirage-20261027`。网络、数据库、服务端口均none。未停止玩家游戏、未改玩家存档。最终结果与指纹检查登记在 [验证记录](VERIFICATION.md)，完整日志／截图在忽略目录 `refs/ra3-expansion/completion/`。
