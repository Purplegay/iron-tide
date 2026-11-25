extends "res://tests/demo_playback_regression.gd"
const Gallery=preload("res://scripts/ui/faction_card_gallery.gd")

func exercise(mode:String) -> void:
	super.exercise(mode)
	if mode==MatchRules.RA2:return
	var before:=JSON.stringify(MetaProgress.to_dict())
	var context:=BattleRequest.combat_context.duplicate(true)
	var expected:=MetaProgress.skill_draw_candidates().map(func(row):return str(row.id))
	check(Gallery.card_ids()==expected,"gallery derives every candidate including unowned cards from current draw pool")
	var original:=GameData.skills.duplicate()
	GameData.skills.reverse()
	var gallery:=Gallery.new();add_child(gallery)
	check(gallery.ids==Gallery.preview_ids(),"reordered card and hero data stays synchronized without hand maintained positions")
	for id in gallery.ids:
		for rank in 4:
			gallery.select_card(gallery.ids.find(id),rank)
			check(gallery.stage.card==id and gallery.stage.preview_rank==rank and gallery.picker.get_item_metadata(gallery.picker.selected)==id,"stable ID dispatch and picker "+id+str(rank))
			check(not gallery.summary.text.contains("{") and not gallery.values.text.is_empty(),"resolved rule and growth "+id+str(rank))
	for id in ["ps_chrono_commission","ps_chrono_sabotage"]:
		for rank in 4:
			gallery.select_card(gallery.ids.find(id),rank)
			var goal:int=GameData.get_skill(id).objective_by_rank[rank]
			check(gallery.stage.commission_state().goal==goal and gallery.values.text.contains("%d 次"%goal),"commission threshold shared with rules "+id+str(rank))
			gallery.playback.seek(0.5)
			check(not gallery.stage.commission_state().lab and gallery.stage.commission_state().count==0,"no progress before actual objective event")
			gallery.playback.seek(1.7)
			check(gallery.stage.commission_state().count==0,"shooting or bomb placement alone does not count")
			gallery.playback.seek(2.01)
			check(gallery.stage.commission_state().count==1 and not gallery.stage.commission_state().lab,"kill or detonation advances before laboratory is ready")
			gallery.playback.seek(1.21+goal*0.8)
			check(gallery.stage.commission_state().unlocked,"threshold unlocks production")
			gallery.stage.playing=false;gallery.playback.seek(1.7);gallery.select_rank((rank+1)%4)
			check(is_equal_approx(gallery.stage.elapsed,1.7) and not gallery.stage.playing,"commission rank switch preserves timeline")
	gallery.free();GameData.skills.assign(original)
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	for pair in [["ps_chrono_commission","CCOMAND"],["ps_chrono_sabotage","CIVAN"]]:
		meta._open_card_demo(pair[0],pair[1])
		var demo=meta.get_node_or_null("FactionCardDemos")
		check(demo!=null and demo.stage.card==pair[0] and demo.refit_unit==pair[1],"refit opens commission demo "+pair[0])
		if demo:demo.free()
	meta.free()
	check(JSON.stringify(MetaProgress.to_dict())==before and BattleRequest.combat_context==context,"all demonstrations leave wallet unlocks and live battle untouched")
