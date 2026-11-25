# 肉鸽未出战兵种制造权限（2026-11-19）

用户确认需求：兵种只要已经解锁并拥有本轮许可，即使未加入本关出战编制，也必须允许正常手动制造；未解锁、未获得许可或科技不足仍禁止。

已改：scripts/expedition/rules.gd::block_reason 移除 active_roster 限制。生产资格现在继续检查远征是否启用、兵种是否在本轮catalog、是否在licenses；科技/生产前置继续由既有 GameData 生产系统负责。本改动只让 active_roster 不再阻止手动生产；active_roster仍控制开局携带和自动增援/跨关部队。

回归：tests/expedition_production_unlock_regression.gd/.tscn 隔离运行4/4通过，exit=0，stderr空：已许可未出战MTNK可生产；目录内无许可HTNK仍阻止；目录外APOC仍阻止；HTNK获得许可后不再被active_roster阻止。测试临时根目录由本次工具输出生成，未操作正式存档。未打包提交推送。
