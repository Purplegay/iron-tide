# 好莱坞首批尤里守军

ALL02UMD.MAP 有 INIT 预置步兵。本次选择当前任务直接需要的守军岗位，hollywood_mission.gd 让回收厂、兵营和碉堡旁按难度生成的 E2 改为 INIT，沿用原有编队数量和巡逻分配。GameData.get_unit 已能读取 data/ra2/death.json 的 crew_units.INIT，单位自身按 ID 加载 SHP 和动作序列。本次范围是关卡部署，未改生产目录或快照格式。

首次回归发现预置碉堡仍在播放建造动画，is_operational 拒绝开局驻军。仅本任务的预置碉堡在布置时结束该动画，继续走 civilian_orders.enter。Godot 4.7.2 在隔离 APPDATA 从大厅进入任务，tests/hollywood_campaign.tscn 胜利 37/37、失败 38/38，均 exit 0。验证了巡逻标记、PsychicJab 数据、实际加载的美术和 FireUp 序列、驻堡状态、快照校验、克林特命中新兵和任务结算。日志在 %TEMP%/it-hollywood-init-fixed.log 和 it-hollywood-init-loss.log。验证范围不含新兵主动开火伤害、跨进程读档、所有难度实玩或发布包。
