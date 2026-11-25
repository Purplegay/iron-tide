# 接人改为护盾撤离

信物进入点地瞄准，显示半径 260 的救援圈。预览和施放共用目标筛选，从己方地面作战单位中按当前生命比例、距圈心距离选取最多四人。确认后单位获得护盾并启动 600 战斗秒冷却，五秒后解除护盾，寻找己方出生基地附近空地并撤离。空地点击保留瞄准，右键取消。有超时空军团兵时携带武器的撤离者可留下两轮残影。旧检查点的登记乘客和集合点由 setup 清理。

修改 keepsake_orders.gd、commander_keepsakes.gd、unit.gd 与 expedition_keepsake_regression.gd。隔离无头远征战场共 243 项通过，包括救援预选、圈内五选四、空点、取消、受击、延迟撤回、残影与冷却恢复。验证使用场景按钮信号和鼠标事件，桌面实际画面与护盾中途冷启动读档待验。日志位于 %TEMP%/CodexIronTideValidation-Rescue-40b547c9-92ce-4fc0-92a2-3ab7bcb0ebe9/result.txt。
