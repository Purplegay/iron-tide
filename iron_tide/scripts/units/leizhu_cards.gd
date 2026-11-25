extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="leizhu"
const ACTIVE="ap_leizhu_court"
const PASSIVE="ps_leizhu_charge"
const FIELDS="leizhu_courts"
const ELECTRODE="leizhu_electrode"
static var HALF_WIDTH:float:
	get:return P.number("mechanic/ap_leizhu_court","edge_width")*R.CELL

static func active(unit) -> bool:
	return is_instance_valid(unit) and unit is Unit and unit.special.get("academy_hero")=="TTNK" and unit.special.has(KEY) and R.active(unit)

static func legal(unit,target) -> bool:
	if not active(unit) or not R.enemy(unit,target) or not (target is Unit or target is Building):return false
	if target is Unit and (target.is_air_target() or target.is_naval or target.embarked_in!=null or AlliedAbilities.concealed(target,unit.side)):return false
	return R.world(unit).actor_visible_to(unit.side,target) and not preload("res://scripts/units/peregrine_cards.gd").protected_target(target)

static func ready(unit,ab) -> bool:
	return active(unit) and ab.id==ACTIVE and ab.ready() and unit.embarked_in==null and unit._stun_timer<=0 and not AlliedAbilities.frozen(unit)

static func points(center:Vector2) -> Array:
	var out:Array=[]
	for i in 3:out.append(center+Vector2.from_angle(-PI*.5+TAU*i/3)*P.number("mechanic/ap_leizhu_court","placement_radius")*R.CELL)
	return out

static func ground(world,point:Vector2) -> bool:
	for i in 9:
		var sample:Vector2=point if i==0 else point+Vector2.from_angle(TAU*(i-1)/8)*7
		if not preload("res://scripts/world/american_paradrop.gd").valid_zone(world,sample):return false
	return true

static func selectable(unit,at:Vector2) -> bool:
	if not active(unit) or not at.is_finite():return false
	var world=R.world(unit)
	if not world.position_visible_to(unit.side,at) or not ground(world,at):return false
	for point:Vector2 in points(at):
		if not ground(world,point):return false
	return true

static func placement(unit,at:Vector2) -> bool:
	return active(unit) and unit.position.distance_to(at)<=P.number("mechanic/ap_leizhu_court","range")*R.CELL and selectable(unit,at)

static func cast(unit,ab,at:Vector2) -> bool:
	if unit.special.has("leizhu_court_order"):return false
	if float(unit.special.get(KEY,{}).get("shutdown_left",0))>0:return false
	if not ready(unit,ab) or not placement(unit,at):return false
	var world=R.world(unit)
	var vertices:=points(at)
	var nodes:Array=[]
	var life:=R.value(unit,ACTIVE,"life")
	for point:Vector2 in vertices:
		var node=world.spawn_unit("E1",unit.side,point)
		if node==null:
			for old in nodes:R.dissolve(old)
			return false
		node.special.expansion_temporary={"kind":"electrode","owner":unit,"left":life}
		node.special[ELECTRODE]={"owner":unit,"point":point,"side":unit.side,"age":0.0}
		node.special.erase("academy_hero");node.display_name="电庭电极"
		node.data=node.data.duplicate(true);node.data.cost=0;node.data.role="structure";node.data.crushable=false;node.data.immune_to_psionics=true
		node.skills.clear();node.passive={};node.buffs.clear();node.weapon={};node.fire_stance="none"
		node.max_hp=unit.max_hp*R.value(unit,ACTIVE,"hp");node.hp=node.max_hp;node._base_max_hp=node.max_hp
		node.bonuses={};node._base_def=1;node._base_atk=0;node._base_speed=0;node.move_speed=0
		node.armor="light";node.ra2_armor="light";node.radius=7;node.sight=0;node._vet_value=0;node.veteran_level=0
		node.collision_layer=0;node.collision_mask=0;node.logistics.capacity=0;node.order_stop()
		node.visible=world.actor_visible_to("ally",node)
		nodes.append(node)
	var weapon:Dictionary=unit._weapon_for_target(null).duplicate(true)
	weapon.damage=float(weapon.get("damage",0))*R.value(unit,ACTIVE,"damage")*P.number("mechanic/ap_leizhu_court","tick_seconds")
	var bonus:Dictionary=unit.bonuses.duplicate(true);bonus.expansion_extra=true;bonus.leizhu_field=true;bonus.reference_weapon=weapon.duplicate(true)
	clear_owner(world,unit)
	var field:Dictionary={"owner":unit,"side":unit.side,"point":at,"nodes":nodes,"left":life,"weapon":weapon,"bonus":bonus,"slow":R.value(unit,ACTIVE,"slow"),"exposure":{}}
	world.allied_state.get_or_add(FIELDS,[]).append(field)
	unit.special[KEY].quiet=0.0
	ab.trigger_cooldown();tick_field(world,field,0);world.queue_redraw()
	return true

static func clear_owner(world,unit) -> void:
	for field in world.allied_state.get(FIELDS,[]).duplicate():
		if field.owner==unit:
			for node in field.nodes:R.dissolve(node)
			world.allied_state[FIELDS].erase(field)

static func vertices(field:Dictionary) -> PackedVector2Array:
	var out:=PackedVector2Array()
	for node in field.nodes:
		if AlliedAbilities.alive(node) and node.side==field.side:out.append(node.position)
	return out

static func contains(poly:PackedVector2Array,point:Vector2) -> bool:
	if poly.size()<2:return false
	if poly.size()==3 and Geometry2D.is_point_in_polygon(point,poly):return true
	for i in (1 if poly.size()==2 else 3):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,poly[i],poly[(i+1)%poly.size()]))<=HALF_WIDTH:return true
	return false

static func covers(poly:PackedVector2Array,target) -> bool:
	if poly.size()<2:return false
	if target is Unit:return contains(poly,target.position)
	# Packed arrays are shared: world-space coverage must not move the foundation.
	var footprint:PackedVector2Array=target.footprint_poly().duplicate()
	for i in footprint.size():footprint[i]+=target.position
	for point:Vector2 in footprint:
		if contains(poly,point):return true
	for point:Vector2 in poly:
		if point.distance_to(target.closest_footprint_point(point))<=HALF_WIDTH:return true
	for i in (1 if poly.size()==2 else 3):
		for j in footprint.size():
			if Geometry2D.segment_intersects_segment(poly[i],poly[(i+1)%poly.size()],footprint[j],footprint[(j+1)%footprint.size()])!=null:return true
	return false

static func damage(unit,target,weapon:Dictionary,bonus:Dictionary) -> void:
	var amount:=CombatMath.full_damage(weapon,target.armor,bonus,null,target.ra2_armor,0,target)
	target.receive_hit(amount,str(weapon.get("attack_type","electric")),bonus,unit,str(weapon.get("ra2_warhead","")))

static func tick_field(world,field:Dictionary,dt:float) -> void:
	var poly:=vertices(field)
	var inside:Array=[]
	for target in world.units.duplicate()+world.buildings.duplicate():
		if not legal(field.owner,target) or not covers(poly,target):continue
		inside.append(target)
		# Separate rank timers let a stronger court expire while a weaker one remains.
		if target is Unit:target.add_buff("leizhu_slow_"+str(roundi(float(field.slow)*100)),P.number("mechanic/ap_leizhu_court","slow_linger"),float(field.slow),"三极电庭")
		var time:float=float(field.exposure.get(target,0))+dt
		while time>=P.number("mechanic/ap_leizhu_court","tick_seconds")-0.000001 and AlliedAbilities.alive(target):
			time=maxf(0,time-P.number("mechanic/ap_leizhu_court","tick_seconds"));damage(field.owner,target,field.weapon,field.bonus)
		field.exposure[target]=time
	for target in field.exposure.keys():
		if not is_instance_valid(target) or target not in inside:field.exposure.erase(target)

static func world_tick(world,dt:float) -> void:
	var fields:Array=world.allied_state.get(FIELDS,[])
	for field:Dictionary in fields.duplicate():
		var owner=field.owner
		if not active(owner) or owner.side!=field.side or world.house_defeated(field.side) or owner.position.distance_to(field.point)>P.number("mechanic/ap_leizhu_court","tether")*R.CELL:
			for node in field.nodes:R.dissolve(node)
			fields.erase(field);continue
		var step:=minf(maxf(0,dt),float(field.left))
		tick_field(world,field,step);field.left=maxf(0,float(field.left)-step)
		for node in field.nodes:
			if AlliedAbilities.alive(node):node.special.expansion_temporary.left=field.left
		if field.left<=0.000001:
			for node in field.nodes:R.dissolve(node)
			fields.erase(field)
	if fields.is_empty():world.allied_state.erase(FIELDS)

static func contact(target,source,amount:float,bonus:Dictionary) -> void:
	if amount<=0 or not bonus.get("leizhu_primary",false) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	var unit=R.owner(source)
	if not active(unit) or unit.side!=bonus.get("leizhu_side") or unit.passive.get("id")!=PASSIVE or not legal(unit,target) or R.temporary(target):return
	if source is Projectile and source.target!=target:return
	var s:Dictionary=unit.special[KEY]
	if s.has("charge_cd"):return
	s.charge_cd=P.number("mechanic/ps_leizhu_charge","charge_interval");s.charge_left=P.number("mechanic/ps_leizhu_charge","charge_seconds");s.charge_count=int(s.get("charge_count",0))+1
	if s.charge_count>=P.count("mechanic/ps_leizhu_charge","charges"):s.charge_count=0;s.erase("charge_left");s.pending_arc=true
	unit.queue_redraw()

static func finish(unit) -> void:
	if not active(unit) or not unit.special[KEY].has("pending_arc"):return
	unit.special[KEY].erase("pending_arc")
	if unit.passive.get("id")!=PASSIVE:return
	var radius:=R.value(unit,PASSIVE,"radius")*R.CELL
	var world=R.world(unit)
	for field in world.allied_state.get(FIELDS,[]):
		if field.owner==unit and contains(vertices(field),unit.position):radius+=P.number("mechanic/ps_leizhu_charge","court_radius_bonus")*R.CELL;break
	var weapon:Dictionary=unit._weapon_for_target(null).duplicate(true);weapon.damage=float(weapon.get("damage",0))*R.value(unit,PASSIVE,"damage")
	var bonus:Dictionary=unit.bonuses.duplicate(true);bonus.expansion_extra=true;bonus.leizhu_arc=true;bonus.reference_weapon=weapon.duplicate(true)
	for target in world.units.duplicate()+world.buildings.duplicate():
		if legal(unit,target) and unit.position.distance_to(R.point(unit,target))<=radius:damage(unit,target,weapon,bonus)
	unit.special[KEY].arc_flash={"left":.35,"radius":radius};unit.queue_redraw()

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special[KEY]
	for key in ["charge_cd","charge_left"]:
		R.timer(s,key,maxf(0,dt))
		if float(s.get(key,0))<=0.000001:s.erase(key)
	if not s.has("charge_left"):s.charge_count=0
	if unit.passive.get("id")!=PASSIVE or s.get("side",unit.side)!=unit.side:
		for key in ["charge_cd","charge_left","charge_count","pending_arc"]:s.erase(key)
	if s.has("arc_flash"):
		s.arc_flash.left-=maxf(0,dt)
		if s.arc_flash.left<=0:s.erase("arc_flash")

static func electrode_tick(node,dt:float) -> void:
	if not AlliedAbilities.alive(node):node.queue_free();return
	var state:Dictionary=node.special[ELECTRODE]
	if not active(state.owner) or state.owner.side!=state.side:R.dissolve(node);return
	node.visible=R.world(node).actor_visible_to("ally",node)
	node.position=state.point;node.velocity=Vector2.ZERO;node.has_move_order=false;state.age+=maxf(0,dt);node.queue_redraw()

static func draw_electrode(node) -> void:
	node._body_bounds=Rect2(-10,-27,20,30)
	node.draw_circle(Vector2.ZERO,9,Color(.08,.12,.16,.8))
	node.draw_rect(Rect2(-4,-21,8,21),Color(.35,.37,.4))
	for y in [-17,-12,-7]:node.draw_arc(Vector2(0,y),7,0,TAU,16,Color(.8,.55,.26),2)
	var glow:float=.65+.35*sin(float(node.special[ELECTRODE].age)*5)
	node.draw_circle(Vector2(0,-24),3.5,Color(.4,.85,1,glow))
	if node.selected or node.hovered:node.draw_arc(Vector2(0,-10),16,0,TAU,24,Color.YELLOW,1)

static func draw_fields(canvas,world) -> void:
	for field in world.allied_state.get(FIELDS,[]):
		var poly:=vertices(field)
		if poly.size()<2:continue
		if poly.size()==3 and world.position_visible_to("ally",poly[0]) and world.position_visible_to("ally",poly[1]) and world.position_visible_to("ally",poly[2]):
			canvas.draw_colored_polygon(PackedVector2Array([Iso.dir(poly[0]),Iso.dir(poly[1]),Iso.dir(poly[2])]),Color(.2,.65,1,.09))
		for i in (1 if poly.size()==2 else 3):
			var a:Vector2=poly[i];var b:Vector2=poly[(i+1)%poly.size()]
			if world.position_visible_to("ally",a) and world.position_visible_to("ally",b):canvas.draw_line(Iso.dir(a),Iso.dir(b),Color(.3,.75,1,.7),3,true)

static func draw(unit) -> void:
	var s:Dictionary=unit.special.get(KEY,{})
	if s.has("arc_flash"):unit.draw_arc(Vector2.ZERO,float(s.arc_flash.radius),0,TAU,48,Color(.4,.85,1,float(s.arc_flash.left)/.35),2,true)

static func draw_preview(world,unit,point:Vector2) -> void:
	var color:=Color(1,.2,.2,.7)
	if selectable(unit,point):
		color=Color(.3,.8,1,.8) if unit.position.distance_to(point)<=P.number("mechanic/ap_leizhu_court","range")*R.CELL else Color(1,.75,.25,.8)
	var poly:=PackedVector2Array()
	for vertex:Vector2 in points(point):
		poly.append(Iso.dir(vertex))
		Iso.outline(world,Iso.ground_circle(vertex,7),color,2)
	world.draw_colored_polygon(poly,Color(color,.1))
	for i in 3:world.draw_line(poly[i],poly[(i+1)%3],color,2,true)
	Iso.outline(world,Iso.ground_circle(unit.position,P.number("mechanic/ap_leizhu_court","range")*R.CELL),Color(.3,.8,1,.35),1)

static func entries(unit) -> Array:
	const V=preload("res://scripts/units/expansion_visual.gd")
	var rows:Array=[];var s:Dictionary=unit.special[KEY]
	if unit.passive.get("id")==PASSIVE:rows.append(V.row("电荷调度 · %d/3 层"%int(s.get("charge_count",0)),float(s.get("charge_left",0)),false,"electric"))
	for field in R.world(unit).allied_state.get(FIELDS,[]):
		if field.owner==unit:rows.append(V.row("三极电庭 · %d/3 电极"%vertices(field).size(),field.left,false,"electric"))
	return rows
