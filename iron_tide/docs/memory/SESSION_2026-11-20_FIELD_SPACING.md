# 2026-11-20 支线任务重叠到基地修复

用户截图13关救人/情报均13秒且标记重叠。根因field_operations.setup用基地中心home作nearest_reachable起点，中心常被基地建筑占据；nearest_reachable失败返回from，被误认为有效点，两个任务落回基地。只有is_finite检查无效。

生产只改field_operations.gd：find_site从主线state.origin可达地面起点短距snap(4格)，拒绝snap离候选>180；9圈24方向散开搜索。valid_site要求同连通区，远离player_start650、所有主线points560、支线互距560、建筑220+配置radius。不合格新目标不生成，拒绝回退基地。setup对旧checkpoint未完成未失败点repair_overlapping_sites，保留原进度，关联NPC一起挪并reset插值，已完成/失败目标不动。定位支线focus_index轮换未完成点，不再永远第一个。

tests/expedition_multi_front_regression补4检查：真实图两点相距>=560、有效性、人工重叠后修复且13秒保留、home回退被拒绝。独立副本完整生产源码同步：36/0日志reports/field-spacing.log干净；field23/0日志field-spacing-regression.log干净，共59。首轮新代码缩进错误已修；第二轮因same_zone以建筑中心为起点导致无支线，修为任务origin后36/0。不引用前失败结果。

证据C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120/reports；本轮未生成截图/不宣称人工画面确认，未写玩家档、未打包提交。已有运行游戏须重载战场/检查点才运行setup位置迁移，不在实时tick强制移动。极端地图无合法点会少生成支线，不挤到基地。全地图覆盖未测。
