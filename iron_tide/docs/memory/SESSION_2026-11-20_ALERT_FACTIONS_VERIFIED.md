# 2026-11-20 两阵营警戒UI实际渲染验证

用户要求验证纠正后的苏联/盟军警戒槽、横灯和左环倒计时。最终使用真实uprising_red_alert_button.gd和uprising_threat_meter.gd、正常Node场景+项目autoload、轻量WorldFixture提供faction/allied_state。Godot4.7.2 OpenGL/NVIDIA真实图形，在CreateDesktop创建的私有未激活桌面运行；从未SwitchDesktop，无玩家游戏输入操作，独立user dir CodexIronTideValidation/RedAlertFinal。源码同步到既有隔离副本，最终两UI脚本SHA256与生产一致。

最终结果：control-result.json 28检查/0失败，render exit0、日志无SCRIPT ERROR/ERROR。两阵营各截图charging/ready/full/half/last；已实际view_image苏联half/ready、盟军half/last。苏联绿铜槽+俄文按钮，盟军蓝灰槽；总攻红色横灯完整；90秒半圈12格、7.5秒1格（180秒24格），圆环熄灭效果可见，槽体未混入其他按钮。

证据 .validation/alert-factions-20261120/：*-control.png、control-result.json、verify_alert.gd、render.log。截图是实际控件渲染放大裁剪，不是图片模拟。最初裁剪漏乘viewport stretch变换只截到地形/局部，已修验证脚本后重跑，勿用早期非control裁剪评价。

完整战场尝试：首次54状态检查通过，但截图坐标不对；第二次完整战场遇到并行修改的Unit._enter_tree调用Battle缺失_place_simulation_lane_deferred报错，退出0和54计数不能当作干净完整场景通过。未修改该无关生产代码，已用独立UI夹具排除干扰。故结论是两阵营控件图形验证通过，非完整战场/全部分辨率验收。最终运行日志覆盖了早期日志，保留此失败说明。未打包提交。当前映射以SESSION_2026-11-20_ALERT_FACTION_FINAL_CORRECTION.md为准，不再读反序CORRECTION2。
