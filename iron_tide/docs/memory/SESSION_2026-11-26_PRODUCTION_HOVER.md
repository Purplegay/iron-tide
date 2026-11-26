# 2026-11-26 生产卡悬停简介

用户截图：悬停建造中的苏联矿石精炼场，只显示空白提示框。Godot 即使取得空提示文字，仍会调用自定义提示构造；旧版 `production_tooltip.gd` 始终创建面板。同时，有固定详情绑定的卡片一律禁用浮动文字，固定栏收起或关闭也没有回退。

- `production_tooltip.gd`：空白内容返回 null，不弹空框；绑定单位或建筑数据的卡片，仅在固定栏未显示正文时用短浮层显示名称与简介。
- `production_inspector.gd`：根据固定栏实际可见性与折叠状态决定是否回退；简介仍来自 `EntityDescription.text`，固定栏完整状态和操作说明不变。页签、队列图标、维修等非目录卡片不新增浮动简介。未改存档或显示偏好。
- `tests/production_sidebar_regression.gd`：真实战斗 HUD 注入鼠标悬停，覆盖经典/扩展、1280×720/1600×900、禁用卡片回退、关闭和重新开启固定栏。用建造中的苏联矿石精炼场验证展开时没有空弹窗，收起时 Godot 实际创建有中文简介的弹窗，移开时关闭。

修前离屏对照复现空弹窗和简介缺失，见 `.validation/production-hover-20261126-171001/before-render/`（仓库根相对路径）。修后隔离用户目录运行 `tests/run-navigation-building.ps1 -Suite production_sidebar_regression -Render`，261/261，退出 0，源文件审计稳定，报告在 `.validation/production-hover-final-171730/reports/`。未读取玩家存档，未重新打包，未测试其他分辨率或场外界面。
