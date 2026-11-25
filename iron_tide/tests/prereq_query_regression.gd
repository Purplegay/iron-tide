extends "res://tests/building_membership_regression.gd"
var micro_done := false
func verify(label:String) -> void:
	super.verify(label)
	var products: Array = GameData.ra2_prereq.keys()
	products.append_array(["", "UNKNOWN", "__test"])
	GameData.ra2_prereq["__test"] = ["  tech ", "", "power", "POWER", "unknown"]
	for side in ["ally", "enemy", "ai2", "neutral"]:
		var owned := original(side)
		for id: String in products:
			check(battle.production_prereqs_ok(id,side)==GameData.ra2_prereq_ok(id,owned,battle.allied_state,side),prefix+label+" prerequisite "+side+id)
		battle.ai_prerequisite_scan=true
		battle.ai_scan_buildings[side]=["GATECH","NAWEAP","NAPOWR"]
		for id in ["MTNK","APOC","BORIS","__test"]:
			check(battle.production_prereqs_ok(id,side)==GameData.ra2_prereq_ok(id,battle.ai_scan_buildings[side],battle.allied_state,side),prefix+label+" AI scoped snapshot "+side+id)
		battle.ai_scan_buildings.clear();battle.ai_prerequisite_scan=false
	GameData.ra2_prereq.erase("__test")
	if not micro_done:
		micro_done=true
		var definition:Dictionary=GameData.building_index["GAPOWR"]
		var saved_tags=definition.get("tags",[])
		for tags in [[],["tech"],["power","radar","refinery"]]:
			definition.tags=tags
			GameData.ra2_prereq["__dynamic"]=["POWER","RADAR","PROC","TECH"]
			for token in ["POWER","RADAR","PROC","TECH"]:
				GameData.ra2_prereq["__dynamic"]=[token]
				check(battle.production_prereqs_ok("__dynamic","ally")==GameData.ra2_prereq_ok("__dynamic",original("ally"),battle.allied_state,"ally"),"live catalog mutation "+token+str(tags))
		definition.tags=saved_tags
		GameData.ra2_prereq.erase("__dynamic")
		var measurements:Array=[]
		for round_index in 7:
			var row:Dictionary={}
			for candidate in ([false,true] if round_index%2==0 else [true,false]):
				var start_us:=Time.get_ticks_usec()
				var answer:=0
				for i in 300:
					for id in ["E1","MTNK","ORCA","APOC","BORIS","SREF","NAWEAP","GATECH"]:
						var value:bool=battle.production_prereqs_ok(id,"ally") if candidate else GameData.ra2_prereq_ok(id,battle.owned_building_ids("ally"),battle.allied_state,"ally")
						if value:answer+=1
				row["candidate" if candidate else "reference"]={"us":Time.get_ticks_usec()-start_us,"answer":answer}
			check(row.candidate.answer==row.reference.answer,"timed prerequisite results equal")
			measurements.append(row)
		FileAccess.open(output_dir.path_join("micro.json"),FileAccess.WRITE).store_string(JSON.stringify(measurements,"  "))
