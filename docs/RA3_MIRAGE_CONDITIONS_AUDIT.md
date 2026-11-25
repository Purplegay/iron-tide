# 幻影坦克模型状态与漏接清单 · 2026-10-28

本轮针对 R3MIRAGE：逐项读取官方 SDK 的七项 Draw 声明（包括 HeadlightDraw2 引用）、主单位行为、原始 SKN 容器和运行消费者。不是所有 RA3 兵种的全量验收。SDK XML 是配置，不等于完整 SAGE 引擎源码。

## v0.5.6.5 本次修补

| 原始来源 / 条件 | 原始值 | 原问题 | 当前实现 |
|---|---|---|---|
| `Schemas/xsd/Modules/ActiveBody.xsd` | DAMAGED=66.666666%，REALLYDAMAGED=33.333333% | 幻影只走通用42%低血烟雾 | `Ra3Mirage.damage_state` 按当前最大生命判断 |
| `AlliedAntiVehicleVehicleTech3.xml / TruckDraw` 的 REALLYDAMAGED 和 REALLYDAMAGED DISGUISED | 同一 SKN；身体贴图替换为 `AUAntiVehicleVehicleTech3_D` | 渲染器始终加载正常身体贴图 | `ra3_mirage_damage_visual.gd` 切换原版受损贴图，维修恢复；履带、法线和SPM不替换 |
| `ModuleTag_Draw_FX / DAMAGED` | `FX_BONE01`：VehicleDamageSmoke，FollowBone=true | 整个分支漏接 | 导入零售原 FX 骨骼位置，烟雾随当前车体方向和位置移动 |
| `ModuleTag_Draw_FX / REALLYDAMAGED` | Smoke + Fire + Fire02 | 火焰两层都没接 | 接三套原粒子定义/纹理，30原生帧换算，保留寿命、发射频率、颜色、大小曲线和图集帧 |
| `ModuleTag_Draw_FX / DAMAGED DISGUISED、REALLYDAMAGED DISGUISED` | 保留模型、不声明粒子 | 通用低血烟雾会破坏伪装表现 | 伪装时清除烟火，显形后恢复；底层受损贴图仍保留 |
| `Locomotor.xml / AlliedAntiVehicleVehicleTech3Locomotor` | MaxSpeedDamaged=75% | 配置文件有值，但实际移动不消费 | `_ramped_speed` 仅对RA3幻影应用，维修后恢复 |

修补不会把所有单位共享材质染黑；每车身体材质独立，受损纹理复用。粒子上限96/车，离屏、隐藏、载入运输工具清理粒子和积压计时，暂停冻结；从存档HP重建，不增加存档字段。移除幻影原生模型上的通用42%烟雾，避免两套重复。

来源为本机 `refs/ra3-sdk/installed/SAGEXML/Allied/Units/AlliedAntiVehicleVehicleTech3.xml`、相应粒子文件、ActiveBody schema、Locomotor。零售贴图与FX骨架来自已安装Steam《起义》1.1；FX_BONE01名称用社区W3X交叉确认，坐标以零售骨架为准。`assets/ra3/mirage/damage/conditions.json` 记录源/输出SHA256、完整Draw数据及版本差异。

资源重建：`python -B tools/ra3_mirage/import_mirage_conditions.py`。新增缺失的两张火焰图集通过既有 `extract_uprising.py --pattern '^Texture:(FXFire02|FXFireGrid)$'` 精确提取至 `refs/ra3-mirage/damage-state`；没有整库复制或下载新游戏资源。

## 明确仍未接齐的部分

| 项目 | 源码／资源证据 | 当前实现与缺口 |
|---|---|---|
| 车体发光、电弧、等离子网格 | 原SKN容器包含 NEWSKIN、NEWSKIN_TREADS、LIGHTNINGFX、GLOWFX、PLASMAFX；OBBOX01是碰撞盒 | `native/skin.json` 和 `_load_meshes` 只有身体、履带。三个FX网格缺失，需分别还原 Lightning.fx / DefaultW3D 材质及骨骼，不应把碰撞盒当外观补进去 |
| 伪装耳部射线 | TruckDraw 的 DISGUISED 分支：Bone_Ear_Left/Right → Primage_Disguise_Rays/Rays02 | 已有入伪装瞬间的 Primage_Disguise 壳特效，并不能代替两条持续骨骼射线；当前没有消费者 |
| 按地形/邻近物选择伪装物 | SpecialDisguiseUpdate：ScanRadiusForPropDisguise=100；Grass/Misc树1、Snow树2、Mud/Dirt/Cliff/Sand/Rock石头、Road卡车 | `_build_native_disguise` 固定 `disguise_tree`；缺地形映射和附近道具复制 |
| 夜间车灯 | HeadlightDraw2：NIGHT时在 fxheadlight_L/R 加 EX_Headlights | 当前没有夜间场景状态和车灯渲染；不应全天强行点亮 |
| 幻影场受损/EMP组合 | ShieldDraw 有 REALLYDAMAGED空模型状态；USER_6以及EMP/瘫痪也有状态分支 | `ra3_mirage_fx.gd` 按 field_active 播正反动画，没有通用模型条件优先级解析。并存状态的优先级与CPU选择需继续验证，不能凭注释就禁用Q的逻辑效果 |
| 退出场的车体动画过渡 | TruckDraw `TRANS_FromField` 为IDLA ONCE，普通/移动/选中状态脚本调用 | `Ra3BoneAnimation.advance` 只切IDLA/MOVA，未独立执行过渡状态；现有场壳正反播放并不等于车体状态机完整 |
| 英雄第二级散射 | CannonNodeVeteran1散射7路，Veteran2再散射3路；对应武器定义 | `Ra3Mirage.shoot` 只有一次候选遍历，未继续创建第二级节点；避免把已有英雄贴图/伤害加成当成全武器链已完成 |
| 原生悬挂和地形运动 | TruckDraw/Locomotor 的轮骨、坡面平滑、Pitch/Roll、Powerslide | 当前连续2D转向、MOVA动画、履带痕迹仍是适配，没有完整SAGE悬挂求解 |

### 基础 RA3 与《起义》的差异

导入器对比 Draw 节点和文本，除两处外一致：

- ShieldDraw：基础SDK有 `AFFECTED_BY_EMP USER_6`、`PARALYZED USER_6` 模型及动画状态；起义改为 `AFFECTED_BY_EMP PARALYZED` 模型组合，并移除上述两条动画状态。
- 英雄 LaserDraw 的 ColorEmissive：SDK为(4,4,4)，起义为(5,2,2)。

本次受损贴图/粒子/阈值没有版本冲突。上述差异单列，未借本次修补静默改写既有幻影场和光束。现有 `audit_sdk.py` 的若干runtime说明仍是历史文字（如“原生语音未接入”），不能直接当当前状态；实际语音/残骸消费者和专项已存在。

## 验证与边界

新增 `ra3_mirage_conditions_regression` 使用实际Battle/Unit/渲染材质和移动入口，覆盖阈值两侧、军衔改变最大血量、75%减速及RA2不受影响、三套粒子、伪装清理、旁车材质隔离、暂停/离屏、维修恢复、粒子上限与存档恢复。重伤渲染与正常渲染有显著像素差异；维修后贴图对象恢复，图像差异最多一个8位量化级。初稿逐字节相等断言因单像素蓝色相差1而失败，最终明确采用渲染量化容差，同时保留严格贴图对象检查。

本次是原资源与配置驱动的Godot适配：火焰2的Swirly/沿速度三维旋转、GPU软粒子场景深度和完整屏幕折射尚未重建，不能称为原SAGE粒子解释器。表现状态仍为 `pending_user_visual_confirmation`。
