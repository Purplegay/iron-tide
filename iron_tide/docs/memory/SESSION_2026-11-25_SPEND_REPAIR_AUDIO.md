# 战场扣款和维修播报

`menu_audio.json` 按原版 sound.ini 将 CreditDown 映射到 ucreddn.wav，音量 30%。`battle.gd` 的 spend_funds 和 try_spend 在玩家实际付款时走同一音效入口，每个战场按现实时间至少间隔 160 毫秒。自动维修轮询发现新开工的己方建筑时，整批请求一次 EVA_Repairing，自动播报至少间隔 3 秒。单栋与批量手动维修沿用原有阵营播报。

Godot 4.7.2 使用独立 APPDATA 从 tests/spend_repair_audio.tscn 启动扩展遭遇战，输出 SPEND_REPAIR_AUDIO_PASS，stderr 为空。检查一次性扣款、连续分次支付、静默支付失败、零元、敌方扣款，以及受损总部自动开工与持续维修时的播放器计数。验证范围为无头场景播放入口，未人工试听混音或验证导出包。

## 后续调整：战场扣款静音

按玩家要求移除统一扣款入口的 CreditDown 播放和节流计时。更新原场景回归，在独立 APPDATA 下以 Godot 4.7.2 无头运行，通过 SPEND_REPAIR_AUDIO_PASS。三次付款共扣 12，音效播放次数保持原值，自动维修开工播报一次。验证覆盖场景播放入口，未人工试听导出包。
