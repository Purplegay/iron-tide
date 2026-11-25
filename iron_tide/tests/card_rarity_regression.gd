extends "res://tests/electric_cards_regression.gd"
const Scope=preload("res://scripts/rules/skill_scope.gd")
const Icon=preload("res://scripts/ui/progression_icon.gd")

func exercise(mode:String) -> void:
	await super.exercise(mode)
	if mode==MatchRules.RA2:return
	for card in MetaProgress.skill_draw_candidates():
		check(Scope.exclusive(card)==(card.get("allowed_units",[]).size()==1),"single unit exclusive "+card.id)
		check(Scope.rarity_color(card)=={"legend":Color("#ffd166"),"epic":Color("#c58aff"),"rare":Color("#70b7ff"),"common":Color.WHITE}[card.rarity],"rarity color "+card.id)
		check(Icon.texture(card.id)!=null,"rarity icon renders "+card.id)
	check(Scope.group(GameData.get_skill("ap_shock_pulse"))=="多单位" and Scope.group(GameData.get_skill("ps_phase"))=="多单位","electrical and phase groups are not exclusive")
	check(Scope.group(GameData.get_skill("ap_tesla_chain"))=="专属" and Scope.group(GameData.get_skill("ap_smoke"))=="通用","single and common groups remain distinct")
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta._unit_sel="SHK";meta._rebuild_unit_detail()
	var labels:=all_labels(meta.unit_detail)
	check(labels.any(func(label):return label.text.contains("专属 W · 连锁放电") and label.get_theme_color("font_color")==Scope.RARITY_COLORS.legend),"chain title legendary yellow and exclusive")
	check(labels.any(func(label):return label.text.contains("多单位 W · 震荡脉冲") and label.get_theme_color("font_color")==Scope.RARITY_COLORS.epic),"pulse title epic purple and multi unit")
	for rank in 4:
		var card:=GameData.get_skill(Cards.CHAIN)
		var text:=MetaProgress.Academy.skill_description(card,rank)
		check(text.contains("主伤害增加 %d%%" % [0,20,30,35][rank]) and text.contains("主伤害的 %d%%" % [10,30,50,100][rank]),"description has two independent curves "+str(rank))
		check(meta._card_growth_step(card,rank).contains("主伤害 +%d%%" % [0,20,30,35][rank]),"growth table includes primary curve "+str(rank))
	meta._open_exclusive_card(Cards.PULSE)
	check(meta.training_group=="多单位","multi unit acquisition opens correct training group")
	meta.free()

func all_labels(node:Node) -> Array:
	var result:Array=[]
	if node is Label:result.append(node)
	for child in node.get_children():result.append_array(all_labels(child))
	return result
