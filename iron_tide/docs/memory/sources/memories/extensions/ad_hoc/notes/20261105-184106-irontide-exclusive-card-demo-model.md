# IronTide 单兵种专属抽取卡演示规则

用户明确要求：只有一个适用兵种的抽取技能／被动卡，在技能演示区域中，触发技能的单位必须使用对应兵种模型，不能继续用三角头。以后新增同类卡也遵守；只有单一兵种才算专属，多兵种卡不要误标专属。

实现入口：C:/Users/admin/IronTide/iron_tide/scripts/ui/faction_card_stage.gd，复用 scripts/rules/skill_scope.gd 的 exclusive（allowed_units 长度为 1），按配置自动加载 unit_showcase 私有模型。切卡释放、等级切换复用，模型与时间轴、残影透明度同步。敌方靶子和一般事件符号不属于本次替换要求。

展示模型必须独立世界、关闭战斗与物理，不能靠战斗循环驱动；冻结 Mirage 模型要隐藏未初始化的 Ra3MirageFx 加法合成节点，避免黑底。验证必须无可见窗口，实际渲染需要独立 Windows Desktop。已提供 card_caster_regression 和隔离截图；不把 headless 通过等同于玩家视觉确认。
