# 苏联 HUD 不再使用盟军蓝色横幅

用户反馈苏联指挥甲板仍用 RA2 盟军顶条。hud.gd 原先无条件引用 SIDEC01 导出的 assets/ra2/ui/top-0.png；BattleScreen 先 hud.setup 再 battle.setup，故 HUD 初建时 roster_faction 尚为默认盟军。

修复：hud.gd 用延迟 _apply_faction_headers 在 Battle.setup 后选择标题，苏联指挥甲板/小地图标题使用现有 Ra3Skin.banner(RED)，盟军保留 RA2 顶条；动态皮肤使用阵营色。ra3_skin.gd::upgrade_control 新增默认关闭的 faction_blue 参数，只在苏联 HUD 启用，将原有蓝色按钮/面板装饰映射到红色，保留其它功能色。未导入苏联原版 RA2 素材，当前是程序化 RA3 红色金属主题，不声称为苏联原版贴图。未改生产规则。

tests/hud_faction_skin_regression.gd/.tscn 实际美国/苏俄战场 10/10 通过，exit0、最终日志无脚本错误。已查看苏俄截图，标题/小地图红色条可见，无盟军 TOP。证据 C:/Users/admin/AppData/Local/Temp/IronTideFactionSkin-1b6b9c307b0840da9a9ca1563f5ba939/report。

限制：生产 uprising_threat_meter.gd 并行修改中有 point := 类型推断错误，首次验证出现脚本错误，该次结果不作最终通过；最终隔离副本只为 point 加 Vector2 类型，生产未动该文件，最终10/10基于该隔离修正。未测远征完整流程/冷读档/多分辨率，未打包提交。工作区有大量并行修改，禁止覆盖。
