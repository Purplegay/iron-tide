extends "res://tests/progression_expansion_2_demo_regression.gd"
const Water=preload("res://scripts/ui/water_relay_demo.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation") or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	await get_tree().process_frame
	MetaProgress.reset_save();BattleRequest.configure_skirmish(MatchRules.EXTENDED,{"map_size":2400})
	naval_samples()
	var stage=preload("res://scripts/ui/faction_card_stage.gd").new();stage.size=Vector2(460,200);add_child(stage);stage.set_process(false)
	for rank in 4:
		var before:=Water.sample(rank,3.99);var settled:=Water.sample(rank,4.)
		check(before.active and before.stored==[150.,200.,250.,300.][rank] and before.shield==0,"demo accumulates actual prevented hits up to per-rank cap")
		check(settled.transfer and not settled.active and settled.recipient=="near" and settled.shield==before.stored,"demo transfers pooled reserve to weakest selected ship")
		check(settled.health==before.health,"shield transfer cannot heal HP")
		var hit:=Water.sample(rank,6.)
		check(hit.shield==maxf(0,settled.shield-200) and hit.health.near==settled.health.near-maxf(0,200-settled.shield),"demo hit consumes shield before HP")
		check(Water.sample(rank,10.).shield==0 and Water.sample(rank,12.1).stored==0,"demo shows shield expiry and resets next independent cycle")
		var desc:=MetaProgress.Academy.skill_description(GameData.get_skill(Water.CARD),rank)
		check(desc.contains("余波接力") and desc.contains("6秒护盾") and not desc.contains("{"),"rank description resolves relay parameters")
		stage.configure(Water.CARD,0,"",rank);stage.playing=false
		for time in [.1,.79,.81,2.,3.2,3.99,4.,4.3,5.99,6.,9.99,10.,12.1]:
			stage.elapsed=time;stage.sync_caster();stage.queue_redraw();await get_tree().process_frame;await RenderingServer.frame_post_draw
			check(stage.caster_model.actor!=null and not stage.caster_model.texture.get_size().is_zero_approx(),"actual GPU relay timeline "+str(rank)+"/"+str(time))
	GameData.progression_tuning.apply("skill/ap_escort_water",{"values/relay_cap/3":.5,"values/relay_duration/3":9})
	check(Water.duration()==15 and Water.sample(3,4.).cap==500 and Water.sample(3,4.).shield==324 and Water.sample(3,12.).shield>0,"edited cap and shield lifetime drive live demonstration")
	GameData.progression_tuning.apply("skill/ap_escort_water",{})
	stage.free();await get_tree().process_frame
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"screenshots":0},"  "))
	get_tree().quit(0 if failed==0 else 1)
