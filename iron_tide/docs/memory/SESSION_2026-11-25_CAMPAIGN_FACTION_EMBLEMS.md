# 战役阵营徽章

从本机红警2本体 ra2.mix 中同一子归档读取 FSBKGDLG.SHP、FSALG.SHP、FSSLG.SHP、FSBCLG.SHP 和 FSSCRN.PAL。三组八帧动画按静态底图匹配位置绘制。上方盟军、下方苏军，中间训练营钢盔作为 Iron Tide 原创战役入口。播放周期采用项目设置 0.8 秒。苏军可见且标注筹备中。

Godot 窗口从主菜单进入阵营选择，两枚徽章均推进到后续帧，菜单回归八项通过。实机截图 %TEMP%/it-factions-live.png，日志 %TEMP%/it-emblems-test.log。
战役阵营悬停音效（2026-11-25）。campaign_command.gd 将三个徽标及三个对应文字按钮的 mouse_entered 接到 Ra2Sfx。menu_audio.json 登记 CampaignFactionHover，复用 umenucl1.wav，音量 45%。Godot 4.7.2 无头加载真实阵营选择场景，以视口鼠标事件依次移入六个控件并在内部移动，逐项核对命中控件与成功播放计数增量为一，6/6 通过。验证覆盖播放触发，实际扬声器响度待试听。

阵营确认语音。对照 `../refs/yr-voices/source/RA2 YR Voicelines/sound.ini`，盟军 AlliedCampaignSelect 使用 itanatc，苏军 SovietCampaignSelect 使用 vgrsatc，训练营 BootCampSelect 使用 igisea，音量均为 90%。训练营钢盔沿用为原创战役入口，点击徽章和名称共用 choose_faction 播放。Godot 4.7.2 隔离 APPDATA 从主菜单进入，tests/campaign_menu_routes.tscn 12 项通过，三次点击名称各增加一次成功播放计数，退出 0，stderr 空。徽章共用回调，本轮未单独点击徽章或试听扬声器。日志 %TEMP%/campaign-select-voice.out。
