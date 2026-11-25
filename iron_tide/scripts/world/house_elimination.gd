extends RefCounted
## Freeze all eliminated ownership before callbacks release control or passengers.
const FLAG := "house_eliminated"

static func update(world) -> Dictionary:
	var houses:Array=BattleRequest.house_teams.keys() if not BattleRequest.house_teams.is_empty() else ["ally","enemy"]
	var defeated:Dictionary=world.allied_state.get_or_add("defeated_houses",{})
	var surviving:Dictionary={}
	var lost:Array=[]
	for side:String in houses:
		surviving[side]=not defeated.has(side) and world.has_surviving_assets(side)
		if not surviving[side] and not defeated.has(side): lost.append(side)
	if lost.is_empty(): return surviving
	eliminate(world,lost)
	world.selected_units=world.selected_units.filter(func(unit):return world.actor_alive(unit))
	if not world.actor_alive(world.selected_building): world.selected_building=null
	world.invalidate_ai_population()
	world._update_power()
	world._emit_selection()
	announce(world, lost)
	return surviving

static func announce(world, lost: Array) -> void:
	var enemy_defeated := false
	for side: String in lost:
		if not BattleRequest.is_ai_house(side): continue
		if not BattleRequest.friendly("ally", side): enemy_defeated = true
		var notice := defeat_notice(world, side)
		Events.emit_message(notice.text, notice.color)
		world.computer_defeated.emit(side, notice.text, notice.color)
	if enemy_defeated:
		preload("res://scripts/world/battle_music_director.gd").trigger_uprising(world)
		Ra2Sfx.play_player_eva(world, "EVA_PlayerDefeated", 0)

static func eliminate_hostiles(world) -> void:
	var houses:Array=BattleRequest.house_teams.keys() if not BattleRequest.house_teams.is_empty() else ["enemy"]
	var hostiles:Array=[]
	for side:String in houses:
		if BattleRequest.is_ai_house(side) and not BattleRequest.friendly("ally",side):
			hostiles.append(side)
	eliminate(world,hostiles)

static func eliminate(world,lost:Array) -> void:
	var defeated:Dictionary=world.allied_state.get_or_add("defeated_houses",{})
	for side:String in lost: defeated[side]=true
	var victims:Array=[]
	for actor in world.units+world.buildings:
		if not is_instance_valid(actor) or actor._dead or actor.is_queued_for_deletion() or not lost.has(actor.side): continue
		actor.special[FLAG]=true
		victims.append(actor)
	# Mark everyone first: a transport/airport may destroy children recursively.
	for actor in victims:
		if not is_instance_valid(actor) or actor._dead or actor.is_queued_for_deletion(): continue
		actor.hp=0.0
		actor._die()

static func defeat_notice(world, side: String) -> Dictionary:
	var index := 1 if side == "enemy" else side.trim_prefix("ai").to_int()
	var rows: Array = BattleRequest.skirmish_config.get("houses", [])
	var row: Dictionary = rows[index] if index >= 0 and index < rows.size() else {}
	var country: String = row.get("country", BattleRequest.skirmish_config.get("enemy_country", "电脑"))
	var relation := "盟友" if BattleRequest.friendly("ally", side) else "敌方"
	var faction: Dictionary = GameData.get_faction(world.roster_faction(side))
	return {"text":"%s指挥官%s（%s）已被击败" % [relation, BattleRequest.Houses.commander_label(row if not row.is_empty() else {"country":country},index), country],
		"color":HouseColor.color_for_side(side, str(faction.get("color", "#ff5b4a")))}
