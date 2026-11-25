extends "res://tests/electric_cards_regression.gd"
const Gallery=preload("res://scripts/ui/faction_card_gallery.gd")
const Scope=preload("res://scripts/rules/skill_scope.gd")

func exercise(mode:String) -> void:
	if mode==MatchRules.RA2:return
	var before:=JSON.stringify(MetaProgress.to_dict())
	var context:=BattleRequest.combat_context.duplicate(true)
	var gallery:=Gallery.new();add_child(gallery)
	var count:=0
	for id in gallery.ids:
		gallery.select_card(gallery.ids.find(id),0)
		var stage=gallery.stage
		var rule:=GameData.get_skill(id)
		if not Scope.exclusive(rule):
			check(stage.caster_model_id.is_empty() and not is_instance_valid(stage.caster_model),"nonexclusive releases caster "+id)
			continue
		count+=1
		check(stage.caster_model_id==str(rule.get("objective_unit",rule.allowed_units[0])) and is_instance_valid(stage.caster_model),"caster derived from sole allowed unit "+id)
		var model=stage.caster_model
		check(model.actor.unit_id==str(rule.get("objective_unit",rule.allowed_units[0])) and model.actor.process_mode==Node.PROCESS_MODE_DISABLED,"correct frozen display actor "+id)
		check(not model.actor.is_in_group("combatants") and not model.actor.is_physics_processing() and model.viewport.world_2d!=get_viewport().world_2d,"isolated from match "+id)
		gallery.playback.user_seek(1.5)
		stage.sync_caster()
		check(is_equal_approx(model.age,1.5) and is_equal_approx(model.actor._anim,1.5),"seek updates model timeline "+id)
		gallery.select_rank(3)
		stage.sync_caster()
		check(stage.caster_model==model and is_equal_approx(model.age,1.5) and not stage.playing,"rank reuses model and preserves pause position "+id)
		check(is_equal_approx(Iso.dir(Vector2.from_angle(model.actor.hull_angle)).angle(),0.0) and model.texture!=null,"caster faces schematic target with render texture "+id)
	check(count>=9,"all current single unit cards covered")
	gallery.free()
	check(JSON.stringify(MetaProgress.to_dict())==before and BattleRequest.combat_context==context,"demo leaves progression and battle context unchanged")
