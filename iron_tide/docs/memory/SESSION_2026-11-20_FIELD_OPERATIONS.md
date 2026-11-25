# 2026-11-20 多敌人、战场支线、联络员与目标清晰度

用户明确要求适当加2/3家敌人但凶残3不要、优化排版、救援加人设、绑定后续关卡独立友军、实验室意义明确、修目标从2开始、多战场支线。已实施本轮，不打包不提交，不覆盖其他并行修改。

实现：新增scripts/expedition/field_operations.gd，林岚/沃尔科夫/苏砚3联系人（bio/promise/country），每场最多2青色占点支线：救人、50补给军需或35补给+20秒敌基地视野情报。救人真实中立CIV1/ENGINEER NPC，死亡支线failed，成功静默撤离，不发军团死亡。20秒驻留、敌人争夺暂停，NPC/临时/空军不占点；数据allied_state.expedition_field_ops随Snapshot保存。胜利写field_contacts和补给，失败/撤退不兑付。后续支援stage=max(6,current+2)，遇5倍数顺延，>25不许诺。

campaign.routes：6～25非首领第二路线2敌，16起3敌；常规单敌保留。已约定友军可使两条路线都多方；依NativeMap出生位筛，保留地图历史限制，必要降级。enemies同队2，player/友军队1，真实houses配置，不是假波。每额外敌人+60补给。26～30严格1敌无supporters。run.prepare_battle houses传入BattleRequest原生多家AI；友军独立基地/资金/生产/AI，不进军团。

objectives：单点“任务据点2”改“前线据点”；研究/救援编号1/2不再1/3。实验室各45秒可先后占、保留，完成每座+40胜利补给，labs在Snapshot中；旧progress迁移分配。多敌人用BattleRequest.friendly判定争夺；目标查找接受敌对ai2等。主线救援加陈禾医生/严川上士名字和单组秒数、每组原3兵。field markers接objectives.minimap_markers；runtime先支线tick再主任务tick（终局同秒先兑支线）；任务面板有定位支线与人物背景承诺。

screen：路线地图300x150，两列阈值420，任务名/敌我家数/收益/故事分层去重，保留Boss预告。增援默认折叠只显示首批到齐。记录加人物和约定，insights战后列支线/多线奖励、实验室座数及联系人。

测试最终干净：field_operations_regression21/0（实际占点、实验室先后45/44、完整磁盘snapshot读档+支线不重复）；multi_front28/0（1/2/3路线、26～30保持、真实远征launch2敌+1盟友，3电脑控制器+独立HQ、新主线progress0、NPC存在/死亡取消、胜利奖励联系人入存档重复settle拒绝）；insights51/0；reinforcement23/0；elite_persistence23/0。累计146（最后两组23于本轮后段NPC前已过，功能未触该路径）。日志 C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120/reports/*-field-final.log。

GUI tests/expedition_insights_visual.tscn已跑，六张1280/960截图，view_image实看960早版与1280最终tab0，敌军1/3、额外120、地图/说明层级可见，yellow discount保留。最后field-visual-final.log无错。未人工自然整局平衡。

旧expedition_regression有特定userdir CodexIronTideValidation门槛，本副本不匹配，只有启动不能计通过；house_match初尝被外层超时终止也不能计通过。新专用真实multi-front链已测。

并行阻塞最小修复：uprising_threat_meter.gd点坐标明确Vector2类型；unit.gd并行性能代码重复声明_simulate_component，移除_enter_tree后较早3行重复，保留主循环较完整driver实现。最终五组干净通过后才结论。objectives还存在其他窗口并行escort_ambush逻辑，本轮逐段编辑保留，勿整文件还原。

重要剩余：支持地图耗尽或海军只双人地图时联系人承诺可能无法落地（文档已说明，后续应保证预约的多人地图或补偿）；地图基地自然经济与多方实际难度未平衡验收。AI英雄头像三个模型403/400仍阻塞，本轮未再请求，不冒充SVG。新增玩法文档docs/EXPEDITION_FIELD_OPERATIONS.md。
