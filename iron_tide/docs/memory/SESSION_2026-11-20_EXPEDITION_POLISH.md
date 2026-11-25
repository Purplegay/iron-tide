# 2026-11-20 剩余肉鸽优化继续完成

用户明确“剩下优化接着做”，延续全部六项优化授权。AI头像因三个模型403/400仍阻塞，本轮没重复请求。谭雅鲍里斯及其他英雄继续原版fallback，未生成AI资产。

本轮生产修改：
- elite_tactics.gd记录实际tactic id；加生命同步Unit._base_max_hp，修升军衔/刷新veterancy重置精英HP；新增ownership_changed，离开enemy移除HP/速度倍率、保留血量比例，再归enemy只恢复一次。
- allied_abilities.gd统一change_side入口与运输乘员调用ownership_changed，沿用已有归属变更语义。
- insights.gd装备stat类奖励显示本装备攻击/防御/生命/速度选择前后百分比，速度说明上限；去掉面向玩家的“先收集数据再调平衡”开发说明。

测试新增expedition_elite_persistence_regression.gd/.tscn，真实战场23/23通过：升军衔HP、健康比例、俘获/再归敌单位与防御建筑、速度重算、完整Snapshot捕获→磁盘get_var→restore及防重复、真实HUD分组左击只选英雄/右击移除英雄保留同型普通兵、真实任务wave验证装甲额外1HTNK和突击额外2E2及倍率。

insights_regression补装备前后数值和速度上限后51/51通过（旧49 +2）。注意其他窗口并行调整过英雄训练预览规则，本轮保留当前生产值，没有还原旧高训练延迟断言。

广测allied_abilities_regression首轮240/0但SCRIPT ERROR多条，根因继承tests/logistics_regression.gd::remove_actor建筑只从battle.units擦除，未从battle.buildings移除，留下已释放引用。已仅修测试清理：Building时同时buildings.erase。重跑最终240/0且无错误。不能引用首轮为干净结果。

新增tests/expedition_insights_visual.gd/.tscn，独立副本真实GUI生成1280x720、960x640三页共6截图，reports/camp-{size}-tab{0,1,2}.png；view_image人工查看960商店、1280军团/路线：黄色折扣角标不遮标题且缺钱仍黄；筛选布局正常；精英词缀预告可读。初轮副本缺icon.ico产生图标错误，已复制生产icon.ico/icon.svg后二轮visual.log干净。不是人工完整30关自然游玩。

证据仍在 C:/Users/admin/AppData/Local/Temp/IronTideExpedition-20261120/reports/ ：expedition_insights_regression-final.log 51/0；expedition_elite_persistence_regression-final.log 23/0；allied_abilities_regression-final.log 240/0；visual.log。最终314项干净通过。独立user目录，不改玩家存档。副本仅同步scripts/tests，资源与缓存junction参见VERIFIED交接。

未提交未打包。余下限制：没有自然游玩数据可据以调经济/章节数值；AI头像未完成。当前三种精英词缀固定公开参数，不宣称自然平衡已验收。源码已有大量其他窗口并行修改，勿覆盖。
