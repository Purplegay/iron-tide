# 百合子手记背景切换

## 三列场景大图卡

场景栏使用全宽三列滚动网格。11 张卡片直接显示场景与百合子，人物衣装取该背景对应的首个篇目。图下显示场景名、锁定或使用状态。点击彩色卡片保存背景，灰色卡片的人物和景物共用灰度效果。

隔离手记回归 1278 项通过。Windows OpenGL 1600×900 截图确认教室和港口呈彩色，面包房、泳池等锁定场景中的百合子和背景均为灰色，图名位于下方。截图和日志在仓库根 `.validation/yuriko-score/cards-preview.png` 与 `cards-reg.log`。截图覆盖首屏，自动断言覆盖全部 11 张卡片。

## 独立场景栏目

手记导航新增「场景」，取代左上角地点菜单。11 个场景均可选择预览。锁定的条目以灰字列出，预览图使用灰度着色器，同时显示解锁篇目。已解锁场景可点击「设为手记背景」保存。离开预览恢复当前使用的背景。

隔离手记回归 1243 项、残章回归 270 项通过。Windows OpenGL 渲染同一港口背景，锁定和解锁时在右侧采样得到的彩色像素数分别为 0 和 5811。像素验证覆盖港口，其余场景共用同一预览函数。日志位于 `.validation/yuriko-score/scene-gallery-render.log` 和同目录 `scene-gallery-*-regression.log`（回归日志文件名以 `yuriko_school_regression.log` 或 `yuriko_bonds_regression.log` 结尾）。

## 初版地点菜单

`scripts/screens/yuriko_school.gd` 在首页左上角地点名加入场景菜单。南汐高中默认开放，港口和九格日常背景按 `Book.episodes` 与 `Bonds.stories` 共用的已读表判定。共用同一张背景的篇目读完任一篇即可。旧档按已读记录直接开放，进行中的书签不计入。`hub_scene` 随手记档案保存，阅读时使用篇目配置，回目录恢复所选背景。

Godot 4.7.2 在隔离档运行手记回归 1237 项、残章回归 270 项，全部通过。手记用例覆盖未读完、每篇读完后检查菜单、选择港口并重新加载档案。无头运行，菜单实际窗口观感待试玩。日志在仓库根 `.validation/yuriko-score/scene-picker-yuriko_school_regression.log` 和 `scene-picker-yuriko_bonds_regression.log`。
