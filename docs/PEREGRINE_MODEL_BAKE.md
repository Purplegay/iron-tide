# 极地游隼模型烘焙 · v0.30.2

## v0.30.4 游隼细节追加

2026-11-18，按用户“游隼也精细一点”追加制作。沿用同一个机身与32向RA2坐标，增加翼面接缝／铆钉、发动机检修盖／散热格栅、加强环、喷口叶片、翼下挂架支撑与局部导航灯。座舱高光改为贴合弧面。4506三角面只在离线制作时使用，游戏继续绘制单方向贴图。

复用 `mechanical_mesh.mjs` 的金属材质采样、结构自阴影、高光和缝隙暗部，未修改共享渲染器。使用已有 `hero-tank-armor.png` 材质，本批没有调用AI新生图。机身和独立阵营／发光遮罩均以2倍超采样烘焙，单格384×256、图集3072×1024，线性mipmap；两份PNG合计1221857字节。资源分辨率提高，`BODY_SCALE=.825`不变，实际32向平均可见宽度为普通ORCA的1.0041倍。

蓝色涡轮、翼灯和肩灯用独立发光遮罩驱动；四次邻域采样产生小范围动态光晕，与呼吸周期同步，迫降或引擎离线时关闭。沿用原绘制提交，无额外灯光、粒子或场景节点。尺寸增加使两张RGBA8纹理含mipmap的理论占用约从18MiB增至32MiB；未进行本批全局帧耗时测试，不把离线烘焙或节点数不变当成性能无变化的证明。

后台5套684项检查通过：`peregrine_art_regression`212、`peregrine_visual_regression`27、`peregrine_card_demo_regression`197、`peregrine_base_regression`113、`peregrine_service_regression`135。覆盖32向朝向／开火位置／像素选择、原生尺寸、实际GPU阵营色与呼吸灯、迫降恢复及存档重建、普通飞机隔离、英雄预览切换与技能演示、无玩法状态和场景节点增长。Godot后台导入及Node语法检查通过，最终日志无脚本／引擎错误。

证据根 `.validation/peregrine-detail-20261118/`：`summary.json`、各套件结果、`review/peregrine-runtime.png`。只导出一张三方向私有桌面预览；两套headless，三套GPU加预览使用未激活私有桌面。沿用本工程隔离验证项目引用当前源码，APPDATA／LOCALAPPDATA逐运行隔离，Godot4.7.2／OpenGL兼容渲染，服务／数据库／协议均未使用。退出审计见 `post-run-audit.json`。

状态：`pending_user_visual_confirmation`。请在游戏中确认细节、灯光和缩放后的清晰度；没有打包、提交或推送。

---

后续：用户已在v0.30.3授权制作另外两款皮肤及英雄雷铸，进展见[三款模型外观](MODEL_SKINS_0_30_3.md)。本文下面保留v0.30.2当批记录。

2026-11-18。用户指定游隼采用英雄灰熊制作方法，并核对武装直升机、恐怖机器人能否复用。本轮实现游隼；另外两款只核对素材与动作来源，保留现有皮肤及尺寸。

## 制作与接入

- `ra2pipe/peregrine_model.mjs`：一个2436三角面的机械模型，白金分层翼甲、曲面机身、双涡轮、蓝色座舱、双尾翼和四条翼下挂架。使用FALC的模型坐标、HVA变换和RA2固定等距投影，离线旋转32次。英雄灰熊原方案为原生体素上叠加外装；本次沿用坐标／烘焙方法，游隼机身本身为新制作的完整几何体。
- 每格288×192、3倍采样，8×4图集。32帧哈希各不相同，均有透明留白。单次模型渲染采用深度缓冲；运行时直接选择一个方向，不混合或镜像方向，不实时生成网格。
- `assets/cosmetics/heroes/peregrine_polar_32.png` 为机身，`_mask.png` 为阵营色／发光遮罩，合计135842字节；JSON保留源素材指纹、边界、机头与双发动机坐标。尺寸经过实际原生ORCA的32向可见宽度核对，`BODY_SCALE=.825`时平均宽度比例约0.9996。
- `peregrine_art.gd` 接入现有 `hero_art` 绘制、点击、机头开火及选框路径。阵营色使用独立遮罩；呼吸灯由可暂停的外观时钟驱动。普通ORCA仍走原生路径。
- `peregrine_visual.gd` 的气流根部读取烘焙发动机坐标；原有悬停、落地起落架、维护与迫降烟雾保留。实际迫降时机身变暗并熄灯，恢复后按真实飞行高度重新点亮。
- 养成预览、天赋示意、联动示意、额外出场和两张契约卡演示同步。作为对照的普通飞机保持原生外观；循环演示倒回普通阶段时清除英雄渲染器和气流。仅外观时钟变化，不推进补弹、维修或其它战斗状态。

复现烘焙（只读原版游戏素材，输出上述三份项目资源）：

```powershell
node ra2pipe/peregrine_model.mjs 'C:/Program Files (x86)/Steam/steamapps/common/Command & Conquer Red Alert II'
```

## 两款现有皮肤的可行性

| 单位 | 已核实来源 | 同路线的实现边界 |
| --- | --- | --- |
| 武装直升机 | `SCHP.VXL/HVA`有3个部件、2个姿态；部署后`SCHD.VXL/HVA`为独立模型；原展开过渡使用`SCHPDEPL`动画 | 最适合继续复用原生模型坐标。飞行机身、旋翼、部署炮身应拆开烘焙并沿原状态切换；展开必须有单独过渡帧，不能只用一套静态32向代替。黑曜夜枭本轮未替换。 |
| 恐怖机器人 | 原版有`DRON.SHP`，没有`DRON.VXL`；现行序列为8向、每向6帧步行／4帧攻击 | 可以采用同一套建模后烘焙的方法，但不能直接使用灰熊的体素外装流程。需要明确四条腿的同一骨架，再制作步行、停步、扑击姿态并烘焙32向；步态按移动距离推进。现有140%尺寸和皮肤本轮未修改。 |

## 验证与边界

后台10个套件共1988项断言通过：

| 套件 | 检查数 |
| --- | ---: |
| `peregrine_art_regression` | 212 |
| `peregrine_visual_regression` | 27 |
| `leizhu_art_regression` | 179 |
| `peregrine_command_demo_regression` | 252 |
| `peregrine_defense_demo_regression` | 306 |
| `hero_combo_demo_regression` | 256 |
| `hero_arrival_demo_regression` | 311 |
| `peregrine_card_demo_regression` | 197 |
| `peregrine_base_regression` | 113 |
| `peregrine_service_regression` | 135 |

包含32向真实消费、机头与世界朝向一致、像素点击与透明边界、原生尺寸、GPU阵营色／呼吸灯、真实迫降／恢复、对局快照重建外观、普通／英雄演示切换及玩家档案不写入。最终运行日志无脚本／引擎错误。`node --check`及本轮目标文件空白检查通过。

证据根：`.validation/peregrine-model-bake-20261118/`，汇总 `summary.json`，各套件 `result.json`／`godot.log`。Godot4.7.2；头less两套，其余在未激活的Windows私有桌面使用OpenGL兼容渲染／RTX5060Ti。隔离项目引用当前源码，APPDATA／LOCALAPPDATA逐运行隔离；未连接服务、数据库或外部协议。退出审计 `post-run-audit.json` 为零残留，输入桌面始终为Default。

没有导出游戏截图；只查看一次烘焙图集。没有打包、提交或推送。本轮验证不等于六方性能验收，也不证明概念图还原度已被用户接受。状态：`pending_user_visual_confirmation`，请在实际游戏中确认机身观感、大小和悬停效果。
