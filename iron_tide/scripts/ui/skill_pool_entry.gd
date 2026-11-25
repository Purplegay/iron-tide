extends "res://scripts/ui/production_tooltip.gd"
## Each pool entry owns its hover target and bounded effect tooltip.
const Academy=preload("res://scripts/rules/academy.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")
const Upgrade=preload("res://scripts/ui/progression_upgrade.gd")

func setup(card:Dictionary,title:String) -> void:
	name="PoolCard_"+str(card.id)
	text=title
	add_theme_font_size_override("font_size",14)
	var color:=Scope.rarity_color(card)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_hover_pressed_color"]:
		add_theme_color_override(state,color)
	add_theme_stylebox_override("normal",UiKit.panel_style(Color.TRANSPARENT,Color.TRANSPARENT,3,1,6))
	for state in ["hover","hover_pressed","focus"]:
		add_theme_stylebox_override(state,UiKit.panel_style(Color(1,1,1,0.06),Color.WHITE,3,1,6))
	add_theme_stylebox_override("pressed",UiKit.panel_style(Color(1,1,1,0.1),Color.WHITE,3,1,6))
	var owned:=MetaProgress.skill_unlocked(card.id)
	var rank:=Academy.card_rank(MetaProgress,card.id) if owned else 0
	tooltip_text="%s · %s\n%s\n%s\n%s" % [card.name,"W 主动" if card.type=="active" else "被动", "已获得 · 当前 Lv.%d"%rank if owned else "未获得 · 预览 Lv.0",Scope.description(card),Academy.skill_description(card,rank)]
	if Upgrade.card(card.id):tooltip_text+="\n可升级至 Lv.%d · %d 战略核心" % [rank+1,Academy.card_upgrade_cost(card.id,rank)]
	elif Upgrade.legend_unlock(card.id):tooltip_text+="\n可解锁 · %d 兑换碎片"%Academy.EXCHANGE.legend
	tooltip_text+="\n点击查看各级效果与培养。"
	Upgrade.mark(self,Upgrade.card(card.id) or Upgrade.legend_unlock(card.id))
