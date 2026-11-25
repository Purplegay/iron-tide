extends "res://tests/allied_abilities_regression.gd"
## Startup regression deliberately avoids unrelated GM UI and spawn cleanup.

func exercise_mode(mode: String) -> void:
	if mode != MatchRules.EXTENDED: return
	setup_logistics_scene(mode, "美国")
	for id in ["R3FUTURE", "R3HARBINGER"]:
		var unit = actor(id, "ally", Vector2(1500, 1500))
		var model = unit._ra3_model
		check(is_instance_valid(model), id + ": model instantiates after autoload startup")
		if not is_instance_valid(model): continue
		model.set_process(false)
		var effect = model.damage_state
		check(is_instance_valid(effect), id + ": deferred damage script loads and instantiates")
		if not is_instance_valid(effect): continue
		unit.hp = unit.max_hp
		effect.tick(0.0)
		check(effect.state == 0 and effect.rows.is_empty(), id + ": healthy state starts clean")
		unit.hp = unit.max_hp * 0.2
		effect.tick(1.0 / 30.0)
		check(effect.state == 2 and not effect.rows.is_empty(), id + ": damaged state creates particles")
		check(effect.rows.all(func(row): return row.sprite.texture != null), id + ": emitted textures resolve")
		unit.hp = unit.max_hp
		for i in 90: effect.tick(1.0 / 30.0)
		check(effect.rows.is_empty() and effect.lights.is_empty(), id + ": repair expires damage effects")
		unit.free()
		battle.units.erase(unit)
	screen.free()
	await get_tree().process_frame
