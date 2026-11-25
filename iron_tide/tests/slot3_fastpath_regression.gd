extends "res://tests/base_recovery_regression.gd"
const Rules = preload("res://scripts/units/expansion_rules.gd")

func old_rank(actor, id: String) -> int:
	if not Rules.active(actor) or not BattleRequest.has_unit_talent(actor.unit_id,id,actor.side): return -1
	return MetaProgress.talent_rank(actor.unit_id,id,BattleRequest.combat_context.get("unit_talents",{}))

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):get_tree().quit(2);return
	await get_tree().process_frame
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		check(Rules.talent_rank(null,"missing")==old_rank(null,"missing"),"null talent owner")
		var actor:=Unit.new()
		for id in GameData.meta_config.unit_talents:
			actor.unit_id=id
			for talent in GameData.meta_config.unit_talents[id]:
				for level in 4:
					BattleRequest.combat_context={"unit_talents":{id:{talent:level}}}
					for side in ["ally","enemy","ai2","neutral","ally"]:
						actor.side=side
						for state in 4:
							actor.hp=0.0 if state==1 else 100.0
							actor._dead=state==2
							actor.special={"expansion_temporary":true} if state==3 else {}
							check(Rules.talent_rank(actor,talent)==old_rank(actor,talent),"live owner/talent/state %s/%s/%s/%s/%s"%[id,talent,level,side,state])
		actor.free()
		var hud:BattleHUD=screen.hud
		for gm in [false,true,false]:
			GM.infinite_funds=gm
			for amount in [0.0,0.9,1.0,9999.0,10000.0,12345.0,12349.0]:
				battle.funds=amount
				Events.funds_changed.emit(amount)
				var expected:="资金 %s"%hud._fmt(battle.current_funds())
				if gm:expected+="  [GM ∞]"
				check(hud.funds_label.text==expected,"funds signal updates immediately including GM and rounding")
		GM.infinite_funds=false
		battle.funds=1000.0
		check(battle.try_spend(125.0) and battle.funds==875.0 and hud.funds_label.text=="资金 875","actual production payment updates label synchronously")
		check(not battle.try_spend(900.0) and battle.funds==875.0,"failed payment preserves funds")
		Events.power_changed.emit(0,0,false)
		check(not hud.power_label.text.is_empty(),"power signal retains full status refresh")
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
