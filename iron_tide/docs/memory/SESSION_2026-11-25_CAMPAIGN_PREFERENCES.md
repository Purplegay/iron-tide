# 战役出击选项记忆

战役指挥室通过 DisplayPreferences 在选择时保存养成配置和难度，使用 display_settings.cfg 的 campaign 分组。不同关卡共用选择，首次进入默认原版配置和普通难度。隐藏难度选择的原创任务按普通难度出击。

Godot 4.7.2 在同一隔离用户目录运行两次 tests/campaign_preference.tscn。首个进程从苏军页面选择带入养成和困难，直接退出。第二个进程进入盟军页面，验证配置与难度控件均已恢复。两个进程均输出 CAMPAIGN_PREF_PASS。测试覆盖菜单持久化与冷启动恢复。
