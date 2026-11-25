# 2026-11-20 支线现场倒计时
用户截图青色情报圈只有任务名，没有现场倒计时。已改field_operations.gd::countdown_text/_draw，所有未完成且未失败支线在现场显示居中名称、青色180x12进度条、白色“剩余 N 秒 · M%”，屏幕坐标固定尺寸，进度clamp0..20。完成/失败沿用隐藏，无奖励或计时规则改动。

tests/expedition_field_operations_regression补19秒→剩余1秒95%检查与非headless截图。独立副本当前生产只同步同文件和测试，headless24/0及真实GUI24/0均无错；reports/field-countdown.log、field-countdown-visual.log。view_image已检查field-countdown.png，现场任务名/95%条/剩余1秒清晰。未打包提交，不改玩家档。
