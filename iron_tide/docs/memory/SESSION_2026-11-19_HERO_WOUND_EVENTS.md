# 谭雅与守望者反复救治 · 2026-11-19

用户截图第21关营地同时显示救治谭雅/守望者，表示这两名英雄老是死亡。未读取用户存档，无法确定截图中两人是否实际阵亡或历史误判。

发现：Heroes.update_wounded旧逻辑将所有英雄先标伤，再移除survivors里的英雄；名单缺失本身即被当成阵亡。此前pending collect修复保留待抵达英雄，但缺失即死亡判定仍存在。

本次改动：
- runtime.gd::unit_died 对实际发出死亡事件的我方Unit读取academy_hero，去重写入allied_state.expedition_hero_deaths。沿用现有Rules.active/world.ended/side检查。
- heroes.gd::update_wounded(run,world=null)，有world时从已有负伤名单起步，仅死亡记录新增负伤，再用survivors移除已存活/待入场英雄；无world保留旧调用兼容行为。
- run.gd::settle/retreat都传world。
- 字段位于已有allied_state中；未独立测试完整冷读档或真实死亡信号链。旧负伤状态不追溯清除，旧战斗加载后新字段缺失时不会仅因名单缺失新增负伤。

tests/expedition_hero_wounded_events.gd：5/5通过，隔离用户目录exit0无stderr。使用轻量World夹具验证缺席不标伤、谭雅死亡、既有负伤保持、存活清伤、守望者死亡去重/legacy flag。不是完整实战生存/死亡链回归，不宣称已复现截图问题。
证据 C:/Users/admin/AppData/Local/Temp/IronTideHeroWound-536976ddc96f4864a3f53d510124b571/test.log。
未修改玩家存档/英雄强度，未打包提交推送。用户当前两项既有救治仍保留，不能确定历史真假死亡时不自动抹除。
