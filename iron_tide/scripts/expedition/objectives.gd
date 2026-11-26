extends Node2D
const Campaign=preload("res://scripts/expedition/campaign.gd")
const Rules=preload("res://scripts/expedition/rules.gd")
const CONTROL_POINT_CAP:=60
const CAPTURE_FORCE_CAP := 8
const Relics = preload("res://scripts/expedition/relics.gd")

static func capture_rate(units:int, relic_level:int) -> float:
	return Relics.capture_rate(units,relic_level)

var world
var error:=""
var state:Dictionary
var focus_index:=0
var field_ops

func setup(battle,restored:bool) -> bool:
	world=battle
	z_index=DepthLayers.ORDER_PREVIEW
	if restored:
		state=world.allied_state.get("expedition_task",{})
		if state.is_empty():error="远征检查点缺少任务状态";return false
	else:
		state={"kind":Rules.context().task,"stage":Rules.context().stage,"elapsed":0.0,"progress":0.0,"phase":0,"outcome":0,"points":[],"targets":[],"arrived":[],"waves":0,"rescued":[],"next_wave":45.0,"relocate":30.0}
		world.allied_state.expedition_task=state
		if not prepare():return false
	if state.kind=="defend" and not state.has("relay_work"):
		state.relay_work=[0.0,0.0]
		if restored:state.progress=minf(360.0,float(state.progress)*2.0)
		separate_control_points()
	if state.kind=="control":
		separate_control_points()
	if state.kind=="control" and not state.has("control_scores"):
		# Older checkpoints only recorded the total. Credit it in marker order.
		var remaining:=float(state.progress)
		state.control_scores=[]
		state.progress=0.0
		for i in state.points.size():
			var credit:=clampf(remaining,0.0,CONTROL_POINT_CAP)
			state.control_scores.append(credit)
			state.progress+=credit
			remaining-=credit
	if state.kind=="research" and not state.has("labs"):
		var previous:=clampf(float(state.get("progress",0.0)),0.0,90.0)
		state.labs=[minf(45.0,previous),maxf(0.0,previous-45.0)]
		state.lab_awarded=[previous>=45.0,previous>=90.0]
	if state.kind=="escort":
		for n in 3:
			var truck=actor("convoy"+str(n))
			if truck!=null:apply_convoy_order(truck)
	if restored and state.kind=="boss" and int(state.stage)==20 and not state.has("command_post"):
		var command=actor("command")
		if command!=null:
			command.order_stop()
			command.hold_position=true
			relocate_command(command)
	queue_redraw()
	return true

func set_convoy_paused(paused:bool) -> bool:
	if state.kind!="escort" or int(state.outcome)!=0 or world.ended:return false
	state.convoy_paused=paused
	for n in 3:
		if n in state.arrived:continue
		var truck=actor("convoy"+str(n))
		if truck!=null:apply_convoy_order(truck)
	return true

func apply_convoy_order(truck) -> void:
	var paused:bool=state.get("convoy_paused",false)
	truck.special.expedition_convoy=true
	truck.special.expedition_convoy_paused=paused
	truck._recompute_bonuses()
	if paused:
		truck.order_stop();truck.hold_position=true;truck._spd_cur=0.0
	else:truck.order_move(state.points[2],false)

func ground(target:Vector2) -> Vector2:
	var origin:Vector2=state.get("origin",world.player_start())
	return world.path_service.nearest_reachable(target,origin,false,120)

# Keep the first marker in place, including when resuming a crowded old layout.
func separate_control_points() -> void:
	var path = world.path_service
	var kept: Array[Vector2] = []
	for i in state.points.size():
		var original: Vector2 = state.points[i]
		if not clear_of_points(original, kept):
			var nearest := INF
			var zone: int = path.zone_at(original)
			for y in path.rows:
				for x in path.cols:
					var candidate := Vector2(x + 0.5, y + 0.5) * float(path.cell)
					var distance := candidate.distance_squared_to(original)
					if distance < nearest and clear_of_points(candidate, kept) and zone > 0 and path.zone_at(candidate) == zone:
						nearest = distance
						state.points[i] = candidate
		kept.append(state.points[i])

func clear_of_points(point: Vector2, others: Array[Vector2]) -> bool:
	for other in others:
		if point.distance_squared_to(other) < 480.0 * 480.0:
			return false
	return true

func mark(actor,key:String,title:String) -> void:
	actor.special.expedition_objective=key
	actor.special.expedition_objective_name=title
	state.targets.append(key)

func actor(key:String):
	for unit in world.units+world.buildings:
		if world.actor_alive(unit) and unit.special.get("expedition_objective","")==key:
			if key=="defense" and unit.side!="ally":continue
			if key in ["command","node0","node1","radar","supply0","supply1"] and (not BattleRequest.is_ai_house(unit.side) or BattleRequest.friendly("ally",unit.side)):continue
			return unit
	return null

func remaining_enemy_buildings(owners: Dictionary = {}) -> int:
	var count:=0
	for building in world.buildings:
		if world.actor_alive(building) and BattleRequest.is_ai_house(building.side) and not BattleRequest.friendly("ally",building.side):
			owners[building.side] = true
			count+=1
	return count

func prepare() -> bool:
	var home:Vector2=world.player_start()
	var enemy:Vector2=world.enemy_base_center
	var origin:=Vector2.INF
	for unit in world.units:
		if world.actor_alive(unit) and unit.side=="ally" and not unit.is_air and not unit.is_naval and world.path_service.zone_at(unit.position)>0:
			origin=unit.position;break
	if not origin.is_finite():
		origin=world.path_service.ground_near_base(home)
		if not origin.is_finite():
			error="基地附近找不到可通行的地面，无法设置任务点"
			return false
	state.origin=origin
	for fraction in [0.35,0.50,0.65]:
		var point:=ground(home.lerp(enemy,fraction))
		if not point.is_finite() or not world.path_service.same_zone(origin,point):error="地图缺少可达的任务区域";return false
		state.points.append(point)
	var kind:String=state.kind
	if kind=="annihilate":
		state.remaining=remaining_enemy_buildings()
		if state.remaining==0:error="敌军基地缺少建筑";return false
	if kind in ["supply","radar","assault","boss"]:
		var targets:Array=[]
		for building in world.buildings:
			if world.actor_alive(building) and BattleRequest.is_ai_house(building.side) and not BattleRequest.friendly("ally",building.side) and not building.data.get("tags",[]).has("defense") and not building.data.get("tags",[]).has("wall"):targets.append(building)
		targets.sort_custom(target_before)
		if targets.size()<3:error="敌军基地缺少任务设施";return false
		var headquarters=targets[-1]
		state.primary_enemy=str(headquarters.side)
		for building in targets:
			if building.is_hq:headquarters=building;break
		targets.erase(headquarters);targets.append(headquarters)
		if kind=="assault":mark(headquarters,"command","敌军指挥部")
		elif kind=="radar":
			var radar=radar_target()
			if radar==null:error="地图无法安置任务雷达";return false
			mark(radar,"radar","前线雷达")
		elif kind=="supply":
			mark(targets[0],"supply0","补给设施 A");mark(targets[1],"supply1","补给设施 B")
		else:
			mark(targets[0],"node0","供能节点 A");mark(targets[1],"node1","供能节点 B")
			if int(state.stage)==20:
				var at:=ground(enemy)
				if not at.is_finite():error="指挥车缺少可达位置";return false
				var command=world.spawn_unit("HTNK","enemy",at)
				command.max_hp*=4.0;command.hp=command.max_hp
				mark(command,"command","机动指挥车")
				state.command_post=at
				command.order_stop()
				command.hold_position=true
			else:mark(targets[-1],"command","核心指挥部")
			var command=actor("command")
			command.special.expedition_protected=true
	if kind=="defend":
		for building in world.buildings:
			if world.actor_alive(building) and building.side=="ally" and building.building_id in ["GACNST","NACNST"]:
				mark(building,"defense","防线指挥所");break
		if actor("defense")==null:error="没有可保护的防线";return false
	if kind=="escort":
		# New missions travel deeper into the battle; restored checkpoints retain their authored endpoint.
		var destination:=ground(home.lerp(enemy,0.90))
		if not destination.is_finite() or not world.path_service.same_zone(origin,destination):error="地图缺少可达的护送终点";return false
		state.points[2]=destination
		state.escort_next_raid=preload("res://scripts/expedition/escort_raids.gd").FIRST_WARNING_AT
		state.next_wave=95.0
		state.escort_raids=0
		for n in 3:
			var at:=ground(home+Vector2(220,n*90-90))
			var truck=world.spawn_unit("HTK","ally",at)
			truck.special.expedition_mission_unit=true
			truck.max_hp*=2.0;truck.hp=truck.max_hp
			mark(truck,"convoy"+str(n),"任务车队 "+str(n+1))
			truck.order_move(state.points[2],false)
	return true

func radar_target():
	var id:String="NARADR" if world.roster_faction("enemy")=="soviet" else "GAAIRC"
	for building in world.buildings:
		if world.actor_alive(building) and BattleRequest.is_ai_house(building.side) and not BattleRequest.friendly("ally",building.side) and building.building_id==id:return building
	var owner:=str(state.get("primary_enemy","enemy"))
	var definition:=GameData.get_building(id)
	for ring in range(3,16):
		for index in ring*8:
			var point:Vector2=world.snap_build_pos(world.enemy_base_center+Vector2.RIGHT.rotated(TAU*index/(ring*8))*ring*100)
			if world.build_spot_ok(point,definition,true,owner,world).ok:
				var building=world._place_building(id,owner,point,true)
				building._buildup_play=-1
				return building
	return null

func target_before(a,b) -> bool:
	return a.position.distance_squared_to(world.player_start())<b.position.distance_squared_to(world.player_start())

func uncontested_rate(point:Vector2) -> float:
	var counts:=point_counts(point)
	return Relics.progress_rate(counts.x) if counts.y==0 else 0.0

func controlled(point:Vector2) -> bool:
	return presence(point)==1

func presence(point:Vector2) -> int:
	var counts := point_counts(point)
	return int(counts.x > 0) + 2 * int(counts.y > 0)

# x counts scoring allies (up to the speed cap), y marks hostile presence.
func point_counts(point:Vector2) -> Vector2i:
	var counts := Vector2i.ZERO
	for unit in world.units:
		if not world.actor_alive(unit) or unit.embarked_in!=null or unit.is_air or unit.special.has("expansion_temporary") or unit.special.has("expedition_mission_unit"):continue
		if unit.position.distance_squared_to(point)>220.0*220.0:continue
		if BattleRequest.friendly("ally",unit.side):
			counts.x = mini(CAPTURE_FORCE_CAP, counts.x + 1)
		elif BattleRequest.is_house(unit.side):
			counts.y = 1
		if counts == Vector2i(CAPTURE_FORCE_CAP, 1): break
	return counts

func tick(delta:float) -> void:
	if world.ended:return
	# A checkpoint may contain an outcome from a failed settlement attempt.
	if int(state.outcome)!=0:
		finish(int(state.outcome)==1)
		return
	state.elapsed+=delta
	var explicit_clear:bool=state.kind=="annihilate"
	var owners := {}
	var remaining := remaining_enemy_buildings(owners)
	var announced: Dictionary = state.get_or_add("defeat_notices", {})
	var lost: Array = []
	var houses: Array = BattleRequest.house_teams.keys() if not BattleRequest.house_teams.is_empty() else ["enemy"]
	for side: String in houses:
		if BattleRequest.is_ai_house(side) and not BattleRequest.friendly("ally", side) and not owners.has(side) and not announced.has(side):
			announced[side] = true
			lost.append(side)
	if not lost.is_empty():
		preload("res://scripts/world/house_elimination.gd").announce(world, lost)
	if explicit_clear:state.remaining=remaining
	if remaining==0:
		finish(true)
		return
	var rate:=1.2 if Rules.synergy("special")>=3 else 1.0
	match str(state.kind):
		"capture","control":
			var multi:bool=state.kind=="control"
			var scores:Array=state.control_scores if multi else [state.progress]
			var decay:=delta if Campaign.reversible(state.kind,state.stage) else 0.0
			var capture_level := Relics.level(Expedition.state, "capture_manual")
			var best:=-1.0
			state.erase("counter_point")
			var total:=0.0
			for i in scores.size():
				var point:Vector2=state.points[i if multi else 1]
				var counts := point_counts(point)
				if counts.y > 0:
					scores[i] = maxf(0.0, float(scores[i]) - decay)
				elif counts.x > 0:
					scores[i] = minf(CONTROL_POINT_CAP, float(scores[i]) + delta * rate * capture_rate(counts.x, capture_level))
				# Occupied public objectives outrank unattended progress; never expose unit coordinates.
				var priority:=float(scores[i])+(100.0 if counts.x > 0 else 0.0)
				if priority>0 and priority>best:
					best=priority
					state.counter_point=point
				total+=float(scores[i])
			state.progress=total
			if total>=scores.size()*CONTROL_POINT_CAP:finish(true)
		"research":
			var labs:Array=state.get_or_add("labs",[0.0,0.0])
			for lab_index in 2:
				var before:=float(labs[lab_index])
				labs[lab_index]=minf(45.0,before+delta*rate*uncontested_rate(state.points[0 if lab_index==0 else 2]))
				if before<45.0 and float(labs[lab_index])>=45.0:
					world.allied_state.expedition_lab_supplies=int(world.allied_state.get("expedition_lab_supplies",0))+40
					Events.emit_message("实验室 %d 接管完成 · 研究资料已取得 · 胜利额外 +40 补给"%(lab_index+1),Color.GOLD)
			state.progress=float(labs[0])+float(labs[1])
			if state.progress>=90:finish(true)
		"rescue":
			for index in [0,2]:
				var key:="rescue"+str(index)
				if index in state.rescued:continue
				state[key]=minf(20.0,float(state.get(key,0))+delta*rate*uncontested_rate(state.points[index]))
				if state[key]>=20:
					state.rescued.append(index)
					for n in 3:
						var at:=ground(state.points[index]+Vector2(n*30,60))
						if at.is_finite():world.spawn_unit("E2" if Expedition.state.country=="苏俄" else "E1","ally",at)
			state.progress=state.rescued.size()
			if state.rescued.size()==2:finish(true)
		"supply":
			state.progress=int(actor("supply0")==null)+int(actor("supply1")==null)
			if state.progress==2:finish(true)
		"radar":
			if actor("radar")==null:finish(true)
		"assault":
			if actor("command")==null:finish(true)
		"defend":
			var defense=actor("defense")
			if defense==null:finish(false)
			else:
				state.progress+=delta
				for slot in 2:
					if float(state.relay_work[slot])>=20.0:continue
					var forces:=point_counts(state.points[slot*2])
					if forces.x==0 or forces.y>0:continue
					state.relay_work[slot]=minf(20.0,float(state.relay_work[slot])+delta*Relics.progress_rate(forces.x))
					if float(state.relay_work[slot])>=20.0:state.progress+=45.0
				state.progress=minf(360.0,state.progress)
				if state.progress>=360.0:finish(true)
		"escort":
			var missing:=0
			for n in 3:
				if n in state.arrived:continue
				var truck=actor("convoy"+str(n))
				if truck==null:missing+=1;continue
				if truck.position.distance_to(state.points[2])<170:
					state.arrived.append(n)
					truck.queue_free()
				elif not state.get("convoy_paused",false) and truck.velocity.length_squared()<1:truck.order_move(state.points[2],false)
			state.progress=state.arrived.size()
			if state.arrived.size()>=2:finish(true)
			elif missing>=2:finish(false)
			if int(state.outcome)==0:preload("res://scripts/expedition/escort_raids.gd").tick(self,delta)
		"boss":
			var held:=0
			var shield_rate:=1.0
			if int(state.stage)==Campaign.TOTAL:
				var flags:Array[int]=[]
				var strengths:Array[int]=[]
				for point:Vector2 in state.points:
					var counts:=point_counts(point)
					flags.append(int(counts.x>0)+2*int(counts.y>0))
					if counts.x>0 and counts.y==0:strengths.append(counts.x)
				if strengths.size()>=2:
					strengths.sort()
					shield_rate=Relics.progress_rate(strengths[-2])
				state.shield_points=flags
				held=flags.count(1)
			boss_tick(delta,held,shield_rate)
	if int(state.outcome)==0 and float(state.elapsed)>=float(state.next_wave):
		state.next_wave+=30.0 if state.kind=="radar" and state.elapsed>=360 else 45.0
		wave()
	queue_redraw()

func boss_tick(delta:float,held:int,shield_rate:float=1.0) -> void:
	var nodes:=int(actor("node0")!=null)+int(actor("node1")!=null)
	var command=actor("command")
	if command==null:finish(true);return
	var stage:int=state.stage
	if stage==Campaign.TOTAL:
		if nodes==0 and state.phase==0:state.phase=1
		if state.phase==1:
			if held>=2:state.progress=minf(45.0,state.progress+delta*shield_rate)
			if state.progress>=45:state.phase=2
		command.special.expedition_protected=state.phase<2
	elif stage==15:
		# A destroyed node opens a 12-second attack window each 30 seconds; both remove the shield.
		command.special.expedition_protected=nodes==2 or (nodes==1 and fmod(float(state.elapsed),30.0)>=12.0)
		state.phase=2-nodes
	elif stage==20:
		command.special.expedition_protected=false
		state.relocate-=delta
		if state.relocate<=0:
			state.relocate=30.0+(2-nodes)*20.0
			relocate_command(command)
		state.phase=2-nodes
	else:
		command.special.expedition_protected=nodes>0
		state.phase=2-nodes

func relocate_command(command) -> void:
	var base:Vector2=world.enemy_base_center
	var home:Vector2=world.player_start()
	var radius:=minf(320.0,base.distance_to(home)*0.12)
	var forward:=base.direction_to(home)*radius
	var index:=int(state.get("relocation_index",0))
	for offset in 3:
		var slot:=(index+offset)%3
		var angle:float=[-PI/2,0.0,PI/2][slot]
		var point:Vector2=world.path_service.nearest_reachable(base+forward.rotated(angle),command.position,false,8)
		if point.distance_to(base)>radius*1.6 or point.distance_to(command.position)<command.radius*2:continue
		var path:PackedVector2Array=world.path_for_unit(command,point)
		if path.size()<2 or path[-1].distance_to(point)>Unit.ARRIVE_EPS:continue
		# A bridge or cliff can make a nearby destination require a long detour.
		var limit:float=maxf(radius*1.8,base.distance_to(command.position))+world.path_service.cell
		var local_route:=true
		for step in path:
			if step.distance_to(base)>limit:local_route=false;break
		if not local_route:continue
		command.order_move(point,false,null,path)
		command.hold_position=true
		state.command_post=point
		state.relocation_index=(slot+1)%3
		return
	command.order_guard()
	state.command_post=command.position

func wave() -> void:
	if int(state.waves)>=12:return
	state.waves+=1
	var tactic:=preload("res://scripts/expedition/elite_tactics.gd").current()
	var elite:bool=Rules.context().get("elite",false)
	var roster:=Campaign.defense_wave(state.stage,state.waves,elite,tactic) if state.kind=="defend" else Campaign.wave_units(state.stage,elite,tactic)
	var home:Vector2=world.enemy_base_center
	var goal:Vector2=state.get("counter_point",state.points[1] if state.kind!="defend" else world.player_start())
	for index in roster.size():
		var at:Vector2=world.path_service.nearest_reachable(home+Vector2(index*65,220),state.points[1],false,60)
		if not at.is_finite():continue
		var unit=world.spawn_unit(roster[index],"enemy",at)
		if unit==null:continue
		preload("res://scripts/expedition/elite_tactics.gd").apply(unit,tactic)
		unit.order_move(goal,true)

func finish(win:bool) -> void:
	if world.ended:return
	if not world.has_base_assets("ally"):win=false
	state.outcome=1 if win else -1
	# Once per victory; this is a public time bonus, never a kill-based farm.
	world.allied_state.expedition_optional=win and state.kind in ["radar","supply","assault","annihilate","rescue"] and state.elapsed<=360
	world.end_battle(win)

func shield_point(index:int) -> int:
	return state.shield_points[index] if state.has("shield_points") else presence(state.points[index])

func point_occupied(index:int) -> bool:
	match str(state.kind):
		"boss":return int(state.stage)==Campaign.TOTAL and shield_point(index)==1
		"defend":return float(state.relay_work[index/2])>=20.0
		"capture":return float(state.progress)>=CONTROL_POINT_CAP
		"control":return float(state.control_scores[index])>=CONTROL_POINT_CAP
		"research":return index in [0,2] and float(state.get("labs",[0.0,0.0])[0 if index==0 else 1])>=45.0
	return false

func point_title(index:int) -> String:
	match str(state.kind):
		"defend":return ("抢修中继站" if index==0 else "截获敌军电报")+(" · 已完成" if point_occupied(index) else " · 坚守减 45 秒")
		"capture":return "前线据点 · 控制 60 秒"
		"control":return "据点 %d · %d/%d"%[index+1,int(state.control_scores[index]),CONTROL_POINT_CAP]
		"boss":return "破盾区 %d · %s"%[index+1,["待进驻","我方控制","敌军控制","交战中"][shield_point(index)]]
		"escort":return "车队撤离终点"
		"research":return "实验室 %d · %s · +40 补给"%[1 if index==0 else 2,"已接管" if point_occupied(index) else "%d / 45 秒"%int(state.get("labs",[0.0,0.0])[0 if index==0 else 1])]
		"rescue":return "救援点 %d · %s"%[1 if index==0 else 2,"陈禾医生 · 医护组" if index==0 else "严川上士 · 侦察组"]
	return "任务据点 "+str(index+1)

func completed_items() -> String:
	var done:PackedStringArray=[]
	if state.kind=="supply":
		for key:String in ["supply0","supply1"]:
			if actor(key)==null:done.append("✓ 补给设施 "+("A" if key=="supply0" else "B"))
	if state.kind=="boss":
		for key:String in ["node0","node1"]:
			if actor(key)==null:done.append("✓ 供能节点 "+("A" if key=="node0" else "B"))
	if state.kind=="escort":
		for index in state.get("arrived",[]):done.append("✓ 任务车队 %d 已抵达"%(int(index)+1))
	return " · ".join(done)

func summary() -> String:
	var name:String=Campaign.task_name(state.kind,state.stage)
	if state.kind in ["capture","control"]:
		name+=" · 敌军进圈每秒扣 1 点" if Campaign.reversible(state.kind,state.stage) else " · 已有进度保留"
	if state.kind=="annihilate":return "%s · 剩余 %d 座"%[name,int(state.remaining)]
	if state.kind=="control":
		var parts:=PackedStringArray()
		var scores:Array=state.control_scores
		for i in scores.size():
			parts.append("%d号 %d/%d"%[i+1,int(scores[i]),CONTROL_POINT_CAP])
		return "%s · %d / %d\n%s"%[name,int(state.progress),scores.size()*CONTROL_POINT_CAP," · ".join(parts)]
	if state.kind=="rescue":return "救援 · 已救出 %d / 2 组\n陈禾医生：%d / 20 秒 · 严川上士：%d / 20 秒\n清除附近敌军后驻留；每组救出 3 名作战人员"%[state.rescued.size(),mini(20,int(state.get("rescue0",0))),mini(20,int(state.get("rescue2",0)))]+"\n"+("✓ 陈禾医生已救出" if 0 in state.rescued else "○ 陈禾医生待救援")+" · "+("✓ 严川上士已救出" if 2 in state.rescued else "○ 严川上士待救援")
	if state.kind=="research":
		var labs:Array=state.get("labs",[0.0,0.0])
		return "接管实验室 · 1号 %d/45 秒 · 2号 %d/45 秒\n分别接管即可保留进度；每座胜利额外 +40 补给"%[int(labs[0]),int(labs[1])]+"\n"+("✓ 实验室 1 已接管" if float(labs[0])>=45.0 else "○ 实验室 1 待接管")+" · "+("✓ 实验室 2 已接管" if float(labs[1])>=45.0 else "○ 实验室 2 待接管")
	if state.kind=="escort":
		var raid:Dictionary=state.get("escort_pending",{})
		var warning:String="超时空侵袭 %d 秒后抵达"%maxi(0,ceili(float(raid.due)-float(state.elapsed))) if not raid.is_empty() else "下次侵袭预警 %d 秒"%maxi(0,ceili(float(state.get("escort_next_raid",20.0))-float(state.elapsed)))
		return "%s · %d / 2 · %s\n%s"%[name,int(state.progress),"车队已暂停" if state.get("convoy_paused",false) else "车队行进中",warning]
	if state.kind=="boss" and int(state.stage)==Campaign.TOTAL:
		match int(state.phase):
			0:return "核心护盾开启 · 摧毁供能节点 A 和 B"
			1:return "派地面部队同时守住任意两圈（已控 %d/3）\n破盾进度 %d/45 秒 · 失守时保留进度"%[state.get("shield_points",[]).count(1),int(state.progress)]
		return "核心护盾已解除 · 摧毁核心指挥部即可获胜"
	if state.kind=="boss" and int(state.stage)==20:return "机动指挥车 · 敌营内转移\n摧毁指挥车即过关，可先完成支线。"
	if state.kind=="boss":return "%s · 阶段 %d · %s"%[name,int(state.phase)+1,"先破标记节点" if actor("command")!=null and actor("command").special.get("expedition_protected",false) else "指挥目标可攻击"]
	if state.kind=="defend":
		var seconds:=ceili(360.0-float(state.progress))
		return "%s · 剩余 %d:%02d\n%s · %s"%[name,seconds/60,seconds%60,point_title(0),point_title(2)]
	var targets:Dictionary={"capture":60,"rescue":2,"supply":2,"escort":2}
	return name+(" · %d / %d"%[int(state.progress),int(targets[state.kind])] if targets.has(state.kind) else " · 摧毁金色标记目标")

func _draw() -> void:
	if not is_instance_valid(world) or state.is_empty():return
	for i in visible_points():
		draw_marker(state.points[i],220 if state.kind in ["boss","defend"] else 180,point_title(i),point_occupied(i))
		match str(state.kind):
			"capture":draw_point_progress(i,state.progress,60,"占领")
			"control":draw_point_progress(i,state.control_scores[i],CONTROL_POINT_CAP,"占领")
			"defend":draw_point_progress(i,state.relay_work[i/2],20,"作业")
			"research":draw_point_progress(i,state.labs[0 if i==0 else 1],45,"接管")
			"rescue":draw_point_progress(i,state.get("rescue"+str(i),0.0),20,"救援")
	if state.kind=="escort" and state.has("escort_pending"):
		var pending:Dictionary=state.escort_pending
		var seconds:int=maxi(0,ceili(float(pending.due)-float(state.elapsed)))
		draw_marker_countdown(pending.position,140,"超时空侵袭落点 · 立即布防",seconds)
	for key:String in state.targets:
		var target=actor(key)
		if target==null:continue
		draw_marker(target.position,100,str(target.special.expedition_objective_name))

func visible_points() -> Array:
	match str(state.kind):
		"capture":return [1]
		"research","defend":return [0,2]
		"rescue":
			var remaining:Array=[]
			for index:int in [0,2]:
				if index not in state.get("rescued",[]):remaining.append(index)
			return remaining
		"escort":return [2]
		"control":return [0,1,2]
		"boss":return [0,1,2] if int(state.stage)==Campaign.TOTAL and int(state.phase)==1 else []
	return []

func minimap_markers() -> Array:
	var markers:Array=[]
	if not is_instance_valid(world) or state.is_empty():return markers
	if state.kind=="escort" and state.has("escort_pending"):
		var pending:Dictionary=state.escort_pending
		var seconds:int=maxi(0,ceili(float(pending.due)-float(state.elapsed)))
		markers.append({"key":"escort_raid","position":pending.position,"title":"超时空侵袭落点 · %ds"%seconds,"countdown":seconds,"status":"active"})
	for index in visible_points():
		var done:bool=int(state.outcome)==1 or (state.kind=="rescue" and index in state.rescued)
		if point_occupied(index):done=true
		markers.append({"key":"point"+str(index),"position":state.points[index],"title":point_title(index),"status":"done" if done else "active"})
	for key:String in state.targets:
		var target=actor(key)
		if target==null:continue
		if key.begins_with("convoy") and int(key.trim_prefix("convoy")) in state.arrived:continue
		markers.append({"key":key,"position":target.global_position,"title":str(target.special.expedition_objective_name),"status":"locked" if target.special.get("expedition_protected",false) else "active"})
	if is_instance_valid(field_ops):
		markers.append_array(field_ops.markers())
		for base:Dictionary in field_ops.support_bases():
			base.merge({"key":"base_"+str(base.contact_id),"status":"base"})
			markers.append(base)
	return markers

func draw_marker(point:Vector2,radius:float,title:String,occupied:=false) -> void:
	var color:=Color("#60eb89") if occupied else Color.GOLD
	draw_arc(point,radius,0,TAU,48,Color(color,0.9),4)
	var canvas:=get_global_transform_with_canvas()
	draw_set_transform_matrix(canvas.affine_inverse())
	var baseline:=canvas*point+Vector2(-60,-65)
	draw_string_outline(ThemeDB.fallback_font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,4,Color.BLACK)
	draw_string(ThemeDB.fallback_font,baseline,title,HORIZONTAL_ALIGNMENT_LEFT,-1,18,color)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func rescue_progress(index:int) -> float:
	return clampf(float(state.get("rescue"+str(index),0.0))/20.0,0.0,1.0)

func draw_point_progress(index:int,seconds:float,required:int,action:String) -> void:
	var canvas:=get_global_transform_with_canvas()
	var center:Vector2=canvas*Vector2(state.points[index])
	var progress:=clampf(seconds,0.0,required)
	var fraction:=progress/required
	var origin:=center+Vector2(-90,-44)
	draw_set_transform_matrix(canvas.affine_inverse())
	if point_occupied(index):
		var badge:=center+Vector2(-56,-48)
		draw_rect(Rect2(badge,Vector2(112,28)),Color("#123b26"))
		var tick:=PackedVector2Array([badge+Vector2(9,14),badge+Vector2(15,20),badge+Vector2(26,8)])
		draw_polyline(tick,Color("#60eb89"),4,true)
		draw_string(ThemeDB.fallback_font,badge+Vector2(34,20),"已"+action,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	draw_rect(Rect2(origin-Vector2(2,2),Vector2(184,16)),Color(0.02,0.04,0.07,0.95))
	draw_rect(Rect2(origin,Vector2(180,12)),Color(0.18,0.20,0.23))
	draw_rect(Rect2(origin,Vector2(180*fraction,12)),Color(0.3,0.9,0.65))
	var message:="%s %d%% · %d / %d 秒"%[action,floori(progress*100.0/required),floori(progress),required]
	if state.kind in ["capture", "control"]:
		message = "%s %d%% · %d / %d 点" % [action, floori(fraction * 100), floori(progress), required]
	var width:=ThemeDB.fallback_font.get_string_size(message,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x
	var baseline:=center+Vector2(-width*0.5,-12)
	draw_string_outline(ThemeDB.fallback_font,baseline,message,HORIZONTAL_ALIGNMENT_LEFT,-1,16,5,Color.BLACK)
	draw_string(ThemeDB.fallback_font,baseline,message,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func draw_marker_countdown(point:Vector2,radius:float,title:String,seconds:int) -> void:
	draw_marker(point,radius,title)
	var canvas:=get_global_transform_with_canvas()
	draw_set_transform_matrix(canvas.affine_inverse())
	var text:="%ds"%maxi(0,seconds)
	var center:=canvas*point
	var width:=ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
	# The number sits inside the warning ring, not only in the top task card.
	draw_string(ThemeDB.fallback_font,center+Vector2(-width*0.5,11),text,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color(1.0,0.95,0.35,1.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)

func focus_next() -> void:
	var points:Array=[]
	for index in visible_points():points.append(state.points[index])
	for key:String in state.targets:
		var target=actor(key)
		if target!=null:points.append(target.position)
	if points.is_empty():return
	world.center_on(points[focus_index%points.size()])
	focus_index+=1
