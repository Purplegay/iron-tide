extends "res://tests/ground_control_regression.gd"

func drawn_pose(building: Building) -> Array:
	var pose := []
	for layer: Dictionary in building._ra2_anim:
		var kind := str(layer.kind)
		if not building._layer_visible(kind): continue
		var state: Dictionary = building._anim_layer(layer)
		pose.append([kind,state.image,building._anim_frame_for(layer,state)])
	return pose

func exercise(mode: String) -> void:
	start(mode)
	check_target_equivalence()
	for id in ["GAPOWR","GAREFN","GAWEAP","NAMISL","ATESLA","NAYARD","GADEPT"]:
		var building: Building = battle._place_building(id,"ally",Vector2(1300,1200),true)
		building.selected=true
		building._buildup_play=-1.0
		building._anim_key=-1
		building._animation_draw_needed()
		check(not building._animation_draw_needed(),prefix+id+" unchanged complete animation pose does not redraw")
		var missed:=[]
		var previous:=drawn_pose(building)
		for frame in 120:
			building._anim_t+=1.0/60.0
			building._tick_anim_state(1.0/60.0)
			var current:=drawn_pose(building)
			var refresh:=building._animation_draw_needed()
			if current!=previous and not refresh:missed.append(frame)
			if building._animation_draw_needed():missed.append(-frame-1)
			previous=current
		check(missed.is_empty(),prefix+id+" every changed renderer pose refreshes once",missed)
		building.position=Vector2.ONE*battle.map_size*5
		building.selected=false
		building.hovered=false
		building._anim_key=-123456789
		check(not building._animation_draw_needed() and building._anim_key==-123456789,prefix+id+" offscreen sprite skips frame inspection")
		var before:float=building._anim_t
		building._process(0.05)
		check(building._ra2_anim.is_empty() or building._anim_t>before,prefix+id+" offscreen animation time still advances")
		building.selected=true
		var refreshed:=building._animation_draw_needed()
		check(refreshed and not building._animation_draw_needed(),prefix+id+" selected/re-entered sprite resolves current pose immediately")
	var site:Building=battle._place_building("GAPOWR","ally",Vector2.ONE*battle.map_size*5,false)
	battle.funds=10000.0
	var work:=site.build_elapsed
	var funds:float=battle.funds
	site._process(0.1)
	check(site.build_elapsed>work and battle.funds<funds,prefix+" offscreen construction still advances and charges funds")
	await finish()

# Retained pre-optimization decision order, independent of the new fast branches.
func reference_weapon_allowed(unit, target, w: Dictionary) -> bool:
	if Ra3Mirage.field_active(unit): return false
	if not AlliedAbilities.alive(target) or float(w.get("damage", 0)) < 0.0 or AlliedAbilities.frozen(unit): return false
	if unit.unit_id in ["SPY", "ENGINEER", "SENGINEER"]: return false
	if AlliedAbilities.alive(target.special.get("temporal_by")) and target.special.temporal_by != unit and Unit.TankHero.rank(target,true)<4: return false
	if unit.unit_id in ["DOG", "SOV_DOG", "SNIPE"] and not AlliedAbilities.infantry(target): return false
	var flags: Dictionary = GameData.ra2_warheads.get(str(w.get("ra2_warhead", "")).to_lower(), {}).get("extra", {})
	if target is ForceFirePoint and (GameData._ra2_flag(flags.get("MindControl")) or GameData._ra2_flag(flags.get("Temporal"))): return false
	if BattleRequest.friendly(target.side,unit.side) and GameData._ra2_flag(flags.get("MindControl")): return false
	if GameData._ra2_flag(flags.get("MindControl")):
		if not target is Unit or target.is_air or AlliedAbilities.flag(target, "ImmuneToPsionics") or target.special.has("controller"): return false
		if AlliedAbilities.alive(unit.special.get("controlled")): return false
	if GameData._ra2_flag(flags.get("Temporal")):
		if target is Unit and (target.is_air or str(AlliedAbilities.source(target).get("Warpable", "yes")).to_lower() in ["no", "false", "0"]): return false
	if target is Unit and AlliedAbilities.concealed(target, unit.side) and not (unit.attack_ordered and unit.attack_target == target): return false
	return true

func reference_naval_allowed(unit, target) -> bool:
	if Unit.TankHero.rank(unit)>=0 and NavalContact.underwater_type(target):return unit.position.distance_squared_to(target.position)<=unit.attack_range*unit.attack_range
	if not NavalContact.underwater_type(target): return unit.unit_id != "ASW"
	var flags: Dictionary = GameData.ra2_source_units.get(unit.unit_id, {}).get("extra", {})
	return int(flags.get("NavalTargeting", 0)) in [1, 2, 3, 4, 5]

func check_target_equivalence() -> void:
	var targets := []
	for id in ["MTNK","E1","JUMPJET","SUB","SQD"]:
		targets.append(battle.spawn_unit(id,"enemy",Vector2(1800,1800)))
	targets.append(battle._place_building("GAPOWR","enemy",Vector2(2000,1800),true))
	targets.append(ForceFirePoint.new())
	var guardian:Unit=battle.spawn_unit("CLEG","enemy",Vector2(2200,1800))
	var mismatches:=[]
	var cases:=0
	var definitions := {"perf_plain":{},"perf_control":{"MindControl":"yes"},"perf_temporal":{"Temporal":"true"},"perf_both":{"MindControl":true,"Temporal":true}}
	for name in definitions:GameData.ra2_warheads[name]={"extra":definitions[name]}
	for id in ["MTNK","ASW","PTROOP","CLEG","DOG","SNIPE","SPY"]:
		var unit:Unit=battle.spawn_unit(id,"ally",Vector2(1700,1800))
		for target in targets:
			var original:Dictionary=target.special.duplicate()
			for state in ["ordinary","friend","ordered","frozen","controlled","controller","temporal","echo"]:
				unit.special.clear()
				target.special=original.duplicate()
				target.side="ally" if state=="friend" else "enemy"
				unit.attack_ordered=state=="ordered"
				unit.attack_target=target if unit.attack_ordered else null
				if state=="frozen":unit.special.chrono_left=1.0
				if state=="controlled":unit.special.controlled=guardian
				if state=="controller":target.special.controller=guardian
				if state=="temporal":target.special.temporal_by=guardian
				if state=="echo":target.special.echo_cloaked=true
				for name in definitions:
					var weapon:={"damage":10.0,"ra2_warhead":name}
					if reference_weapon_allowed(unit,target,weapon)!=AlliedAbilities.valid_weapon_target(unit,target,weapon):mismatches.append([id,state,name])
					cases+=1
			for hero in [false,true]:
				for wreck in [false,true]:
					unit.special.clear()
					if hero:unit.special.academy_hero="MTNK"
					if wreck:unit.special.hero_wreck={}
					for distance in [10.0,2000.0]:
						unit.position=target.position+Vector2(distance,0)
						if reference_naval_allowed(unit,target)!=NavalContact.weapon_allows(unit,target):mismatches.append([id,"naval",hero,wreck,distance])
						cases+=1
			target.special=original
		unit.special.clear()
		unit.attack_target=null
		unit.attack_ordered=false
	for name in definitions:GameData.ra2_warheads.erase(name)
	check(mismatches.is_empty(),prefix+"weapon/domain decisions match retained reference across "+str(cases)+" live states",mismatches)
	metrics.append({"target_equivalence_cases":cases})

