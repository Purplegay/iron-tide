# 第二批养成扩展：首批皮肤实现

此页保留 v0.29.5 首版记录。最新的 300% 猎蛛尺寸、224 像素格无损 WebP、步态修正与夜枭火焰气流，见 [v0.29.7 调整记录](NIGHT_HUNTER_DETAIL_0297.md)；下述旧尺寸和 PNG 路径不再作为当前版本参数。

2026-11-17，工程版本 0.29.5。状态：`pending_user_visual_confirmation`。

本批接入武装直升机 SCHP「黑曜夜枭」与恐怖机器人 DRON「缝隙猎蛛」，通过现有兵种改装的皮肤选择装备，首批免费。其余英雄、技能卡和天赋仍按 [扩展设计](PROGRESSION_EXPANSION_2_DRAFT.md) 分批实施，本批检查不代表那些玩法或演示已经完成。

按最新反馈，两个机体均使用 AI 直接绘制的 32 个方向，运行时选择最近方向的单张图片。已移除光流补帧、相邻方向／姿态混合和机体模型投射。位置与转角继续使用既有表现插值，图片本身不交叉淡入淡出。RA3 组合编辑没有开放给这两个 RA2 单位；已写挂点接口只保留为预留。

| 内容 | 当前实现 |
| --- | --- |
| 图集 | 每款 32 方向 × 3 姿态，单格 128×128，图集 1024×1536；两张 PNG 合计 3,518,241 字节，约 3.36 MiB |
| 尺寸 | 以原版 8 个代表方向的可见宽度校准；夜枭含旋翼包络为原版 1.0 倍，猎蛛为 1.15 倍。各方向轮廓不同，不保证逐方向宽度完全相等 |
| 夜枭展开 | 飞行／半展开／完全展开三组独立方向图，跟随真实 `siege_progress` 切换，收拢反向播放；旋翼逐渐减速，独立炮管连续伸缩并跟随炮塔转角 |
| 猎蛛步态 | 站姿、两组对角迈步姿态，以站姿→迈步 A→站姿→迈步 B 循环；移动相位跟随单位既有步态，停止后回到站姿 |
| 灯光 | 游戏时间驱动 3.2 秒明暗周期；空闲未选中也更新。寄生／隐藏时不另留光点，死亡不继续显示本体灯层 |
| 原规则 | 碰撞半径、生命、伤害、导航、武器与部署地空层保持原逻辑 |

这是直接序列帧方案，方向间的透视和细节来自 AI 绘制，并非严格几何渲染。展开目前是三姿态切帧，步态是四拍循环；不将其描述为连续骨骼动画。方向一致性、旋翼对位、步态自然程度和实际游戏尺寸仍需用户试玩确认。

## 资源与制作入口

- 运行资源：`iron_tide/assets/cosmetics/night_hunters/night_owl_direct32.png`、`rift_hunter_direct32.png`，以及各自 JSON。炮管沿用独立的 `night_owl_model_gun.png` 32 向图层，机体不使用模型投射。
- AI 原稿和提示词：[direct32](concepts/progression-expansion-2/direct32/README.md)。使用内置 `image_gen.imagegen`；原稿位于 docs，不进入游戏运行资源目录。
- `ra2pipe/night_hunter_pack.gd` 仅裁切既有格子、等比例缩小并打包，不生成方向或动作，不进行帧间融合。以 `IRON_SKIN_SOURCE` 指定上述原稿目录，`IRON_SKIN_OUTPUT` 指定运行资源目录，用 Godot `--headless --path iron_tide --script <绝对脚本路径>` 运行。
- 渲染入口：`night_hunter_skin.gd`；灯光 shader：`night_hunter.gdshader`。使用原有改装、存档、单位绘制和选择轮廓入口。

## 本轮验证

Godot 4.7.2，隔离用户资料目录 `CodexIronTideValidation/night-hunters-20261117`。图形验证在未激活的专用 Windows 桌面进行，未打开用户可见游戏窗口；不连接服务或数据库。

| 检查 | 结果 |
| --- | --- |
| `night_hunter_skin_regression.tscn` | 694 项通过：RA2／扩展模式，实际改装保存／重载、对局快照恢复、敌我范围、原版尺寸比例、所有方向和姿态有效、逐帧仅一个图块、实时灯光像素变化、展开炮管、隐藏与点击边界 |
| `refit_skin_regression.tscn` | 148 项通过；故意制造存档写入失败的 warning 为预期断言场景 |
| `siege_chopper_collision_regression.tscn` | 56 项通过；部署／起飞碰撞规则回归 |
| 编辑器后台导入 | 通过，未发现脚本／shader 导入错误 |

本轮路径为 `.validation/night-hunters-batch1-20261117/`：`render-direct32/night-hunter-result.json`、`final-refit_skin_regression/result.json`、`final-siege_chopper_collision_regression/result.json`、`direct32-import.log`。三组进程已退出，资料目录各自隔离。未重新截图试造型；专项默认不落截图，显式设置 `IRON_SKIN_RECORD=1` 可记录真实渲染动作帧。旧模型阶段结果不作为本版验收依据。

表现验证覆盖实际 Unit 渲染器与改装预览，尚未由用户确认目标对局中的最终观感；本轮不声明六家对局性能达标，也未打包或发布。
