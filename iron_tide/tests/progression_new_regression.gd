extends "res://tests/base_recovery_regression.gd"
const NewContent=preload("res://scripts/ui/progression_new.gd")
const Gallery=preload("res://scripts/ui/faction_card_gallery.gd")

func selector_mark(meta,id:String) -> bool:
	var picker:OptionButton=meta.pool_body.get_node("TrainingCard")
	for index in picker.item_count:
		if picker.get_item_metadata(index)==id:return picker.get_item_text(index).contains("新！")
	return false

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save();BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	for card:Dictionary in GameData.raw_docs["progression_expansion_2.json"].skills:
		check(NewContent.card(card.id),"new ordinary card is marked before first acquisition "+str(card.id))
	for uid:String in GameData.raw_docs["progression_expansion_2.json"].unit_talents:
		for id:String in MetaProgress.talent_options(uid):
			check(NewContent.talent(uid,id)==bool(MetaProgress.talent_options(uid)[id].get("expansion2",false)),"only new unowned talent marked "+uid+"/"+id)
	check(not NewContent.card("ap_smoke") and not NewContent.talent("SHK","tesla_reserve") and not NewContent.card("unknown"),"existing and missing content is not marked new")
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta._set_page("units");meta._unit_sel="SHK";meta._rebuild_unit_detail()
	check(meta.unit_detail.get_node("TalentTitle_reserve_transfer").text.contains("新！"),"real talent detail displays new marker")
	meta._show_talent_demo("SHK","reserve_transfer",0)
	check(NewContent.talent("SHK","reserve_transfer"),"viewing talent demo does not acknowledge or unlock it")
	meta.get_node("TalentDemo").free()
	check(not MetaProgress.unlock_unit_talent("SHK","reserve_transfer",-1) and NewContent.talent("SHK","reserve_transfer"),"failed unlock preserves marker")
	MetaProgress.currency.credits=1000000;MetaProgress.currency.cores=100000;MetaProgress.currency.diamonds=100000
	var quote:=MetaProgress.talent_unlock_quote("SHK","reserve_transfer")
	check(MetaProgress.unlock_unit_talent("SHK","reserve_transfer",quote.cost),"real purchase unlocks rank zero")
	check(not NewContent.talent("SHK","reserve_transfer") and not meta.unit_detail.get_node("TalentTitle_reserve_transfer").text.contains("新！"),"successful unlock immediately refreshes actual talent title")
	check(MetaProgress.set_effect_enabled("talent","reserve_transfer","SHK",false) and not NewContent.talent("SHK","reserve_transfer"),"disabling owned talent never restores new marker")
	MetaProgress.unit_talents={};MetaProgress.load_save()
	check(not NewContent.talent("SHK","reserve_transfer"),"talent acquisition survives disk reload without separate seen flags")
	const CARD="ap_escort_water"
	meta._set_page("pool");meta.training_group=preload("res://scripts/rules/skill_scope.gd").group(GameData.get_skill(CARD));meta.selected_card=CARD;meta._refresh_pool()
	check(selector_mark(meta,CARD),"actual pool selector marks new card")
	var gallery:=Gallery.new();add_child(gallery);gallery.select_card(gallery.ids.find(CARD),2)
	check(gallery.summary.text.contains("新！") and gallery.picker.get_item_text(gallery.picker_indices[gallery.selected]).contains("新！"),"gallery selection and detail show marker")
	gallery.stage.elapsed=2.75;gallery.stage.playing=false
	check(NewContent.card(CARD),"previewing card ranks and animation does not clear mark")
	MetaProgress.academy.card_shards=10000
	check(MetaProgress.Academy.purchase(MetaProgress,"redeem",CARD),"real shard redemption obtains card")
	check(not NewContent.card(CARD) and not selector_mark(meta,CARD) and not gallery.summary.text.contains("新！"),"acquisition immediately removes marker in open pool and gallery")
	check(gallery.rank==2 and gallery.stage.elapsed==2.75 and not gallery.stage.playing,"marker refresh preserves preview rank clock and pause")
	MetaProgress.unlocked_skills.clear();MetaProgress.load_save()
	check(not NewContent.card(CARD),"card marker remains cleared after disk reload")
	gallery.free();meta.free()
	# Exercise the normal draw path; deterministic seed, no change to pool or weights.
	seed(1741);MetaProgress.academy.tickets=400
	var got_new:=false
	for attempt in 40:
		var before:Array=MetaProgress.skill_draw_candidates().filter(func(card):return NewContent.card(card.id)).map(func(card):return str(card.id))
		var rewards:Array=MetaProgress.Academy.draw(MetaProgress,10)
		for reward:Dictionary in rewards:
			if reward.id in before:
				check(MetaProgress.skill_unlocked(reward.id) and not NewContent.card(reward.id),"actual random first draw clears only acquired marker "+str(reward.id));got_new=true
		if got_new:break
	check(got_new,"real unchanged draw pool produced new expansion content")
	var unowned:Array=MetaProgress.skill_draw_candidates().filter(func(card):return card.get("expansion2",false) and not MetaProgress.skill_unlocked(card.id))
	check(not unowned.is_empty() and unowned.all(func(card):return NewContent.card(card.id)),"other uncollected new cards remain marked")
	MetaProgress.save();MetaProgress.unlocked_skills.clear();MetaProgress.load_save()
	check(unowned.all(func(card):return NewContent.card(card.id)),"remaining uncollected markers persist through disk reload")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("PROGRESSION_NEW_RESULT ",checks.size()," checks, ",failed," failed")
	get_tree().quit(0 if failed==0 else 1)
