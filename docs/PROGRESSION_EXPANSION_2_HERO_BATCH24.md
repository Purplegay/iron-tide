# 英雄第二十四批：谭雅潜泳的累积护盾与获取／契约复核

2026-11-18，v0.29.65。按第五稿3.1～3.6核对获取、契约和累积天赋，发现潜泳演示与已经实现的低级能力累积规则不一致。本批修正演示并增加真实受伤组合验证；不改变战斗数值或结算规则。

旧演示在生命100→80后只标潜泳护盾15。实际上，单次生命损失达到15%且存活时，0级“脱离杀线”另给10%护盾，因此这一例应为生命80、潜泳盾15＋脱离杀线盾10＝25，均属于谭雅。两种来源不应混成一份共同续时的盾。

新增 `scripts/ui/tanya_swim_demo.gd`，30秒分三段：受伤、主动开火、上岸。受伤段先扣20生命、再获得两份盾，三秒后脱离杀线盾到期，四秒后潜泳盾到期；开火／上岸段不受伤，只给潜泳15盾。前两段再次潜泳、再开火，展示间隔内不补盾／不续时；15秒和30秒触发间隔分别显示。生命、护盾总额及来源都标在谭雅的信息区域。原生命80／护盾15的错误片段已移除；天赋预览时长同步30秒。已有夜枭／猎蛛美术未修改。

本轮缓存 `.validation/tanya-swim-demo-20261118/summary.json`：**1427项通过，0失败、0 SCRIPT ERROR／ERROR、0截图**。

| 核对范围 | 当前源码／实际入口 | 本轮证据及边界 |
| --- | --- | --- |
| 潜泳与0级受伤盾累积 | `expansion_2_commandos.injured`、`tanya_talents.injured`、真实 `receive_hit` | `tanya_talents_regression` 125项；新增真实入水隐形、20点伤害、两份盾、独立冷却、再次破隐不刷新、分别到期且不回血 |
| 谭雅全部0～5级预览及潜泳三个片段 | `hero_talent_demo`、`tanya_talent_demo`、`tanya_swim_demo` | GPU 166项，包含逐节点语义与实际离屏绘制；不代表观感认可 |
| 谭雅／鲍里斯累计生产解锁及下局身份 | `academy`、`expansion_2_commandos`、生产完成入口 | `commando_hero_regression` 106项；生产、满军衔、次数去重、旧英雄能力排除、装配和对局存档 |
| 首架飞机赠游隼及原产品／机场位 | `hero_reinforcements`、`peregrine`、真实机场队列 | `peregrine_base_regression` 104项；出场、悬停补弹、同局不再赠、普通ORCA及保存边界 |
| 第三辆TTNK赠雷铸 | `hero_reinforcements`、`leizhu_reinforcements`、真实工厂队列 | `leizhu_base_regression` 111项；产品保留、生产资格、保存、基础养成及UI |
| 谭雅契约及双卡四档 | `commando_contracts`、`tanya_breach`、原生双枪与C4计时结算 | `tanya_contract_regression` 182项；真实命中／归属与任务边界，部分累计／胜利条件使用预置进度 |
| 鲍里斯契约及双卡四档 | `commando_contracts`、`boris_fire_control`、原生米格 | `boris_contract_regression` 171项；呼叫／章数／伤害半径／单装／保存及任务边界，累计结算夹具不等于完整自然两轮任务 |
| 游隼契约及双卡四档 | `peregrine_contracts`、`peregrine_cards`、真实普通攻击和补满 | `peregrine_contract_regression` 199项；无奖励卡击杀20目标及有效补满、胜利授双卡和存档／非法目标／普通机隔离 |
| 雷铸契约及双卡四档 | `leizhu_contracts`、`leizhu_cards`、真实主电击与受伤 | `leizhu_cards_regression` 206项；无奖励卡25次主电击击杀、实际生命损失、胜利双卡、共享池0.35%与500碎片及购买回滚 |
| 四份契约统一结算落盘／失败重试 | `battle_rewards`、真实正常对局结束入口 | `hero_settlement_regression` 57项；使用已完成战果夹具，验证原子保存、失败回滚、重试和去重，不替代战斗归属专项 |

共享契约池仍从未获得契约集合等概率挑选，合计0.35%，不把四份新契约各算0.35%；永久养成结算检查与预览显示检查分开。上述是本轮实际覆盖范围，不据此认定所有英雄节点、全部演示或自然玩法已经完成最终验收。

剩余全量审计继续按第五稿逐项对照：其余英雄0～5级功能与预览的累积关系、全部持续物件／跨阶段保存和所属方出局清理、全部UI描述与实际入口、完整外观及用户表现确认。游隼完整独立32向机身仍未接入；保持原有素材阻塞记录，不用重复方向或融合图替代。性能目标沿用原状态，本批没有进行六方对局性能验收。

验证环境Godot4.7.2，当前源码／资源链接的隔离工程、每次独立APPDATA／LOCALAPPDATA；实战专项headless，GPU为GL Compatibility 1280×720未激活私有桌面，输入桌面前后Default。服务／数据库／网络none，结束进程审计无残留。无截图、用户可见窗口、打包、提交或推送。表现 `pending_user_visual_confirmation`，总目标active。
