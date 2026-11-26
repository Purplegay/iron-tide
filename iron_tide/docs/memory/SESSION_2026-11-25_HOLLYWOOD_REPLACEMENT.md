# 好莱坞原战役入口替换

在 data/waves.json 的 yr_hollywood 原记录上更新任务名为《好莱坞梦一场》，副标题为《尤里的复仇 · 盟军第二关》，敌方标识为 yuri，显示名为尤里军团。任务继续使用原编号记录进度。主菜单战役进入 campaign_command 场景，盟军分组选择该任务后出击。

使用玩家启动器选用的 IronTideRuntime.exe，在隔离目录以 tests/hollywood_campaign.tscn 为主场景，实际从战役指挥室选择盟军战役和出击。48 项通过，exit 0，验证战场任务编号、尤里敌方、九类建筑数量、驻堡、目标和胜利结算。日志 %TEMP%/it-hollywood-replacement-command.log。本轮验证为新开局。