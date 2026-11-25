# 远征任务统一人数读条曲线

relics.gd 提供人数曲线和当前手册等级倍率。objectives.gd 将研究、救援、坚守、终章持点破盾接入占点所用的曲线。坚守按指挥所附近守军计数，零守军仍按原速。破盾取已控圈人数的第二高值。field_operations.gd 接入普通支线驻留。field_assignments.gd 接入监听、双台、测点、体检和编制不足时的后备读条。监听允许多人共同录音，双台取人数较少的一台。战斗时钟与波次继续按实际模拟时间计时。按件完成的护送和摧毁目标仍按实际抵达或摧毁数结算。同步修改手册、路线和监听说明。

Godot 4.7.2 隔离用户目录真实场景的 expedition_control_regression 最终 44/44，含四支部队在研究、救援、监听各推进 1.25 秒的断言。field_operations 的 1024 项中 9 项广播展示断言失败，field_missions 的 145 项中 1 项战损文案断言失败。此次逐分支数值验收覆盖占点、研究、救援和监听。日志在 %TEMP%/HudOnlyea0a0c7f2136439b855d93a2a392a1b1/curve-final2.log、new-field_operations.log、new-field_missions.log。
