# v0.25.76.1 · 灰熊移动重绘减负

保留位置、寻路、碰撞和战斗每帧更新；满血且无特殊战斗状态的灰熊，姿态未变时装饰重绘交错 30 Hz。车体/炮塔换方向立即刷新，开火、受击、受损和英雄单位保持原刷新。青瓷结晶参数仅变化或更换材质时上传，保留 8 秒积攒、4 秒消退。

无窗口隔离回归：grizzly_visual 21、tank_finish 1449、reverse_pivot 42 项通过，合计 1512；原存档未修改。

最新存档副本、独立不可见 Windows desktop（不调用 SwitchDesktop），原选中组 35 单位含 12 灰熊，固定移动目的地、关闭 AI 决策。四轮移动中位 before 23.051/19.001 ms、after 23.038/20.801 ms；P95 before 32.188/28.579 ms、after 31.575/33.444 ms。没有稳定整帧改善，不能宣称卡顿完全消除。GPU 同时还有玩家游戏进程；用户要求本轮收尾。

旧 unit_showcase 全套在商店夹具访问空 hull 后超时，不计通过。表现状态 pending_user_visual_confirmation。

证据：C:/Users/admin/Temp/iron-grizzly-tests-20261105-b；C:/Users/admin/Temp/iron-grizzly-pair-20261105-c。
