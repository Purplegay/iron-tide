extends "res://tests/base_recovery_regression.gd"
func original(side:String) -> Array:
	var result:Array=[]
	for candidate in battle.buildings:
		if not is_instance_valid(candidate):continue
		var b:Building=candidate
		if b.side!=side or b.hp<=0 or b.is_dead() or b.is_queued_for_deletion() or b.under_construction:continue
		result.append(str(b.building_id))
	return result
func verify(label:String) -> void:
	for side in ["ally","enemy","ai2","neutral"]:
		check(battle.owned_building_ids(side)==original(side),prefix+label+" ownership "+side)
		var expected:=0
		for b in battle.buildings:
			if is_instance_valid(b) and b.side==side and b.hp>0 and not b.under_construction:
				var raw:Dictionary=GameData.ra2_source_buildings.get(b.building_id,{}).get("extra",{})
				if str(raw.get("UnitReload","")).to_lower()=="yes" and str(raw.get("Helipad","")).to_lower()=="yes":expected+=int(raw.get("NumberOfDocks",0))
		check(battle.aircraft_capacity(side)==expected,prefix+label+" airport capacity "+side)
		for id in ["","E1","MTNK","ORCA"]:
			var count:=0
			for candidate in battle.buildings:
				if not battle.actor_alive(candidate):continue
				var factory:Building=candidate
				if factory.side!=side or not factory.is_operational():continue
				if (id.is_empty() and factory.is_hq) or (not id.is_empty() and not factory.is_refinery() and factory.buildable.has(id)):count+=1
			var data:Dictionary=GameData.get_building(battle.roster_id("GACNST",side)) if id.is_empty() else GameData.get_unit(id)
			var rate:float=1.0 if BattleRequest.extensions_enabled() else GameData.ra2_build_time(data)/GameData.ra2_build_time(data,maxi(1,count))
			check(battle.factory_speed_factor(side,id)==rate,prefix+label+" factory speed "+side+id)
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for mode in [MatchRules.RA2,MatchRules.EXTENDED]:
		start(mode)
		battle.ai_prerequisite_scan=false
		verify("initial")
		var coil:Building=battle._place_building("TESLA","ally",Vector2(1800,1500),true)
		coil._buildup_play=-1.0;battle.power_low=true
		coil.special.tesla_chargers=[null]
		battle.factory_speed_factor("ally","MTNK")
		check(coil.special.tesla_chargers.size()==(1 if BattleRequest.extensions_enabled() else 0),prefix+"preserve Tesla stale charger cleanup side effect")
		battle.power_low=false
		var factory:Building=battle._place_building("GAWEAP","ally",Vector2(1500,1500),true)
		factory._buildup_play=-1.0
		verify("additional operational factory")
		factory._buildup_play=0.0;verify("factory buildup")
		factory._buildup_play=-1.0;factory._prism_offline=1.0;verify("factory offline")
		factory._prism_offline=0.0;factory.special.chrono_left=1.0;verify("factory frozen")
		factory.special.clear();factory.powered=true;battle.power_low=true;verify("factory low power")
		battle.power_low=false;verify("factory power restored")
		factory.buildable.append("E1");verify("factory roster changed in place")
		factory.data=factory.data.duplicate(true);factory.data.tags=["refinery"];verify("refinery excluded from factory bonus")
		factory.data.tags=[];factory.hp=0;verify("factory zero health")
		factory.hp=factory.max_hp;factory.queue_free();verify("factory queued for deletion")
		var airport=battle._place_building("GAAIRC","ally",Vector2(1200,1200),true)
		verify("created same frame")
		airport.side="enemy";verify("capture same frame")
		airport.side="ai2";verify("third house same frame")
		airport.under_construction=true;verify("unfinished")
		airport.under_construction=false;verify("completed same frame")
		airport.hp=0;verify("zero hp")
		airport.hp=airport.max_hp;airport._dead=true;verify("dead flag")
		airport._dead=false;verify("restored")
		var saved=BattleSaves.Snapshot.new().capture(battle)
		BattleSaves.Snapshot.new().restore(battle,saved)
		get_tree().paused=false;battle.paused=false
		verify("snapshot restore")
		var removed:Building=battle.buildings.back()
		battle.buildings.erase(removed);removed.free();verify("removed")
		# A stale reference can survive until the world's next array cleanup.
		# Cover both a cached reference and rebuilding from that same array.
		var stale:=Building.new()
		stale.side="ally";stale.building_id="GAWEAP";stale.hp=100;stale.max_hp=100
		battle.buildings.append(stale)
		verify("unattached live entry")
		stale.free()
		verify("freed cached entry")
		battle.invalidate_building_membership()
		verify("freed entry during index rebuild")
		battle.buildings.append(null)
		verify("null and freed entries during index rebuild")
		battle.buildings.pop_back();battle.buildings.pop_back()
		await finish()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
