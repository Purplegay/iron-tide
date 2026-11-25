# 远征信物独立冷却

13 件信物开战就绪，成功发动后各自冷却 600 战斗秒。按钮显示剩余战斗时间，战场检查点保存进度。旧 used 标记映射到完整冷却，旧曝光计时保留剩余值并以 600 为上限，旧齐射窗口按已过去的时间补齐冷却。缺口窗口允许追加齐射，乘客成功接回后清登记，木折尺和炮闩清理上一轮命中标记。说明更新至 commander_keepsakes.gd。

实际改动位于 scripts/expedition/keepsake_orders.gd、commander_keepsakes.gd、tests/expedition_keepsake_regression.gd。回归的赠礼准备兼容本场已经发放的信物，仍检查永久存盘和重复领取。隔离无头战场回归 239/239，通过 13 件存档恢复与逐件最后半秒、到点重新就绪检查。通过模拟推进验证时间边界。旧玩家存档迁移及完整桌面操作待实机确认。源码交付。日志 %TEMP%/CodexIronTideValidation-Rearm-c41120db-2898-4d3e-a2ec-7c055e6ae207/result.txt。