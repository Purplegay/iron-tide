# 盟军终关清剿目标标记

用户在控制器摧毁后看不到具体目标，要求参照好莱坞。复查 `hollywood_mission.gd::markers`、`SESSION_2026-11-25_HOLLYWOOD_OBJECTIVES.md` 与终关零售 `Dominator_Gone`/`MISSION:StopYuri`。此前终关只给控制器/可见建造场打点，剩余发电厂和部队没有标记。

`allied_finale.gd` 用既有 `dominator_placed` 加实际控制器存活状态进清剿显示，不加存档字段；旧档即时计算。与当前 `Win_Check` 共用存活/敌方/任务房条件，不修改胜负语义。好莱坞规则：已探索建筑即使离开当前视野仍有红色菱形；终关额外标出当前可见且未搭载的敌军（包括能被侦测到的舰艇，未侦测不显示）；不揭雾，目标被摧毁或转属撤标。用共用战场标记和可点击雷达入口，不冒称原版有同样的辅助标记。

Godot 4.7.2 真菜单隔离无头 41/41、exit0、stderr 空，`.validation/finale-cleanup-marks/test.{out,err}`。夹具置控制器/建筑血量归零和揭示指定格，查战场目标数据及实际小地图标记、隐藏目标和撤标。未跑清剿状态独立进程冷读、图形目检或发行包，未改玩家档。