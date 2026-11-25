# v0.29.3 — 敌方电脑淘汰语音

用户确认范围为整个敌方电脑阵营被淘汰。`house_elimination.gd` 现在在新淘汰事件上触发已有 `EVA_PlayerDefeated`，由玩家自己的盟军／苏军指挥官播报，复用 `ceva026.wav` / `csof026.wav` 与现有 EVA 排队服务。

同批多家敌人淘汰合并一次语音，文字仍逐家提示。盟友电脑淘汰不触发敌方淘汰语音；重复检查及读取已有淘汰记录不重播，新淘汰与最后一家敌人仍触发。普通单位死亡、胜负判定及存档结构未改变。

Godot 4.7.2，headless，独立 `CodexIronTideValidation/house-defeat-voice-20261117` 用户目录：

- `house_defeat_notice_regression`：61 项通过，包含两阵营真实音频解码、播放器接收、首次／重复／读档后／同时／盟友／最后一家淘汰。
- `house_elimination_regression`：25 项通过。
- `audio_lifecycle_regression`：78 项通过。
- 引擎日志无 SCRIPT ERROR / ERROR，修改源码与隔离测试副本一致。

本机证据：`.validation/house-defeat-voice-20261117/<suite>/result.json`。可通过 `iron_tide/tests/run-navigation-building.ps1 -Suite house_defeat_notice_regression` 重跑隔离专项。

这里只验证资源与触发链路，未进行使用者设备上的听觉验收。实际音量、语音内容与提示时机待用户重开游戏确认；未打包、提交或推送。
