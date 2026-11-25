# Upheaval 对照与单位 GM 测试工具

2026-10-28。本次对照范围为未来坦克 X-1、先锋武装炮艇的受损状态、受损速度及既有武器／技能回归；不是整套 SAGE CPU 引擎复刻完成声明。

## 来源与优先级

- EA `CnC_Modding_Support`，提交 `3aad8e412961ab543192ae70f8503dc8e178e095`，`Uprising/Xml`、`Schemas`、`Shaders`。
- [Bibber 的 Upheaval 1.16 源码](https://bibber.eu/downloads/ra3-upheaval-source-code/)。感谢作者 Bibber；本次使用其 XML 作第二份行为对照。Upheaval 是将起义单位移植进 RA3 的社区 MOD，不能把它的修改当作起义官方原值。
- 包 SHA256：`8bb4cea9d15d8c00f153b169b64de292873038a602e65fd5451306aa1825588f`。对照文件：`Upheaval/Data/Mod/Units/Future Tank X-1/{GameObject,WeaponTemplate}.xml`、`Harbinger Gunship/{GameObject,WeaponTemplate}.xml`。
- 运行贴图来自本机 Steam《起义》资源；不是试玩版，也不是从网上找的替代贴图。`tools/ra3_mirage/import_damage_states.py` 可重新导入，输出 `assets/ra3/expansion/damage/rules.json` 记录 XML、schema、shader 和输入纹理哈希。

## 对应关系

| 来源字段／状态 | 原定义及本次处理 | 实现／验证 |
| --- | --- | --- |
| `ActiveBody.xsd` 两个 MaxHealth 百分比默认值 | DAMAGED 为 66.666666%，REALLYDAMAGED 为 33.333333%；单位无覆盖 | 导入默认值；按当前最大生命计算，维修可逆 |
| Future `DAMAGED` | `B_Fender01 → AlliedVehicleDamageSmoke`；EA 与 Upheaval 相同 | `ra3_damage_state.gd` 骨骼发射源 |
| Future `REALLYDAMAGED` | `AUFutureTank → AUFutureTank_D`，同骨骼烟、火、FireLight | 原零售贴图，局部 3D 灯光，修复后恢复原材质 |
| Gunship 两受损状态 | `FXDamage01/02` 烟；重伤追加火、`AUGunship_D`；EA 与 Upheaval 相同 | 两独立发射源；原有 `FXCon_L/R` 尾迹保留，无额外 FireLight |
| `AlliedVehicleDamageSmoke.xml` | 35 帧寿命、每帧 1 粒、尺寸 3–10、增长 .5／阻尼 .94、36 帧蒸汽纹理、4 段颜色／alpha | 原 XML 通用采样，30 原生帧／秒，粒子释放后不锁在车身上 |
| `AlliedVehicleDamageFire.xml` | 寿命 15–20 帧，原 FireScroll3、尺寸 5–10、颜色倍率 2–5，Additive | 独立颜色与纹理采样，避免 Godot COLOR 已含纹理而二次相乘 |
| `GpuParticleDistort.fx` 中画质路径 | 相邻视频纹理帧插值再乘粒子颜色 | 移植中画质路径；像素测试与 CanvasItem 单次 alpha 合成对比 |
| Future Locomotor `MaxSpeedDamaged=75%` | 原配置已有但未消费；本次接到实际地面速度计算 | 受损最高速 75%，维修恢复 100%，不改变原转弯参数 |
| Gunship Locomotor | 没有受损速度覆盖，schema 默认 100% | 保留飞行速度与 80% 盘旋速度；不照搬坦克降速 |
| Gunship WeaponTemplate 差异 | 官方机炮射程 300，Upheaval 改为 400；官方主炮最小射程 50，MOD 为 100 | 保持 EA 原值，地图换算后为机炮 450、主炮最小 75 |
| Q 接近／横扫与炮艇武器、模式、飞行 | 保留上一轮修正及官方源值 | 重跑 riot、future、gunship presentation／flight、expansion 专项 |
| 旧通用低血冒烟 | 之前所有单位低于 42% 都画灰色圆团 | 两单位使用原版受损效果后关闭该重复层；其余单位不变 |

## GM 操作

主菜单 **后台 → GM 控制台 → 进入单位测试场**；也可在正常战斗按 **Ctrl+G**。G 单键仍是警戒。主菜单旧快捷键提示已更正。

- 中文名称／ID 搜索，选择敌我、1–50 数量、军衔、血量百分比；单位生成在当前可见区域，地面单位避开建筑、水域和已有单位，空间不足会报告实际数量。
- 飞行器按机身视觉高度调整位置，避免只看到地面阴影。快捷生成未来坦克＋炮艇；v0.5.10起靶标包括步兵、灰熊及全部已注册的R3单位（当前幻影、未来坦克、先锋炮艇）。名单每次从GameData.unit_index读取，新增R3单位自动加入；不绕过地形／空间检查。v0.5.11.1起不再关闭物理回调：地面静止，空中靶标通过既有flight适配盘旋／悬浮并禁止还击；死亡走正常释放流程。旧special.gm_stationary存档同样适用，不改变官方武器／飞行参数。
- 对框选单位设置军衔、血量，重置冷却与弹药，停止并关闭自动开火。正在执行或接近目标的未来坦克 Q 不取消、不退款。
- 只清除带 GM 生成标记的单位，并清理选择／编队引用；不使用全场秒杀。生成标记与静止靶标通过既有 `special` 状态存档。
- 测试场不创建 AI、不推进波次、不触发胜负或局外奖励；返回大厅退出。正常对局保持原流程。`gm_unit_lab` 加入存档字段白名单，避免恢复成普通计胜负战斗。
- 浮窗锚定右侧全高、内容可滚动；所有作弊勾选按字段同步，不再按 CheckBox 遍历顺序误改新控件。

## 验证与边界

专项 `iron_tide/tests/gm_ra3_damage_regression.tscn` 走实际 GM 按钮信号、单例、Battle hook 和场景切换，覆盖搜索、非法 ID、敌我、军衔、血量、站立靶标、存档恢复、清理边界、飞机机身可见、受损贴图、粒子状态、维修、速度，以及测试场不结算。包含实际 Compatibility 渲染截图和独立 alpha 像素断言。

最终回归记录在 `refs/ra3-expansion/gm-damage-verified/audit.json`；隔离工程 `refs/ra3-mirage/integration-test/project` 使用同一真实脚本／资源，单独用户目录 `CodexIronTideValidation/ra3-mirage-20261027`，显式窗口 1600×900。网络、服务、数据库依赖均为 none。测试工程 autoload 同步当前主项目，不把缓存缺少新 autoload 导致的编译错误当业务错误或通过。

表现仍为 `pending_user_visual_confirmation`。当前为原版粒子中画质分支和 Godot 连续世界适配，没有实现高画质场景深度软交界／纹理扰动、SAGE 随机种子逐位一致、跨 2D 建筑的完整深度遮挡。FireLight 仅照亮该单位的独立 3D 视口，不能照亮整个 2D 地表。停在屏幕外时清理残留粒子；粒子不是存档权威对象，恢复时从当前血量重建。原有球体扩张后中子伤害周期和完整 CPU 光束几何证据缺口仍见 `RA3_FX_AUDIT.md`、`RA3_RIOT_AUDIT.md`，不因这轮对照消失。

最终结果：GM/受损 66、future presentation 58、gunship presentation 40、gunship flight 15、expansion 63、riot 31、savegame 120、allied abilities 200、native 93，共 9 组 686 项通过，无 SCRIPT ERROR/ERROR/资源泄漏。主工程 editor import 退出 0、无脚本错误；damage/rules.json 中全部来源哈希复核一致。

并行工作区审计：回归期间仅 display_preferences.gd 和未参与本套的 display_settings_regression.gd 发生变化，RA3、GM、存档相关脚本与资源没有变化。显示设置由独立任务维护，原样保留；本测试显式 --windowed --resolution 1600x900，且测试场景使用固定 1600×900 SubViewport。对最终显示设置版本又运行完整 GM/受损/测试场入口 66 项，全部通过、无错误，运行前后全脚本资源指纹一致，补验记录 refs/ra3-expansion/gm-damage-confirm/audit.json。该补验不重复计入 686 项。没有将并行显示设置的历史版本声称为本轮交付。
