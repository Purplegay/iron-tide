extends "res://tests/hotpath_equivalence_regression.gd"

class ReferenceUnit extends Unit:
	func reference_loadout(target) -> Dictionary:
		if unit_id == "BORIS" and is_instance_valid(target) and target is Building: return data.special_weapon
		if unit_id == "SQD" and is_instance_valid(target) and target is Unit and SovietSpecials.organic(target):
			return data.get("elite_special_weapon", data.special_weapon) if veteran_level >= 2 else data.special_weapon
		var native := _effective_native_weapon(target)
		if not native.is_empty(): return OpenTopped.weapon(self, native) if embarked_in is Unit else native
		if data.has("anti_air_weapon") and is_instance_valid(target) and target is Unit and target.is_air_target():
			var aa:Dictionary=data.elite_anti_air_weapon if veteran_level >= 2 else data.anti_air_weapon
			return OpenTopped.weapon(self, aa) if embarked_in is Unit else aa
		if _deployed and data.has("deployed_weapon"):
			var deployed:=deployed_weapon()
			return OpenTopped.weapon(self, deployed) if embarked_in is Unit else deployed
		var base:=_ra2_weapon_override if not _ra2_weapon_override.is_empty() else weapon
		return OpenTopped.weapon(self, base) if embarked_in is Unit else base

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	for mode in [MatchRules.RA2, MatchRules.EXTENDED]:
		start(mode)
		exercise_bonuses()
		exercise_ranges()
		exercise_native_dispatch()
		exercise_power()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)

func exercise_native_dispatch() -> void:
	var ground: Unit = battle.spawn_unit("HTNK","enemy",Vector2(900,800))
	var air: Unit = battle.spawn_unit("JUMPJET","enemy",Vector2(920,800))
	air.logistics.air_lift = 1.0
	var ship: Unit = battle.spawn_unit("DEST","enemy",Vector2(940,800))
	var building: Building = battle.buildings[0]
	for id in ["MTNK","E1","GGI","APOC","BFRT","DRED","DEST","GHOST","TANY","CCOMAND","PTROOP","FV","CLEG","MGTK","BORIS","SQD","SCHP"]:
		var unit := ReferenceUnit.new()
		unit.setup(GameData.get_unit(id),"ally",Vector2(800,800))
		battle.add_child(unit)
		check(unit._battle_world()==battle and unit._navigation_world()==battle,prefix+"typed world resolves "+id)
		for rank in [0,2]:
			unit.veteran_level=rank
			unit._refresh_veteran_bonuses(false)
			for deployed in [false,true]:
				unit._deployed=deployed
				for target in [null,ground,air,ship,building]:
					check(unit._loadout_weapon_for_target(target)==unit.reference_loadout(target),prefix+"native dispatch retains original weapon %s/%s/%s"%[id,rank,deployed])
		unit.free()
	var orphan := Unit.new()
	check(orphan._battle_world()==null and orphan._navigation_world()==null,prefix+"preview without battle retains null world")
	orphan.free()

func exercise_power() -> void:
	var retained: Array = battle.buildings
	var retained_houses: Dictionary = battle.allied_state.get("house_ai",{})
	battle.buildings=[]
	battle.allied_state.house_ai={}
	var sides := ["ally","enemy","ai2","ai3","ai4","ai5"]
	for side in sides:
		if side!="ally":battle.allied_state.house_ai[side]={}
		for index in 6:
			var building := Building.new()
			building.side=side
			building.power=101 if index%2==0 else -35
			building.max_hp=100.0
			building.hp=[100.0,45.0,0.0][index%3]
			building.under_construction=index==4
			battle.buildings.append(building)
	for round_index in 3:
		if round_index==1:
			battle.buildings[0].side="ai3" # Ownership changes are visible immediately.
			battle.buildings[4].under_construction=false
		if round_index==2:
			battle.buildings[7].hp=0.0
			battle.buildings[8].hp=100.0
		for infinite in [false,true]:
			GM.infinite_power=infinite
			var expected := {}
			for side in sides:
				if side!="ally":expected[side]=battle._side_power(side)
			var produced:=0.0
			var drain:=0.0
			for building in battle.buildings:
				if building.side!="ally" or building.under_construction:continue
				if building.power>0:produced+=ceilf(building.power*clampf(building.hp/maxf(1.0,building.max_hp),0.0,1.0))
				elif building.power<0:drain-=building.power
			if infinite:produced=maxf(produced,drain)
			battle._update_power()
			check(battle.power_produced==produced and battle.power_drain==drain and battle.power_low==(produced<drain-.001),prefix+"single-pass player grid preserves HP/construction/infinite rule")
			for side in expected:
				var actual:Dictionary=battle.enemy_power if side=="enemy" else battle.allied_state.house_ai[side].power
				check(actual==expected[side],prefix+"single-pass grid equals original scan "+side)
	GM.infinite_power=false
	for building in battle.buildings:building.free()
	battle.buildings=retained
	battle.allied_state.house_ai=retained_houses
	battle._update_power()
