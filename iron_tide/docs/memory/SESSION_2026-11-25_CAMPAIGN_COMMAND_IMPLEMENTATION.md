# 战役指挥室与通关奖励

主菜单分别进入 campaign_command.tscn 和 lobby.tscn。战役可选盟军或原创任务，苏军显示筹备中。每次选关默认原版配置，右侧唯一的养成开关设置战斗规则，并随快照保存。灰烬要塞沿用无尽波数结算。

首胜金额按战雷点、军需、钻石依次为好莱坞 200/1200/30，断轨平原 100/600/10，结晶裂谷 160/1000/20，均可在 data/waves.json 调整。重打取前两种资源各自的 5% 向下取整，钻石为零。军需使用 credits，战雷点使用独立的钱包字段 war_points。campaign_victories 按关卡记录至 stats，match_id 收据与钱包在已有结算事务中一同保存。选关预览和到账复用 campaign_payout.gd。

独立 APPDATA 的 Godot 4.7.2 无窗口关卡测试跨三个进程验证首胜、带养成重打、失败和重复提交。钱包累计 200/1200/30 → 210/1260/30 → 210/1260/30。胜利路径各 53 项、失败最终 56 项通过。campaign_menu_routes.tscn 从主菜单触发按钮验证战役、原创换关与遭遇战，5 项通过。日志在 %TEMP%/it-campaign-wallet-first.log、it-campaign-wallet-repeat.log、it-campaign-wallet-loss-final.log 和 it-campaign-menu-routes.log。测试覆盖快照里的规则选择。实际窗口布局与导出包尚待验收。