extends "res://tests/special_mechanics_regression.gd"
const X = preload("res://scripts/units/progression_expansion.gd")
const R = preload("res://scripts/units/expansion_rules.gd")
const Visual = preload("res://scripts/units/bomb_nest_visual.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2); return
	await get_tree().process_frame
	for side in ["ally", "enemy"]:
		for rank in 4:
			await exercise_nests(side, rank)
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed == 0 else 1)

func nests() -> Array:
	return battle.units.filter(func(u): return is_instance_valid(u) and not u._dead and Visual.handles(u))

func exercise_nests(side: String, rank: int) -> void:
	arena(MatchRules.EXTENDED)
	var tag := side + str(rank) + " "
	BattleRequest.combat_context.card_ranks["ap_bomb_nests"] = rank
	var zep = battle.spawn_unit("ZEP", side, Vector2(1200,1200))
	var ab := Ability.new()
	ab.setup(GameData.get_skill("ap_bomb_nests"), R.rank(zep,"ap_bomb_nests"))
	zep.skills.append(ab)
	check(zep.use_ability(zep.skills.size()-1), tag + "real ability entry accepts bomb drop")
	X.Cards.tick(zep,0.01)
	check(nests().size()==1,tag+"first bomb drops immediately")
	X.Cards.tick(zep,0.58)
	check(nests().size()==1,tag+"second bomb waits for cadence")
	X.Cards.tick(zep,0.62)
	var bombs := nests()
	check(bombs.size()==3,tag+"three bombs after two intervals")
	if bombs.size()!=3:
		await finish(); return
	var bomb = bombs[0]
	check(bomb.display_name=="空投弹巢" and bomb.weapon.is_empty() and bomb.skills.is_empty() and bomb.move_speed==0 and bomb.collision_layer==0,tag+"stationary noncombat mine carrier")
	check(not Visual.handles(zep) and not Visual.handles(battle.spawn_unit("E1",side,Vector2(1600,1600))),tag+"ordinary infantry and aircraft keep normal rendering")
	var initial := Visual.height(bomb)
	check(initial>0,tag+"bomb starts above ground")
	bomb.queue_redraw()
	await get_tree().process_frame
	check(bomb._body_bounds.size==Vector2(22,22),tag+"real draw dispatch uses bomb casing bounds")
	bomb._physics_process(0.3)
	check(is_equal_approx(Visual.height(bomb),initial*.5),tag+"halfway through falling")
	# Exercise the existing save graph, including a legacy nest without new visual metadata.
	bombs[1].special.expansion_temporary.erase("drop_height")
	var saved: Dictionary = Snapshot.new().capture(battle)
	check(BattleSaves.validate(saved).is_empty(),tag+"midair save validates")
	Snapshot.new().restore(battle,saved)
	get_tree().paused=false; battle.paused=false
	bombs=nests(); bomb=bombs[0]
	check(is_equal_approx(Visual.height(bomb),initial*.5),tag+"reload preserves midair progress")
	check(Visual.height(bombs[1])>0,tag+"legacy E1 nest restores as falling bomb")
	var owner = bomb.special.expansion_temporary.owner
	check(is_instance_valid(owner) and owner.unit_id=="ZEP",tag+"save restores mine owner")
	var foe_side := "enemy" if side=="ally" else "ally"
	var foe = battle.spawn_unit("HTNK",foe_side,bomb.position)
	var ally = battle.spawn_unit("HTNK",side,bomb.position)
	var before: float = foe.hp
	var ally_hp: float = ally.hp
	bomb._physics_process(0.3)
	check(is_zero_approx(Visual.height(bomb)) and not bomb._dead and foe.hp==before,tag+"landed at 0.6 seconds without early blast")
	bomb._physics_process(0.29)
	check(not bomb._dead and foe.hp==before,tag+"arming interval protects against early blast")
	bomb._physics_process(0.02)
	check(bomb._dead and foe.hp<before and ally.hp==ally_hp,tag+"armed mine blasts enemy without friendly fire")
	# Expiry and air-only contacts retain the existing rules.
	var quiet=bombs[2]
	quiet.position=Vector2(1800,1200)
	battle.spawn_unit("ZEP",foe_side,quiet.position)
	quiet._physics_process(1.0)
	check(not quiet._dead and is_zero_approx(Visual.height(quiet)),tag+"air target does not trigger landed mine")
	quiet._physics_process(20.0)
	check(quiet._dead,tag+"untriggered mine expires")
	await finish()
