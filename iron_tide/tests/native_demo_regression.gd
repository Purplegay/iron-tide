extends "res://tests/electric_cards_regression.gd"
const Training=preload("res://scripts/rules/skill_training.gd")
const Demo=preload("res://scripts/ui/native_talent_demo.gd")

func exercise(mode:String) -> void:
	if mode==MatchRules.RA2:return
	var before:=JSON.stringify(MetaProgress.to_dict())
	var context:=BattleRequest.combat_context.duplicate(true)
	var count:=0
	for id in Training.PROFILES:
		var talent:=Training.talent_id(id)
		if talent.is_empty():continue
		var demo:=Demo.new();add_child(demo);demo.configure(id,0)
		check(demo.stage.models.size()==2 and demo.stage.models[0].actor.unit_id==id,"two real visual models "+id)
		for rank in 4:
			demo.select_rank(rank)
			check(demo.stage.rank==rank and demo.levels.selected==rank,"level control selects "+id+str(rank))
			for time in [0.0,0.8,1.3,2.6,4.8,7.0]:
				demo.stage.elapsed=time;demo.stage.refresh()
				var state:Dictionary=demo.stage.sample(rank)
				check(not state.phase.is_empty() and state.at.is_finite(),"visible action phase "+id+str(rank)+str(time))
			demo.pause_button.pressed.emit()
			var stopped:float=demo.stage.elapsed;demo.stage._process(0.5)
			check(demo.stage.elapsed==stopped,"pause freezes model and effects "+id)
			demo.restart();check(demo.stage.elapsed==0 and demo.stage.playing,"replay resets action "+id)
		if id in ["DOG","SOV_DOG"]:
			demo.stage.elapsed=0.8
			check(demo.stage.sample(0).moving and demo.stage.sample(0).at.y<92,"dog leaps with original contact-flight duration")
			check(demo.stage.value(3)<demo.stage.value(0) and demo.stage.value(0)<demo.stage.value(-1),"dog trained intervals shorten by rank")
			check(demo.stage.models[0].actor._seq.has("FireUp"),"dog original firing animation available")
		demo.free();count+=1
	check(count==18,"all native preview entries have demos")
	check(JSON.stringify(MetaProgress.to_dict())==before,"demo does not write progression")
	check(BattleRequest.combat_context==context,"demo does not replace active battle context")
	var meta=preload("res://scripts/screens/meta_screen.gd").new();add_child(meta)
	meta._show_talent_demo("DOG","native_attack_cd",2)
	var panel=meta.find_child("NativeTalentDemo",true,false)
	check(panel!=null and panel.stage.rank==2,"real refit entry opens playable demo at owned rank")
	meta.free()
