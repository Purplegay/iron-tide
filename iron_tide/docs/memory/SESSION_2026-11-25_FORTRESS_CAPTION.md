# 洛杉矶战斗要塞登场介绍

盟军战车工厂触发机场战斗要塞援军。此前 cevau71.wav 直接播放，屏幕只报到达。用本地 whisper-cli 转写 8.94 秒英语原声，内容是运兵、碾压挡路装甲车辆和乘员通过射击孔开火。hollywood_mission.gd 现在用已有 transmit 入口播放同一原声并送入战场通讯框。字幕按该框现有规则排队并按字数停留。

隔离 APPDATA，以 Godot 4.7.2 无头运行 tests/hollywood_campaign.tscn -- --skip-report，通过援军触发、三名重装大兵与两名美国大兵登车、介绍进入可见通讯框、推进其显示计时九秒仍完全可见、战役胜利结算。进程返回 0。日志 %TEMP%/it-fortress-caption-console.log。未验证窗口实拍、繁忙队列的声画同步或发布包。