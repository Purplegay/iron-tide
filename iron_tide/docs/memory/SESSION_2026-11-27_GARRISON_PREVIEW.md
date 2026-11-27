# 驻军建筑的战场人数预览

## 原版依据与选择
- 本机 Steam 尤复 `ra2md.mix > conqmd.mix > PIPS.SHP` 第 6、7 帧（零基）分别是 7×14 空位和 6×13 绿色驻军小人，均按零售 `PALETTE.PAL` 提取。归档和哈希见 `assets/ra2/pips/garrison/source.json`，可用 `tools/yr_garrison_pips.mjs` 复现。运输载具继续使用 `PIPS2.SHP` 的图标。
- `refs/ts-ra2/src/engine/renderable/entity/PipOverlay.ts::createBuildingOccupationInfo` 是公开移植参考：使用上述两帧，按 `maxNumberOccupants` 绘制己方/盟友建筑的占位与空位，显示锚在地基边上；该参考只在已有人驻扎时绘制。没有把该参考当成零售程序逐帧实测。本机 `rulesmd.ini` 中 `CAHSE01`、`NABNKR` 的 `CanBeOccupied=yes` / `MaxNumberOccupants=5`；生化反应炉走 `InfantryAbsorb` / `Passengers=5`，非原版民房驻军类型。
- 为满足进驻前预览，Iron Tide 主动扩展为中立可驻军民房也能在悬停时显示全空容量，己方/盟友空楼同样显示；敌方不显示。使用现有真实占地投影于地基下方居中，8 屏幕像素间距，保持图标原图像素尺寸；锚点和间距不声称是零售逐像素复刻。

## 实际改动
- `scripts/ui/garrison_indicator.gd` 单独读取 `CivilianOrders.slots()` 和建筑实际驻军列表，只计仍存活且确实驻扎在本建筑的单位。利用 `BattleRequest.friendly()` 支持盟友；中立仅出示容量，不读取内容。普通建筑、施工中、隐藏、销毁均不显示。
- `battle.gd` 在既有血条覆盖层和能见度检查后绘制，鼠标悬停复用战场真实拾取；`transport_indicator.gd` 移除旧的建筑方格绘制。未改变进驻门槛、伤害、撤离、运输或存档格式。容量预览不替代进驻光标对当前步兵和血量的检查。

## 验证范围
- Godot 4.7.2 无头，独立用户目录，实际战场场景；`tests/garrison_indicator_regression.tscn` 原版/扩展两种规则共 44/44、退出 0、stderr 空。覆盖中立悬停拾取、逐个进驻、占领、选中满员、单人和全员撤出、无效引用、盟友、敌方隐藏、施工/销毁、碉堡/坦克地堡/生化反应炉容量、原版贴图加载。覆盖层安排重绘，但无头未验最终画面像素、不同镜头下的视觉遮挡或特定战役存读档。
- 原 `soviet_defense_regression` 更新断言目标；改前（隔离副本只撤回本批相关变更）和改后均 89/91，失败均为原有的「5 个可点击肖像」「撤出后 4 个肖像」两项，地图人数、空位与悬停断言通过，无 stderr。
- 证据：`.validation/garrison-indicator-20261127/{garrison_indicator,soviet_defense,soviet_defense_baseline}/`；未启动有头客户端，未写玩家存档，未打包或提交。
