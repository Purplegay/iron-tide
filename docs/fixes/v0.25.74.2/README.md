# v0.25.74.2 · 抽取技能不再免费占用固有 Q

根因：skills.json 的早期 defaults.primary 将灰熊烟幕弹、部分单位引擎超载、聚焦射击等卡牌当成固有主动。UnitSkillLayout.ensure 不检查拥有权就补进技能数组，导致不装配也能在 Q 施放。

- primary_id 拒绝 gacha 卡牌作为默认固有 Q；RA3 原生技能、工程师、间谍、超时空步兵、重装大兵等明确原生 Q 和 E 保留。
- 原有默认 W 排序先排除遗留 Q 条目，避免取消 Q 后自动把它塞入 W。已获得烟幕弹等卡后，可以手动装配至 W，接受普通兼容性与拥有权检查。
- 局外首次迁移清理普通单位和英雄装配中的旧 Q 条目；保留其余 W、被动、拥有权及培养等级。迁移标记防止以后读档删掉玩家明确装配的新 W。
- 新对局冻结规则标记。旧战斗解析装配时排除遗留 Q，恢复快照时仅移除多余的 Ability，保留实际 W 对象和冷却；读档后生产的新单位也不再注入旧 Q。
- 改造页、战场技能栏、Q／W 热键和自动 W 共用同一个技能布局规则。

## 验证

- native_q_card_regression：109 项通过；遍历当前单位的 Q、无卡出生、原生 Q／E 保留、获得并装配烟幕弹到 W、新旧战斗存读档和冷却、旧档迁移幂等、改造页 Q 空位。
- hero_loadout_regression：75 项通过。
- tank_shield_regression：135 项通过。
- auto_w_regression：84 项通过；将过时的“灰熊烟幕弹是固有 Q”断言更新为明确装配后的 W。

共 403 项通过，全部 headless / CREATE_NO_WINDOW，使用隔离存档，没有弹出窗口或修改玩家存档。未做图形验收，未提交、推送或打包。英雄写失败回滚测试含主动注入告警，UI 测试退出存在已有资源释放告警。

历史 skill_hotkey_regression 尚含旧卡池／旧固有 Q 假设，本轮未以其作为验收；当前布局和旧存档修正由新增回归及自动 W 回归覆盖。

证据：C:/Users/admin/Temp/irontide-tank-heroes-20261105-133253/native-q-cards/、native-q-hero/、native-q-shield/、native-q-autow-final/。
