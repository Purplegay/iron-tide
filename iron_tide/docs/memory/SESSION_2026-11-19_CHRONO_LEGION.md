# 军团超时空跨局修正

用户要求每局重新传送、上一局计时推进折半形成减时，普通最多50%、特殊遗物最多80%；军团人数损失按比例回补等待；本局自产兵不进军团。

已完成reinforcement_plan.gd、runtime.gd、run.gd、relics.gd及tests/expedition_reinforcement_regression.gd修改。规则、计算示例、测试证据和旧checkpoint边界详见 ../EXPEDITION_REINFORCEMENTS.md。

隔离真实战场24/24通过，exit0、stderr空。初轮23项通过但存在原有音乐建筑unit_id错误；仅隔离副本修类型保护后24项无错，不修改生产battle.gd。未运行完整跨局磁盘冷读或人工整局。不提交、不打包。

注意：旧checkpoint在场兵没有来源标记，不猜测来源，因此结算不会纳入这些无标记单位；新军团到场后有special.expedition_legion_member标记。已存在旧营地军团下局重新排队。保持原有大量未提交改动。
