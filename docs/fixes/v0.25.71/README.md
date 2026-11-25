# v0.25.71 · 超时空许可装配对象与任务执行者分离

- 超时空爆破许可仅装配于超时空伊文 CIVAN；超时空突击许可仅装配于超时空突击队 CCOMAND。普通 IVAN／GHOST 不再提供这两张卡的装配入口。
- 扩展开局冻结对应超时空兵种的被动装配，即可由己方任意普通疯狂伊文实际引爆／海豹部队击杀累计任务。普通单位无需装卡，也不用先生产超时空单位或建实验室。
- 阈值不变：海豹击杀 10／8／5／3 次，伊文引爆 5／4／3／1 次。仅装弹、拆弹、友军／中立事件不算；炸弹保留归属，施放者死亡后实际引爆仍计数。任务解锁后的兵营／实验室前置及间谍窃取科技替代路线不变。
- 成长表改读 objective_by_rank 显示“次”，修复原来的 0%。生产阻挡提示写明在对应超时空单位改造栏装卡。演示左侧为装配兵种，时间轴模型按 objective_unit 显示实际执行任务的普通兵种。

## 旧档

局外旧装配：普通单位装着许可、目标超时空槽位为空时自动迁移；目标已有其他被动时保留目标被动，卸下旧位置的许可但不删除拥有权或等级，可手动重装。迁移不收费，不改其他主动卡，重复读取不重复迁移。

已有战斗继续读取冻结装配而非当前局外档：version 1 的旧来源装配仍能累计，已有任务计数、完成标记和炸弹归属保留；新开局 version 2 只认可超时空兵种槽位。无该功能标记的早期对局仍沿用原始间谍解锁规则。

## 验证

- field_commission_regression：272 项通过，覆盖四档真实击杀／引爆、无需普通单位装卡、未装超时空卡不计数、生产交付、无实验室累计、施放者死亡、磁盘存读、迁移冲突／幂等、旧战斗兼容和成长次数。
- card_gallery_regression：1035 项通过。
- card_caster_regression：67 项通过，许可卡模型按 objective_unit 同步。

共 1374 项断言通过，无脚本错误。逻辑检查 headless／CREATE_NO_WINDOW；截图在不切换前台的独立 Windows Desktop 完成，已查看 CIVAN 装配入口与 5／4／3／1 次成长表。未操作玩家存档，未弹出测试窗口。UI 测试退出存在 Texture／Font／CanvasItem／ObjectDB 释放告警，未声称零告警。

证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/commission-carriers-final/、commission-carriers-gallery/、commission-carriers-model/、commission-carriers-visual/。未提交、推送或打包。
