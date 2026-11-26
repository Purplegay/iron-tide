extends "res://tests/soviet_opening_regression.gd"

const Squid = preload("res://scripts/units/soviet_specials.gd")
const Drone = preload("res://scripts/units/soviet_advanced.gd")

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("IronTideParasiteValidation"):
		get_tree().quit(2)
		return
	await get_tree().process_frame
	start_soviet("苏俄", "allied", "prebuilt")
	for own_kill in [false, true]:
		var point := Vector2(2700, 1600)
		var host = battle.spawn_unit("DEST", "enemy", point)
		var squid = battle.spawn_unit("SQD", "ally", point + Vector2(90, 0))
		check(Squid.shoot(squid, host, squid.weapon) and squid.embarked_in == host, "squid attaches to enemy ship")
		var killer = squid if own_kill else battle.spawn_unit("DEST", "ally", point + Vector2(180, 0))
		host.hp = 1
		host.receive_hit(10000, "shell", {}, killer)
		check(AlliedAbilities.alive(squid) == own_kill, "squid survives only its own host kill: " + str(own_kill))
		if own_kill:
			check(squid.embarked_in == null and squid.side == "ally" and battle.actor_alive(squid), "squid returns to its original owner")
		check(not host.special.has("squid"), "dead ship releases squid reference")
	var protected_host = battle.spawn_unit("DEST", "enemy", Vector2(2700, 1800))
	var protected_squid = battle.spawn_unit("SQD", "ally", protected_host.position + Vector2(90, 0))
	Squid.shoot(protected_squid, protected_host, protected_squid.weapon)
	protected_squid.special.iron_left = 5.0
	protected_host.hp = 0
	protected_host._die(battle.spawn_unit("DEST", "ally", protected_host.position + Vector2(180, 0)))
	check(AlliedAbilities.alive(protected_squid) and protected_squid.embarked_in == null and protected_squid.side == "ally", "iron-curtained squid survives external host kill")
	for own_kill in [false, true]:
		var point := Vector2(2100, 1100)
		var host = battle.spawn_unit("HTNK", "enemy", point)
		var drone = battle.spawn_unit("DRON", "ally", point + Vector2(90, 0))
		Drone.contact(drone, host)
		check(host.special.get("parasite") == drone and drone.embarked_in == host, "drone infests enemy vehicle")
		var killer = drone if own_kill else battle.spawn_unit("HTNK", "ally", point + Vector2(180, 0))
		host.hp = 1
		host.receive_hit(10000, "shell", {}, killer)
		check(AlliedAbilities.alive(drone) == own_kill, "drone survives only its own host kill: " + str(own_kill))
		if own_kill:
			check(drone.embarked_in == null and drone.side == "ally" and battle.actor_alive(drone), "drone returns to its original owner")
		check(not host.special.has("parasite"), "dead vehicle releases drone reference")
	FileAccess.open(output_dir.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}, "  "))
	print("PARASITE_HOST_DEATH_RESULT ", checks.size(), " checks, ", failed, " failed")
	get_tree().quit(0 if failed == 0 else 1)
