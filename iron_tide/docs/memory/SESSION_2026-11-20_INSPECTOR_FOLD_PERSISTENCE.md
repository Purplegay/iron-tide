# 简介栏收起状态持久保存

用户明确要求截图中生产简介栏的收起要记忆，而非一次性。

- production_inspector.gd 新增 folded_changed 信号，仅用户按钮点击发出；clear 不再重置_folded，idle description也遵循状态。
- hud.gd 使用原 user://hud_panels.cfg，panels.production_details_collapsed 保存bool；用户点击立即保存，HUD创建_restore_panel_preferences时恢复。与生产栏/单位菜单偏好共同写入，不丢其它两项。
- tests/production_sidebar_regression.gd 覆盖磁盘保存、clear保持、重新载入偏好恢复；修正先前折叠测试检查工厂卡后未切回单位卡导致的旧断言错误。

验证：新鲜全项目隔离导入被并行unit.gd::_simulate_component重复定义阻断，未修改该无关文件。使用此前能运行的隔离副本 Temp/iron-tide-gunship-smoke-20261120-c/project，同步本次hud.gd、production_inspector.gd和sidebar测试后运行，221 checks/0failed、exit0、stderr空。报告 Temp/inspector-preferences-verified/result.json、godot.log。该结果证明本次UI逻辑在隔离快照通过，不宣称当前整项目干净构建通过。未重启真实玩家游戏，未改玩家存档、未打包提交。
