extends Node2D
## Optional objectives live in allied_state so checkpoint reloads cannot award twice.
const SchoolField=preload("res://scripts/expedition/yuriko_field.gd")
const Stories=preload("res://scripts/expedition/contact_stories.gd")
signal contact_met(id: String)
signal transmission(speaker:String, message:String, contact_id:String)
var support_ids:Dictionary={}
var world
var data:Dictionary={}
var focus_index:=0
var story_retry:=0.0
const Missions=preload("res://scripts/expedition/field_missions.gd")
var missions:=Missions.new()
const POINT_GAP:=560.0
const BASE_GAP:=650.0
const BUILDING_GAP:=220.0

static func support_stage(stage:int) -> int:
	var target:=maxi(6,stage+2)
	if target%5==0:target+=1
	return target if target<=25 else 0

static func contract(stage:int,seed_value:int,history:Array=[]) -> Dictionary:
	var arrival:=available_arrival(stage,history)
	var id:=Stories.select_contact(stage,seed_value,history,MetaProgress.contact_archive)
	var profile:Dictionary=Stories.PEOPLE[id]
	return {"id":id,"name":profile.name,"country":profile.country,"bio":profile.bio,"promise":profile.promise,
		"stage":arrival}

static func available_arrival(stage:int,history:Array) -> int:
	var booked:={}
	for prior:Dictionary in history:
		booked[int(prior.stage)]=true
	var arrival:=support_stage(stage)
	while arrival>0 and booked.has(arrival):
		arrival+=1
		if arrival%5==0:arrival+=1
		if arrival>25:arrival=0
	return arrival

static func allies_for(run:Dictionary,stage:int) -> Array:
	var result:Array=[]
	for person:Dictionary in run.get("field_contacts",[]):
		if int(person.get("stage",0))==stage and stage<=25:result.append(person)
	return result.slice(0,1)

func setup(battle,restored:bool) -> void:
	world=battle
	missions.world=world
	z_index=DepthLayers.ORDER_PREVIEW
	if restored and world.allied_state.has("expedition_field_ops"):
		data=world.allied_state.expedition_field_ops
	else:
		data={"objectives":[],"supplies":0,"contacts":[]}
		world.allied_state.expedition_field_ops=data
		var stage:=int(Expedition.state.stage)
		var home:Vector2=world.player_start()
		var enemy:Vector2=world.enemy_base_center
		var direction:Vector2=(enemy-home).normalized().orthogonal()
		var person:=contract(stage,int(Expedition.state.seed),Expedition.state.get("field_contacts",[]))
		var cycle:=int(Expedition.state.get("cycle",1))
		var route:Dictionary=Expedition.state.route
		var seed_value:=int(Expedition.state.seed)
		var field_kind:=Missions.candidate(seed_value,stage,route,cycle)
		var bridge:bool=route.get("bridge_support",false)
		if bridge:missions.deploy_bridge(data)
		for index:int in Missions.Assign.slots(int(person.stage)):
			var rescue:bool=index==0 and int(person.stage)>0
			var candidate:Vector2=home.lerp(enemy,0.42+0.15*index)+direction*(420.0 if index==0 else -420.0)
			if rescue:candidate=home.lerp(enemy,0.28)+direction*420.0
			var occupied:=occupied_points()
			var point:=find_site(candidate,occupied,rescue)
			if rescue and not point.is_finite():point=find_site(home,occupied,true)
			if not point.is_finite():continue
			var kind:="contact" if rescue else "cache" if stage%2==0 else "intel"
			var objective:Dictionary={"id":"field%d"%index,"kind":kind,"position":point,"progress":0.0,"done":false,"failed":false,"person":person.duplicate(true),"reward":50 if kind=="cache" else 35}
			if index==1:
				var mission:=objective.duplicate(true)
				if missions.prepare(self,mission,field_kind,seed_value):
					data.objectives.append(mission);continue
			if kind=="contact":
				var npc_id:="CIV1" if GameData.unit_index.has("CIV1") else "ENGINEER"
				var npc=world.spawn_unit(npc_id,"ally",point)
				if npc==null:continue
				npc.special.expedition_mission_unit=true;npc.special.expedition_contact=objective.id
				npc.special.expedition_objective_name=person.name
				npc.order_stop();npc.hold_position=true;npc.fire_stance="none"
				objective.has_npc=true
			data.objectives.append(objective)
	if not restored:
		preload("res://scripts/expedition/hero_field_stories.gd").assign(Expedition.state, data.objectives)
		SchoolField.setup(self,Expedition.state)
		deploy_support_squads()
	else:
		SchoolField.setup(self,Expedition.state,true)
	repair_overlapping_sites()
	SchoolField.prepare_finds(self,Expedition.state)
	repair_npc_sides(world)
	for objective:Dictionary in data.objectives:
		if restored and objective.kind=="fuel" and objective.get("phase","")=="station" and objective.has("outpost") and missions.powered_outpost(objective):
			missions.arm_outpost(missions.outpost(objective))
		if objective.kind=="contact":
			var person:Dictionary=objective.person
			if Stories.remember(MetaProgress.contact_transcripts,person.id,Stories.mission_text(person)):
				MetaProgress.save()
		if objective.kind=="box" and not objective.done and not objective.failed:
			var crate:=preload("res://scripts/expedition/field_crate.gd").new()
			crate.setup(missions,objective)
			add_child(crate)
	queue_redraw()

func occupied_points() -> Array:
	var points:Array=[]
	for objective:Dictionary in data.get("objectives",[]):points.append(objective.position)
	return points

func valid_site(point:Vector2,occupied:Array) -> bool:
	if not point.is_finite() or point.distance_to(world.player_start())<BASE_GAP:return false
	var origin:Vector2=world.allied_state.get("expedition_task",{}).get("origin",world.player_start())
	if not world.path_service.same_zone(origin,point):return false
	for other:Vector2 in occupied:
		if point.distance_to(other)<POINT_GAP:return false
	for other:Vector2 in world.allied_state.get("expedition_task",{}).get("points",[]):
		if point.distance_to(other)<POINT_GAP:return false
	for building in world.buildings:
		if world.actor_alive(building) and point.distance_to(building.position)<BUILDING_GAP+float(building.data.get("radius",0)):return false
	return true

func safe_rescue_spawn(point:Vector2) -> bool:
	for building in world.buildings:
		if not world.actor_alive(building) or not BattleRequest.is_house(building.side) or BattleRequest.friendly("ally",building.side):continue
		var clear_distance:=maxf(1300.0 if building.is_hq else BASE_GAP,float(building.attack_range)+BUILDING_GAP)
		if point.distance_squared_to(building.position)<clear_distance*clear_distance:return false
	for unit in world.units:
		if not world.actor_alive(unit) or not BattleRequest.is_house(unit.side) or BattleRequest.friendly("ally",unit.side):continue
		var clear_distance:=maxf(BASE_GAP,maxf(float(unit.sight),float(unit.attack_range))+BUILDING_GAP)
		if point.distance_squared_to(unit.position)<clear_distance*clear_distance:return false
	return true

func find_site(preferred:Vector2,occupied:Array,rescue_spawn:=false) -> Vector2:
	var home:Vector2=world.allied_state.get("expedition_task",{}).get("origin",world.player_start())
	# A short snap can return home on failure; valid_site explicitly rejects it.
	for ring in 9:
		for step in (1 if ring==0 else 24):
			var candidate:=preferred+Vector2.RIGHT.rotated(TAU*float(step)/24.0)*float(ring)*180.0
			var point:Vector2=world.path_service.nearest_reachable(candidate,home,false,4)
			if point.distance_to(candidate)>180.0:continue
			if valid_site(point,occupied) and (not rescue_spawn or safe_rescue_spawn(point)):return point
	return Vector2.INF

func repair_overlapping_sites() -> void:
	var occupied:Array=[]
	for objective:Dictionary in data.get("objectives",[]):
		if objective.kind=="bridge":
			occupied.append(objective.position);continue
		if objective.done or objective.get("failed",false):
			occupied.append(objective.position);continue
		if not valid_site(objective.position,occupied):
			var replacement:=find_site(objective.position,occupied)
			if replacement.is_finite():
				objective.position=replacement
				for unit in world.units:
					if world.actor_alive(unit) and unit.special.get("expedition_contact","")==objective.id:
						unit.global_position=replacement;unit.order_stop();unit.reset_physics_interpolation()
		occupied.append(objective.position)

static func repair_npc_sides(battle) -> void:
	for unit in battle.units:
		if not battle.actor_alive(unit):continue
		if unit.special.has("field_tanker") or unit.special.has("field_engineer"):continue
		if not unit.special.has("expedition_contact") and not unit.special.get("expedition_mission_unit",false):continue
		if not BattleRequest.friendly("ally",unit.side):AlliedAbilities.change_side(unit,"ally")

func tick(seconds:float) -> void:
	if data.is_empty() or world.ended:return
	SchoolField.tick(self)
	if data.has("story_followups"):tick_story_followups(seconds)
	if story_retry>0.0:
		story_retry=maxf(0.0,story_retry-seconds)
		if story_retry==0.0:greet_from_support()
	for objective:Dictionary in data.objectives:
		if Missions.NAMES.has(objective.kind):
			missions.tick(objective,data,seconds);continue
		if objective.done or objective.get("failed",false):continue
		if objective.get("has_npc",false) and not world.units.any(func(unit):return world.actor_alive(unit) and unit.special.get("expedition_contact","")==objective.id):
			objective.failed=true
			Events.emit_message("救援失败："+str(objective.person.name)+" 已阵亡，约定支援取消",UiKit.COL_SIDE_MISSION)
			continue
		var crew:=0;var contested:=false
		for unit in world.units:
			if not world.actor_alive(unit) or unit.embarked_in!=null or unit.is_air or unit.special.has("expedition_mission_unit") or unit.special.has("expansion_temporary"):continue
			if unit.position.distance_squared_to(objective.position)>180.0*180.0:continue
			if BattleRequest.friendly("ally",unit.side):crew+=1
			elif BattleRequest.is_house(unit.side) and not BattleRequest.friendly("ally",unit.side):contested=true
		objective.control_hint="敌军争夺 · 清敌后继续" if contested else "保持控制" if crew>0 else "派地面部队入圈"
		if crew>0 and not contested:objective.progress=minf(20.0,float(objective.progress)+seconds*preload("res://scripts/expedition/relics.gd").progress_rate(crew))
		if float(objective.progress)>=20.0:complete(objective)
	if not data.get("tracked","").is_empty():
		for objective:Dictionary in data.objectives:
			if objective.id==data.tracked and (objective.done or objective.get("failed",false)):
				data.erase("tracked");break
	queue_redraw()

func complete(objective:Dictionary) -> void:
	if objective.done or objective.get("failed",false) or Missions.NAMES.has(objective.kind):return
	objective.done=true
	if objective.kind=="contact":
		for unit in world.units:
			if world.actor_alive(unit) and unit.special.get("expedition_contact","")==objective.id:
				unit.special.erase("expedition_contact");unit._dead=true;unit.hp=0;unit.hide();unit.queue_free()
	data.supplies=int(data.supplies)+int(objective.reward)
	if objective.kind in ["contact","cache"]:
		data.kits=int(data.get("kits",0))+1
	if objective.kind=="contact":
		data.contacts.append(objective.person.duplicate(true))
		var person:Dictionary=objective.person
		var line:=Stories.rescue_line(person)
		var changed:=Stories.remember(MetaProgress.contact_transcripts,person.id,{"rescue":line})
		var entry:Dictionary=MetaProgress.contact_transcripts.get_or_add(person.id,{})
		if changed or not entry.get("rescued",false):
			entry.rescued=true
			MetaProgress.save()
		transmission.emit(person.name,line,person.id)
		meet_contact(person.id)
		Events.emit_message("救援成功：%s。胜利后带回 1 个维修包，第 %d 关带队支援。"%[objective.person.name,objective.person.stage],UiKit.COL_SIDE_MISSION)
	elif objective.kind=="intel":
		if is_instance_valid(world.fog):world.fog._reveal("ally",world.enemy_base_center,800.0,world.fog.EXPEDITION_INTEL_SIGHT_SECONDS)
		Events.emit_message("截获战场情报 · 标记敌军主基地 · 胜利额外 +%d 补给"%objective.reward,UiKit.COL_SIDE_MISSION)
	else:Events.emit_message("军需物资已回收 · 胜利后 +%d 补给、1 个维修包"%objective.reward,UiKit.COL_SIDE_MISSION)

func deploy_support_squads() -> void:
	var seats: Array = BattleRequest.skirmish_config.get("houses", [])
	var contacts: Array = BattleRequest.combat_context.expedition.get("support_contacts", [])
	for i in contacts.size():
		var side := BattleRequest.Houses.id(seats.size() - contacts.size() + i)
		if not world.house_controllers.has(side) or not BattleRequest.friendly("ally", side): continue
		var squad: Array = Stories.PEOPLE.get(contacts[i].id, {}).get("opening_squad", [])
		if squad.is_empty(): continue
		var center: Vector2 = world.house_controllers[side].base_center
		var origin: Vector2 = world.path_service.ground_near_base(center)
		if not origin.is_finite(): continue
		var deployed := 0
		for slot in 72:
			var offset := Vector2.RIGHT.rotated(TAU * (slot % 12) / 12.0) * (300.0 + 80.0 * floori(slot / 12.0))
			var target := center + offset
			if not Rect2(Vector2.ZERO, Vector2.ONE * world.map_size).has_point(target): continue
			var pos: Vector2 = world.path_service.nearest_reachable(target, origin, false, 8)
			var id: String = squad[deployed]
			var radius := float(GameData.get_unit(id).get("radius", 20))
			if not pos.is_finite() or not preload("res://scripts/world/economy_cycle.gd").landing_clear(world, pos, radius): continue
			var unit = world.spawn_unit(id, side, pos)
			if unit == null: break
			unit.order_guard()
			deployed += 1
			if deployed == squad.size(): break

func greet_from_support() -> void:
	var seats:Array=BattleRequest.skirmish_config.get("houses",[])
	var contacts:Array=BattleRequest.combat_context.get("expedition",{}).get("support_contacts",[])
	for i in contacts.size():
		var index:=seats.size()-contacts.size()+i
		var side:=BattleRequest.Houses.id(index)
		if index<1 or not BattleRequest.friendly("ally",side) or not world.house_controllers.has(side):continue
		var person:Dictionary=contacts[i]
		seats[index].commander=person.name
		support_ids[side]=person.id
		world.ai_decisions(side).preferred_recruit=Stories.PEOPLE.get(person.id,{}).get("unit","")
		var greeted:Dictionary=data.get_or_add("greeted",{})
		if greeted.has(side) or world.house_defeated(side):continue
		var context:Dictionary=BattleRequest.combat_context.expedition
		var run_id:=str(context.get("id",""))
		var stage:=int(context.get("stage",0))
		var chapter:=Stories.available_chapter(person.id,run_id,stage,MetaProgress.contact_archive)
		if chapter.is_empty():
			greeted[side]=true
			var arrival:String=Stories.PEOPLE.get(person.id,{}).get("arrival",person.get("promise","友军已到达。"))
			if Stories.remember(MetaProgress.contact_transcripts,person.id,{"arrival":arrival}):MetaProgress.save()
			transmission.emit(person.name,arrival,person.id)
			meet_contact(person.id)
			continue
		var original:=MetaProgress.contact_archive
		MetaProgress.contact_archive=original.duplicate(true)
		var story:Dictionary=Stories.PEOPLE[person.id].chapters[chapter]
		MetaProgress.contact_archive.get_or_add(person.id,{})[chapter]={"run":run_id,"stage":stage,"title":story.title,"lines":story.lines.duplicate()}
		if not MetaProgress.save():
			MetaProgress.contact_archive=original
			story_retry=15.0
			continue
		greeted[side]=true
		var lines:Array=Stories.PEOPLE[person.id].chapters[chapter].lines
		transmission.emit(person.name,lines[0],person.id)
		meet_contact(person.id)
		if lines.size()>1:
			data.get_or_add("story_followups",{})[side]={"name":person.name,"lines":lines.slice(1),"delay":18.0}

func meet_contact(id: String) -> void:
	var met: Array = data.get_or_add("met_contacts", [])
	if id not in met:
		met.append(id)
		contact_met.emit(id)

func tick_story_followups(seconds:float) -> void:
	var pending:Dictionary=data.story_followups
	for side:String in pending.keys():
		if world.house_defeated(side):
			pending.erase(side)
			continue
		var entry:Dictionary=pending[side]
		entry.delay-=seconds
		if entry.delay>0.0:continue
		transmission.emit(entry.name,entry.lines.pop_front(),support_ids.get(side,""))
		if entry.lines.is_empty():pending.erase(side)
		else:entry.delay=18.0
	if pending.is_empty():data.erase("story_followups")

func title(objective:Dictionary) -> String:
	var label_:String=Missions.NAMES.get(objective.kind,Missions.BASIC_NAMES.get(objective.kind,str(objective.kind)))
	if objective.kind=="contact":label_="救援："+str(objective.person.name)
	return label_+" · 附带遗物" if objective.has("school_gift") else label_

func compact_summary() -> String:
	var lines:PackedStringArray=[]
	if data.has("shelter_at"):lines.append(SchoolField.SHELTER + (" · 已听到饭盒声，本场获胜后带回第一章" if data.get("shelter_heard",false) else " · 派部队前往粉色标记"))
	if data.has("archive_at"):lines.append(SchoolField.ARCHIVE+(" · 已拾取" if data.get("archive_taken",false) else " · 由百合子拾取"))
	for objective:Dictionary in data.get("objectives",[]):
		if not data.get("tracked","").is_empty() and data.tracked!=objective.id:continue
		if objective.has("school_gift"):lines.append("战利品 · "+SchoolField.Bonds.loot_text(objective))
		if objective.has("hero_lead"):
			lines.append("英雄线索 · " + str(preload("res://scripts/expedition/hero_field_stories.gd").name_of(objective.hero_lead)))
		if objective.has("hero_chronicle"):
			lines.append("同行委托 · "+str(preload("res://scripts/expedition/hero_field_stories.gd").chapter_for(objective.hero_chronicle).title))
		if Missions.NAMES.has(objective.kind):
			lines.append("支线 · %s：%s"%[Missions.NAMES[objective.kind],missions.hint(objective)]);continue
		var name:String="救援" if objective.kind=="contact" else "军需" if objective.kind=="cache" else "情报"
		var progress:String="失败" if objective.get("failed",false) else "完成" if objective.done else "%d / 20 秒"%int(objective.progress)
		var person_name:String=str(objective.person.name).get_slice(" · ",0)+" · " if objective.kind=="contact" else ""
		lines.append("支线 · %s%s：%s"%[person_name,name,progress])
	return "\n".join(lines) if not lines.is_empty() else "支线：暂无"

func summary() -> String:
	var text:PackedStringArray=[]
	if data.has("shelter_at"):text.append(SchoolField.SHELTER+" · 派部队靠近雨棚，听到饭盒声后获胜。")
	if data.has("archive_at"):text.append(SchoolField.ARCHIVE+" · "+("已收好，胜利后带回" if data.get("archive_taken",false) else "派百合子接近粉色档案"))
	for objective:Dictionary in data.get("objectives",[]):
		if objective.has("school_gift"):text.append("普通小队完成本项并获胜可带回："+SchoolField.Bonds.loot_text(objective))
		if objective.has("hero_chronicle"):
			text.append("同行委托 · "+preload("res://scripts/expedition/hero_field_stories.gd").chapter_hint(objective.hero_chronicle))
		if objective.has("hero_lead"):
			var lead: Dictionary = preload("res://scripts/expedition/hero_field_stories.gd").BOOK[objective.hero_lead]
			text.append(str(lead.clue) + " 完成委托并获胜后加入本轮远征。")
		if Missions.NAMES.has(objective.kind):
			text.append("%s %s · %s"%["✓" if objective.done else "✗" if objective.failed else "○",Missions.NAMES[objective.kind],missions.hint(objective)]);continue
		var failed:bool=objective.get("failed",false)
		var mark:="✗" if failed else "✓" if objective.done else "○"
		text.append("%s %s"%[mark,title(objective)])
		if failed:
			text.append("任务失败，无法领取补给")
		else:
			var progress:="已完成" if objective.done else "进度 %d/20 秒"%int(objective.progress)
			var kit := "、1 个维修包" if objective.kind in ["cache","contact"] else ""
			text.append("%s · 胜利后获得 %d 补给%s"%[progress,objective.reward,kit])
		if objective.kind=="contact":
			if failed:
				text.append("支援已取消")
			else:
				text.append("第%d关赴约"%objective.person.stage)
				text.append(str(objective.person.promise))
	return "\n".join(text)

func track(id:String) -> void:
	data.tracked=id if data.get("tracked","")!=id else ""
	queue_redraw()

func next_marker(o:Dictionary,marks:Array) -> Dictionary:
	var suffix:=""
	match o.kind:
		"radio":suffix=str(o.real) if o.listened or o.ambushed else "_listen"
		"box":suffix="_depot" if o.phase=="carry" else ""
		"fuel":suffix="_station" if o.phase=="drive" else ""
		"divert":suffix="_end" if o.phase=="withdraw" else "_relay"
		"relay_pair":suffix="_second" if o.get("relay_a",false) and not o.get("relay_b",false) else ""
	for m:Dictionary in marks:
		if m.key==str(o.id)+suffix:return m
	return marks.front()

func markers() -> Array:
	var result:Array=[]
	for kind:String in data.get("school_finds",{}):
		var item:Dictionary=data.school_finds[kind]
		result.append({"key":"school_"+kind,"position":item.position,"title":"百合子支线 · "+SchoolField.FINDS[kind],"color":SchoolField.PINK,"optional":true,"preferred":true,"status":"done" if item.taken else "active"})
	if data.has("shelter_at"):
		result.append({"key":"school_shelter","position":data.shelter_at,"title":SchoolField.SHELTER,"color":SchoolField.PINK,"optional":true,"preferred":true,"status":"done" if data.get("shelter_heard",false) else "active"})
	if data.has("archive_at"):
		var archive:=SchoolField.marker(data)
		archive.tracked=data.get("tracked","")==archive.key
		result.append(archive)
	for objective:Dictionary in data.get("objectives",[]):
		var marks:Array=missions.marks(objective) if Missions.NAMES.has(objective.kind) else [{"key":objective.id,"position":objective.position,"title":title(objective),"optional":true,
			"status":"locked" if objective.get("failed",false) else "done" if objective.done else "active"}]
		if objective.kind=="contact" and not objective.done and not objective.get("failed",false):
			marks[0].contact_id=objective.person.id
		if not objective.done and not objective.get("failed",false):
			var next:=next_marker(objective,marks);next.preferred=true
			if objective.id==data.get("tracked",""):next.tracked=true
		if objective.get("hero_lead","")=="YURIKO":
			for mark:Dictionary in marks:mark.color=SchoolField.PINK
		result.append_array(marks)
	return result

func focus_next() -> void:
	var pending:Array=[]
	for mark:Dictionary in markers():
		if mark.get("tracked",false):world.center_on(mark.position);return
		if mark.status=="active" and mark.get("preferred",false):pending.append(mark)
	if pending.is_empty():return
	world.center_on(pending[focus_index%pending.size()].position)
	focus_index+=1

func actions() -> Array:
	for o:Dictionary in data.get("objectives",[]):
		if Missions.NAMES.has(o.kind):return missions.actions(o)
	return []

func act(action:String) -> void:
	if world.ended or world.paused:return
	for o:Dictionary in data.get("objectives",[]):
		if action in missions.actions(o):
			missions.act(o,data,action);queue_redraw();return

func carrier_died(unit) -> void:
	for o:Dictionary in data.get("objectives",[]):
		if o.kind=="box" and o.phase=="carry" and unit.special.get("field_box","")==o.id:
			missions.drop_box(o,unit);return

func countdown_text(objective:Dictionary) -> String:
	var seconds:=clampf(float(objective.get("progress",0.0)),0.0,20.0)
	return "剩余 %d 秒 · %d%%"%[ceili(20.0-seconds),floori(seconds*5.0)]

func support_bases() -> Array[Dictionary]:
	var bases:Array[Dictionary]=[]
	for side:String in support_ids:
		var id:String=support_ids[side]
		if world.house_defeated(side) or not Stories.PEOPLE.has(id):continue
		for building in world._buildings_for_side(side):
			if not world.actor_alive(building) or not building.is_hq:continue
			var profile:Dictionary=Stories.PEOPLE[id]
			bases.append({"position":building.global_position,"contact_id":id,
				"title":"%s · %s"%[profile.base,str(profile.name).get_slice(" · ",0)]})
			break
	return bases

func _draw() -> void:
	if not is_instance_valid(world):return
	SchoolField.draw(self)
	for base:Dictionary in support_bases():
		var canvas:=get_global_transform_with_canvas()
		var anchor:Vector2=canvas*Vector2(base.position)+Vector2(0,-76)
		var font:=ThemeDB.fallback_font
		var width:=font.get_string_size(base.title,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_set_transform_matrix(canvas.affine_inverse())
		draw_rect(Rect2(anchor-Vector2(width/2+7,17),Vector2(width+14,24)),Color("#102029ed"))
		draw_string(font,anchor-Vector2(width/2,0),base.title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#9ce8d8"))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	for objective:Dictionary in data.get("objectives",[]):
		if Missions.NAMES.has(objective.kind):
			if (not objective.done and not objective.failed) or objective.get("phase","")=="station":
				for m:Dictionary in missions.marks(objective):
					var repair:bool=objective.kind=="fuel" and objective.get("phase","")=="station"
					var site=missions.outpost(objective) if repair and objective.has("outpost") else null
					if repair and objective.has("outpost") and (site==null or site.side!="ally"):continue
					draw_arc(m.position,Missions.REPAIR_RADIUS if repair else Missions.REACH,0,TAU,64,Color("91d9a9") if repair else Color(UiKit.COL_SIDE_MISSION,0.85),3)
					var transform_to_screen:=get_global_transform_with_canvas()
					draw_set_transform_matrix(transform_to_screen.affine_inverse())
					var anchor:Vector2=transform_to_screen*Vector2(m.position)+Vector2(0,-44)
					if site!=null:
						var top:=RA2Art.art_dir(Vector2(0,site.combat_sight_rect().position.y))
						anchor=transform_to_screen*(site.position+top)-Vector2(0,9)
						m.title="前哨站 · 维修范围"
					var ink:=Color("a3efc1") if m.get("staffed",false) else UiKit.COL_SIDE_MISSION
					var width:=ThemeDB.fallback_font.get_string_size(m.title,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
					draw_rect(Rect2(anchor-Vector2(width/2+6,18),Vector2(width+12,24)),Color("182728ed"))
					draw_string(ThemeDB.fallback_font,anchor-Vector2(width/2,0),m.title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,ink)
					if m.has("meter"):
						draw_rect(Rect2(anchor+Vector2(-width/2,3),Vector2(width,3)),Color("556563"))
						draw_rect(Rect2(anchor+Vector2(-width/2,3),Vector2(width*clampf(m.meter,0,1),3)),Color("a3efc1"))
					draw_set_transform_matrix(Transform2D.IDENTITY)
			continue
		if objective.done or objective.get("failed",false):continue
		draw_arc(objective.position,180,0,TAU,32,Color(UiKit.COL_SIDE_MISSION,0.8),3)
		var canvas:=get_global_transform_with_canvas()
		draw_set_transform_matrix(canvas.affine_inverse())
		var center:Vector2=canvas*Vector2(objective.position)
		var heading:=title(objective)+" · "+str(objective.get("control_hint","派地面部队入圈"))
		var heading_width:=ThemeDB.fallback_font.get_string_size(heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(ThemeDB.fallback_font,center+Vector2(-heading_width*0.5,-67),heading,HORIZONTAL_ALIGNMENT_LEFT,-1,16,UiKit.COL_SIDE_MISSION)
		var fraction:=clampf(float(objective.get("progress",0.0))/20.0,0.0,1.0)
		var origin:=center+Vector2(-90,-51)
		draw_rect(Rect2(origin-Vector2(2,2),Vector2(184,16)),Color(0.02,0.04,0.07,0.95))
		draw_rect(Rect2(origin,Vector2(180,12)),Color(0.12,0.22,0.25))
		draw_rect(Rect2(origin,Vector2(180*fraction,12)),UiKit.COL_SIDE_MISSION)
		var countdown:=countdown_text(objective)
		var countdown_width:=ThemeDB.fallback_font.get_string_size(countdown,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
		draw_string(ThemeDB.fallback_font,center+Vector2(-countdown_width*0.5,-18),countdown,HORIZONTAL_ALIGNMENT_LEFT,-1,16,UiKit.COL_SIDE_MISSION)
		draw_set_transform_matrix(Transform2D.IDENTITY)
