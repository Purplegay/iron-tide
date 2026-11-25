# 远征基础气垫运输船

旧部署只在 island_cross 发放运输船与护航舰。第 5 关玩家检查点的地图是 yr_tsunami。runtime.gd 现按阵营在基地附近可达、无占用的陆地部署 LCRF 或 SAPC，每关配给一艘。原 island_cross 继续提供护航舰。补发标记写入 allied_state，旧检查点已有同阵营运输船时直接记录已发。screen.gd 在筹备页说明基础配给。

在隔离 APPDATA 中用玩家局外档与远征检查点副本启动真实战斗场景，第 5 关成功恢复。苏方 SAPC 数量 1，两栖属性为真，载运容量 12，现有单位可登船，到敌方基地附近可用陆地的两栖寻路返回 3 个路径点。再次执行补发检查仍为 1 艘。验证覆盖恢复、载运资格、路径查询和重复调用，未实跑整场通关。证据 %TEMP%/CodexIronTideValidationFerry57404/log.txt。