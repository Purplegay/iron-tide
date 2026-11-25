extends RefCounted
## Explicit battle-only test commands; never touch persistent progression.

static func target_ids() -> Array[String]:
	var ids:Array[String]=["E1","MTNK"]
	# Registered RA3 units use the R3 namespace; new imports need no GM list edit.
	var ra3:Array[String]=[]
	for id in GameData.unit_index:
		if str(id).begins_with("R3"):ra3.append(str(id))
	ra3.sort();ids.append_array(ra3)
	return ids

static func run(world, request: Dictionary) -> String:
	if not is_instance_valid(world) or world.ended:return "请先进入对局"
	match str(request.get("action", "")):
		"spawn":return spawn(world, request)
		"faction":
			var side := str(request.get("side","ally"))
			var roster := GameData.faction_unit_catalog(world.roster_faction(side))
			var missed := PackedStringArray()
			var options := request.duplicate()
			options.count = 1
			for id in roster:
				options.id = id
				if spawn_count(world, options, true) == 0: missed.append(str(GameData.get_unit(id).name))
			var result := "%s阵营已生成 %d/%d 种单位" % ["敌方" if side == "enemy" else "我方", roster.size()-missed.size(), roster.size()]
			if not missed.is_empty(): result += "；无合适地形或空间：" + "、".join(missed)
			return result
		"promote":
			var promoted := 0
			var eligible := 0
			for unit in world.selected_units:
				if not world.actor_alive(unit): continue
				eligible += 1
				if not unit.can_gain_veterancy(): continue
				var prior: int = unit.veteran_level
				unit._grant_veteran(prior + 1, false)
				if unit.veteran_level > prior:
					promoted += 1
					unit.queue_redraw()
			world._emit_selection()
			if eligible == 0: return "请先框选要升星的单位"
			return "已为 %d 个单位各升一级，跳过 %d 个满级或不可晋升单位" % [promoted, eligible-promoted]
		"targets":
			var total:=0
			for id in target_ids():
				total+=spawn_count(world,{"id":id,"count":1,"side":"enemy","stationary":true})
			return "已生成 %d 个靶标（步兵／灰熊／全部已接入 RA3 单位）；地面静止、飞机正常飞行、不还击；空间／地形不合适时少生成" % total
		"clear":
			var count:=0
			for unit in world.units.duplicate():
				if is_instance_valid(unit) and unit.special.get("gm_test_spawn",false):
					world.selected_units.erase(unit);world.units.erase(unit)
					for key in world.control_groups:world.control_groups[key].erase(unit)
					unit.queue_free();count+=1
			var refresh := false
			for b in world.buildings.duplicate():
				if is_instance_valid(b) and b.building_id=="R3REAPERTURRET" and b.special.get("gm_test_spawn",false):
					world.buildings.erase(b);b.queue_free();count+=1;refresh=true
			if refresh: world._refresh_pathing()
			world._emit_selection()
			return "已移除 %d 个 GM 生成单位" % count
		"health", "rank", "reset", "stop":
			var count:=0
			for unit in world.selected_units:
				if not is_instance_valid(unit) or unit.hp<=0:continue
				match str(request.action):
					"health":unit.hp=unit.max_hp*clampf(float(request.get("health",100)),1,100)/100.0
					"rank":unit._grant_veteran(clampi(int(request.get("rank",0)),0,3),false)
					"stop":unit.order_stop();unit.fire_stance="none"
					"reset":
						# Do not erase active casts or refund an in-flight salvo.
						if unit.special.has("ra3_riot_point") or unit.special.has("ra3_riot_approach"):continue
						unit._cd_timer=0.0
						for skill in unit.skills:skill.cd_left=0.0
						for key in unit.special.keys():
							if str(key).ends_with("_cd"):unit.special[key]=0.0
						unit.special.ra3_clip=0
						unit.special.erase("soviet_mounts")
						unit.special.erase("raising_missile_0")
						unit.special.erase("raising_missile_1")
						unit.special.erase("missile_racks")
						unit.special.erase("launcher_rof")
						if unit.unit_id==Ra3Expansion.HARBINGER:
							for mount in preload("res://scripts/units/ra3_gunship_mounts.gd").states(unit).values():
								mount.used=0;mount.remaining=0.0;mount.flash=0.0
						unit.logistics.ammo=unit.logistics.ammo_max
				count+=1;unit.queue_redraw()
			world._emit_selection()
			return "已应用到 %d 个选中单位（进行中的 Q 不重置）" % count if count>0 else "请先框选单位；进行中的 Q 请等待结束"
	return "未知单位测试命令"

static func spawn(world, request: Dictionary) -> String:
	var id:=str(request.get("id",""))
	if not GameData.unit_index.has(id) and id != "SUB":return "未知单位："+id
	var count:=spawn_count(world,request)
	return "已在当前视野生成 %d 个 %s；空间／地形不合适时少生成" % [count,str(GameData.get_unit(id).get("name",id))]

static func spawn_count(world, request: Dictionary, map_fallback := false) -> int:
	var id:=str(request.get("id",""))
	if not GameData.unit_index.has(id) and id != "SUB":return 0
	var data: Dictionary=GameData.get_unit(id)
	var tags: Array=data.get("tags",[])
	var air:=tags.has("air")
	var naval:=tags.has("naval") or str(data.get("role",""))=="naval"
	var amphibious:=str(data.get("movement_zone","")).to_lower()=="amphibious"
	var side: String="enemy" if request.get("side","ally")=="enemy" else "ally"
	var count:=0
	var play: Rect2=world.camera_play_rect()
	# Keep spawns left of the floating GM panel as well as the production deck.
	play.size.x=minf(play.size.x,world.get_viewport_rect().size.x-520.0)
	var inverse: Transform2D=world.get_canvas_transform().affine_inverse()
	var center:=inverse*play.get_center()
	var radius:=maxf(16.0,float(data.get("radius",20)))
	# Try the visible spiral first. A whole roster may need water or space off-screen.
	var cell := 64
	var columns := ceili(world.map_size / float(cell))
	var attempts := 600 + (columns * columns if map_fallback else 0)
	for attempt in attempts:
		if count>=clampi(int(request.get("count",1)),1,50):break
		var ring:=sqrt(float(attempt))*42.0
		var point:=center+Vector2.from_angle(attempt*2.39996323)*ring
		if attempt >= 600:
			var index := attempt - 600
			point = Vector2(index % columns + 0.5, floori(index / float(columns)) + 0.5) * cell
		if not Rect2(Vector2.ONE*radius,Vector2.ONE*(world.map_size-radius*2)).has_point(point):continue
		if attempt < 600 and not play.grow(-30).has_point(world.get_canvas_transform()*point):continue
		if not air and world.path_service.is_blocked(point,naval,amphibious):continue
		var blocked:=false
		for other in world.units:
			if not is_instance_valid(other) or other.hp<=0:continue
			var other_point: Vector2=other.position
			if air and other.is_air:other_point-=RA2Art.art_dir(Vector2(0,other._visual_lift()))
			if other_point.distance_to(point)<radius+other.radius+8:blocked=true;break
		if not air:
			for b in world.buildings:
				if is_instance_valid(b) and b.hp>0 and preload("res://scripts/units/ra3_riot.gd").point_distance(b,point)<radius+8:blocked=true;break
		if blocked:continue
		var unit=world.spawn_unit(id,side,point)
		if unit==null:continue
		if air:
			# The aircraft's body, not just its ground shadow, must be in view.
			unit.position+=RA2Art.art_dir(Vector2(0,unit._visual_lift()))
			if not Rect2(Vector2.ONE*radius,Vector2.ONE*(world.map_size-radius*2)).has_point(unit.position):
				world.units.erase(unit);unit.queue_free();continue
		unit.special.gm_test_spawn=true
		unit._grant_veteran(clampi(int(request.get("rank",0)),0,3),false)
		unit.hp=unit.max_hp*clampf(float(request.get("health",100)),1,100)/100.0
		if request.get("stationary",false):
			# Restrict behaviour, not the engine clock: flight and death still tick.
			unit.order_stop();unit.fire_stance="none";unit.special.gm_stationary=true
		count+=1
	return count
