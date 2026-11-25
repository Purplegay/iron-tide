# 远征特装海豹部队攻防强化

军团卡片通过 Growth.can_upgrade 接受有成员的特装小队。scripts/expedition/run.gd 的 service("training") 在 item_valid 之前额外检查普通许可，造成按钮可用但点击报「当前条件不满足」。移除该提前返回后，交易通过 item_problem 调用与卡片一致的 Growth.upgrade_problem。补员及量产继续按各自规则处理。

在独立 APPDATA 下用 Godot 4.7.2 无头运行 tests/expedition_special_training.tscn。9 项检查通过，退出码 0。用真实服务验证未持有时拒绝且保留免费次数、获得单名特装 III GHOST 后免费升级攻防、重复提交旧价格不会扣费、付费升级以及重新读档后的等级和余额。日志在 %TEMP%/CodexIronTideValidation-special-1747356c-9180-4fe4-bd25-c1776d2cb980/test.log。验证范围为工程内营地交易入口，未操作玩家存档、手点界面或构建发布包。
