extends Node

class Scanner extends Unit:
	var coarse := true
	var domain_calls := 0
	func _scan_rejects_air(w: Dictionary) -> bool:
		return coarse and super._scan_rejects_air(w)
	func _weapon_domain_valid(t, cover := false, w: Dictionary = {}) -> bool:
		domain_calls += 1
		return super._weapon_domain_valid(t, cover, w)

var failures := 0
var checks := 0
var fixture_draws := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func actor(id: String, owner: String, point: Vector2, scanner := false) -> Unit:
	var u: Unit = Scanner.new() if scanner else Unit.new()
	u.setup(GameData.get_unit(id).duplicate(true), owner, point)
	# Keep scene-group membership for scanning, without ticking or rendering synthetic state.
	u.process_mode = Node.PROCESS_MODE_DISABLED
	u.hide()
	u.draw.connect(func(): fixture_draws += 1)
	add_child(u)
	return u

func compare(u: Scanner, label: String) -> int:
	u.coarse = false
	u.attack_target = null
	u.domain_calls = 0
	u._refresh_target()
	var old_target = u.attack_target
	var old_calls := u.domain_calls
	u.coarse = true
	u.attack_target = null
	u.domain_calls = 0
	u._refresh_target()
	check(is_same(old_target, u.attack_target), label)
	return old_calls - u.domain_calls

func _ready() -> void:
	BattleRequest.configure_skirmish(MatchRules.RA2, {})
	var u := actor("MTNK", "ally", Vector2(100,100), true) as Scanner
	u.fire_stance = "free"
	var ground := actor("MTNK", "enemy", Vector2(140,100))
	var air := actor("JUMPJET", "enemy", Vector2(140,100))
	var peer := actor("MTNK", "enemy", Vector2(140,100))
	air.logistics.air_lift = 1.0
	var saved := u.weapon
	u.weapon = saved.duplicate()
	u.weapon.ra2_aa = false
	check(u._scan_rejects_air(u.weapon), "standard ground weapon enables coarse reject")
	check(compare(u, "same target with airborne contact and tied ground pair") == 1, "airborne contact skips exactly one domain validation")
	check(is_same(u.attack_target, ground), "equal score keeps the first scene-group contact")
	air.logistics.air_lift = 0.0
	check(compare(u, "same target with landed contact") == 0, "landed contact does not bypass domain validation")
	air.special.para_height = 20.0
	check(compare(u, "same target with parachuting contact") == 1, "parachuting contact uses live airborne state")
	u.weapon.ra2_aa = true
	check(compare(u, "same target with air-capable weapon") == 0, "air-capable weapon never coarse rejects")
	u._weapon_target_rule = Unit.WeaponTargetRule.COMMANDO
	u.weapon.ra2_aa = false
	check(not u._scan_rejects_air(u.weapon), "commando eligibility stays on full path")
	u._weapon_target_rule = Unit.WeaponTargetRule.STANDARD
	var denied_id := "__scan_fixture_denied"
	var allowed_id := "__scan_fixture_allowed"
	GameData.ra2_projectiles[denied_id] = {"extra":{"AG":"FaLsE"}}
	GameData.ra2_projectiles[allowed_id] = {"extra":{"AG":"yes"}}
	GameData.rebuild_static_combat_rules()
	u.weapon.erase("ra2_projectile")
	var default_ground := u._weapon_domain_valid(ground, false, u.weapon)
	check(default_ground, "fixture can attack ground without an AG restriction")
	for projectile_id: String in [denied_id.to_upper(), allowed_id, "__scan_fixture_missing", ""]:
		u.weapon.ra2_projectile = projectile_id
		for t: Unit in [ground, peer, ground]:
			check(u._weapon_domain_valid(t, false, u.weapon) == (projectile_id.to_lower() != denied_id), "current weapon selects its own AG rule: " + projectile_id)
	GameData.ra2_projectiles.erase(denied_id)
	GameData.ra2_projectiles.erase(allowed_id)
	GameData.rebuild_static_combat_rules()
	var saboteur := actor("GHOST", "ally", Vector2(100,100), true) as Scanner
	saboteur.fire_stance = "free"
	var building := Building.new()
	building.building_id = "GAPOWR"
	building.data = GameData.get_building("GAPOWR").duplicate(true)
	building.hp = 100.0
	building.max_hp = 100.0
	building.side = "enemy"
	building.position = Vector2(140,100)
	building.process_mode = Node.PROCESS_MODE_DISABLED
	building.hide()
	add_child(building)
	check(CommandoCombat.building_c4(saboteur, building), "fixture supports C4")
	for t: Unit in [ground, peer, air]:
		t.remove_from_group(BattleRequest.foes_group("ally"))
	saboteur._refresh_target()
	check(is_same(saboteur.attack_target, building), "automatic scan keeps a valid C4 building")
	building.special.c4_left = 1.0
	check(not CommandoCombat.building_c4(saboteur, building), "already charged building cannot take another C4")
	# The contact intentionally has no parachute animation state. Let the renderer
	# run before quitting so an accidentally visible fixture cannot pass this test.
	await get_tree().process_frame
	await get_tree().process_frame
	check(fixture_draws == 0, "scan-only actors never receive a draw callback")
	print("Target scan reuse: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
