extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
## Read-only presentation. Never own stack timers, mutate saves or combine targets.
const COLORS := [Color("#65dcff"),Color("#85ee9b"),Color("#ffd16a"),Color("#d7a1ff")]
const DIM := Color("#526274")

static func layer_color(index:int) -> Color:
	return COLORS[clampi(index,0,COLORS.size()-1)]

static func heat_count(actor,target) -> int:
	if not is_instance_valid(target) or not AlliedAbilities.alive(target):return 0
	var layers=actor.special.get("reaper_heat",{}).get(target,[])
	if layers is Array:return layers.filter(func(left):return float(left)>0.000001).size()
	return int(float(layers)>0.000001) # Old saves hold one remaining lifetime.

static func rows(actor) -> Array:
	var result:Array=[]
	if not AlliedAbilities.alive(actor) or actor.embarked_in!=null or actor.special.has("hero_wreck"):return result
	if actor.unit_id=="SHK" and preload("res://scripts/units/tesla_reserve.gd").enabled(actor):
		var limit:int=preload("res://scripts/units/tesla_reserve.gd").rule(actor).limit
		result.append({"label":"蓄电","count":clampi(int(actor.special.get("tesla_reserve_stacks",0)),0,limit),"limit":limit})
	if actor.unit_id=="DESO" and actor._deployed and Unit.YRTalents.enabled(actor,"deso_expansion"):
		result.append({"label":"扩散","count":clampi(int(actor.special.get("rad_growth_stacks",0)),0,preload("res://scripts/units/radiation_growth.gd").LIMIT),"limit":preload("res://scripts/units/radiation_growth.gd").LIMIT})
	if actor.unit_id=="R3REAPER":
		var rule:=BattleRequest.talent_upgrade("R3REAPER","reaper_fire_control",actor.side)
		if not rule.is_empty():
			var limit:=ceili(float(rule.linger)/float(rule.charge_seconds))
			result.append({"label":"主热","count":mini(limit,heat_count(actor,actor.attack_target)),"limit":limit})
			var secondary=actor.special.get("split_enemy")
			if is_instance_valid(secondary) and secondary!=actor.attack_target:
				result.append({"label":"副热","count":mini(limit,heat_count(actor,secondary)),"limit":limit})
	if actor.passive.get("id","")=="ps_phase":
		var target=actor.special.get("phase_target")
		var valid:=is_instance_valid(target) and AlliedAbilities.alive(target) and is_same(target,actor.attack_target)
		var count:=clampi(floori((float(actor.special.get("phase_time",0))+0.00001)/P.number("mechanic/faction","phase_interval")),0,P.count("mechanic/faction","phase_cap")) if valid else 0
		result.append({"label":"稳流","count":count,"limit":P.count("mechanic/faction","phase_cap")})
	return result

static func paint(ci:CanvasItem,center:Vector2,label:String,count:int,limit:int,radius:=22.0) -> void:
	if limit<=0:return
	count=clampi(count,0,limit)
	# Four current layers; cap geometry independently if future rules add more.
	var segments:=mini(limit,8)
	for i in segments:
		var color:=layer_color(i) if i<count else DIM
		var points:=PackedVector2Array()
		for j in 9:
			var angle:float=-PI+TAU*(float(i)+0.08+float(j)*0.105)/segments
			points.append(center+Vector2(cos(angle)*radius,sin(angle)*radius*0.38))
		if i<count:ci.draw_polyline(points,Color(color,0.16),7,true)
		ci.draw_polyline(points,Color(color,0.95 if i<count else 0.45),2,true)
	var color:=layer_color(count-1) if count>0 else DIM
	var text:="%s %d/%d"%[label,count,limit]
	var point:=center+Vector2(-42,radius*0.38+12)
	ci.draw_string_outline(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_CENTER,84,11,3,Color("#071018"))
	ci.draw_string(ThemeDB.fallback_font,point,text,HORIZONTAL_ALIGNMENT_CENTER,84,11,color)

static func draw_unit(actor) -> void:
	if actor.get_meta("stack_preview",false):return
	if actor.unit_id not in ["SHK","DESO","R3REAPER"] and actor.passive.get("id","")!="ps_phase":return
	var entries:=rows(actor)
	for i in entries.size():
		var row:Dictionary=entries[i]
		paint(actor,Vector2(0,i*23),row.label,row.count,row.limit,clampf(actor.radius+5,19,34))
