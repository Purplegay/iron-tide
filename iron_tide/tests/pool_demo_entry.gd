extends Node
const Demo=preload("res://scripts/ui/pool_research_demo.gd")
func _ready() -> void:
	var meta=preload("res://scripts/screens/meta_screen.gd").new()
	add_child(meta)
	var before:=MetaProgress.currency.duplicate(true)
	for pair in [["credits",151000,meta.credits_label],["cores",3250,meta.cores_label],["diamonds",5950,meta.diamonds_label]]:
		MetaProgress.currency[pair[0]]=pair[1]
		meta._refresh()
		var label:Label=pair[2]
		var icon:TextureRect=label.get_parent().get_node("ResourceIcon")
		if icon.texture!=meta.CostIcon.texture(pair[0]) or not label.text.ends_with(meta._fmt(pair[1])):
			push_error("资源栏图标或金额错误："+str(pair[0]));get_tree().quit(1);return
	MetaProgress.currency=before
	meta._refresh()
	print("BASE_WALLET_ICONS_OK 3")
	var hero=preload("res://scripts/ui/hero_progression.gd").new()
	add_child(hero)
	hero.selected="TTNK"
	var saved_training=MetaProgress.academy.get("hero_training",{}).duplicate(true)
	MetaProgress.academy.hero_training={"TTNK":{"firepower":23,"health":20}}
	for pair in [[hero.firepower,"firepower","火力",5416],[hero.health,"health","生命",4600]]:
		hero._training_button(pair[0],pair[1],pair[2],true)
		var price_row=pair[0].get_node("TrainingPrice").get_child(1)
		if price_row.get_child(0).texture!=meta.CostIcon.texture("credits") or price_row.get_child(1).text!="%d 军需券"%pair[3]:
			push_error("英雄训练价格或图标错误");get_tree().quit(1);return
	MetaProgress.academy.hero_training=saved_training
	hero.free()
	print("HERO_TRAINING_PRICE_ICONS_OK 2")
	var checks:=0
	for id in Unit.PoolCards.ACTIVES.keys()+Demo.PASSIVE:
		meta._open_card_demo(id,"")
		var gallery=meta.get_node("FactionCardDemos")
		for rank in 4:
			gallery.select_rank(rank)
			gallery.playback.seek(2.7)
			if gallery.stage.card!=id or gallery.stage.preview_rank!=rank or not gallery.values.text.contains(Demo.result(id,rank)):
				get_tree().quit(1);return
			gallery.stage.queue_redraw()
			await get_tree().process_frame
			checks+=1
		gallery.free()
	print("POOL_DEMOS_OK ",checks)
	var talent_checks:=0
	for pair in [["LCRF","fleet_cannon"],["SAPC","fleet_rockets"],["FV","fv_intercept"],["V3","v3_cluster"]]:
		meta._show_talent_demo(pair[0],pair[1],0)
		var popup=meta.get_node("TalentDemo")
		var preview=popup.find_child("Preview",true,false)
		var levels=popup.find_children("*","OptionButton",true,false)[0]
		for rank in 4:
			levels.select(rank)
			levels.item_selected.emit(rank)
			preview.age=preview.demo_duration()-0.5
			preview._animate()
			if preview.rank!=rank or preview.demo!=pair[1] or preview.actor==null:
				get_tree().quit(1);return
			await get_tree().process_frame
			talent_checks+=1
		popup.free()
	print("POOL_TALENT_DEMOS_OK ",talent_checks)
	get_tree().quit()
