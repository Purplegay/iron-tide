# 摄影棚费用、训练倒计时与动画

三位好莱坞演员的生产卡原先用训练限制提示替换了费用和时间。HUD 现在保留实际生产价格和预计用时，当前订单显示剩余秒数，排队订单显示等待训练。摄影棚使用自身原画生成 12 帧落成图集和 12 帧胶片轮、门灯循环动画，训练时提高播放速度。资源生成工具为 tools/studio_animation.ps1。

使用隔离 APPDATA 在 Godot 4.7.2 图形窗口运行 tests/hollywood_heroes.tscn，共 133 项通过。实际放置摄影棚，读取三张演员卡，推进生产并验证资金减少、剩余时间变化、胶片轮换帧和出兵。验证范围为项目运行版，日志在 %TEMP%/CodexIronTideValidationStudioCard/out2。
