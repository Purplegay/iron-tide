extends RefCounted
const COUNT_LABELS = [["heat_charges","余温填弹"],["sonic_count","声波计数"],["cover","编队掩护"],["arc_count","零点放电"]]
const LIST_LABELS = [["scrap","废铁装甲"],["crystals","棱镜晶体"],["echoes","昨日弹仓"]]
const STATUS_ICONS = {"succession_available":"ps_watch_succession","succession":"ps_watch_succession","temporary_post":"ap_watch_posts","temporary_reserve":"ps_watch_succession","temporary_twin":"ap_north_twin","temporary_mirror":"ap_mirror_fork","scrap":"ps_spine_scrap","echoes":"ps_north_echo","crystals":"ps_prism_crystal","mark":"ap_tracer_mark","mirror_shield":"guard","mirrors":"ap_mirror_fork","dive_cloak":"smoke","heat_charges":"reload","arc_count":"electric","sonic_count":"naval","cover":"guard"}
const R=preload("res://scripts/units/expansion_rules.gd")
const TIMERS={"swap_cd":"交换冷却","rebirth_lock":"继任整备","tracer_arm":"曳光待发","relay_left":"接力填弹","relay_cd":"接力冷却","deck_cd":"甲板轮换冷却","dive":"潜水跳脱","afterheat_cd":"余温冷却","capacitor_cd":"电容冷却","dive_boost":"俯冲余势","dive_cloak":"投弹隐身","move_lock":"断电定身","speed_left":"机动加速"}

static func entries(unit) -> Array:
	var s:Dictionary=unit.special.get(R.KEY,{})
	var out:Array=[]
	for key in TIMERS:
		if float(s.get(key,0))>0:out.append(row(TIMERS[key],float(s[key]),key=="move_lock",key))
	for spec in COUNT_LABELS:
		if int(s.get(spec[0],0))>0:
			var e:=row(spec[1],0,false,spec[0]);e.stacks=int(s[spec[0]]);out.append(e)
	for spec in LIST_LABELS:
		var values:Array=s.get(spec[0],[])
		var scrap_equipped:bool=unit is Unit and spec[0]=="scrap" and unit.passive.get("id")=="ps_spine_scrap" and R.active(unit)
		if not values.is_empty() or scrap_equipped:
			var e:=row(spec[1],0,false,spec[0]);e.stacks=values.size()
			if spec[0]=="scrap":
				e.text="装甲块剩余耐久："+str(values) if not values.is_empty() else "尚未拾取废铁，当前无额外装甲。靠近废铁至 2 格内可自动拾取。"
				if scrap_equipped:e.limit=int(R.value(unit,"ps_spine_scrap","count"))
			elif spec[0]=="echoes":
				var details:=PackedStringArray()
				for echo in s.echoes:details.append("待机 %.1fs"%maxf(0,6-echo.age) if echo.age>=1.5 else "重放准备 %.1fs"%(1.5-echo.age))
				e.text="；".join(details)
			out.append(e)
	if unit is Unit and unit.passive.get("id")=="ps_watch_succession":out.append(row("继任已用" if s.get("succession_used",false) else "继任可用",0,false,"succession_available"))
	if s.has("mark"):
		var e:=row("破甲曳光",s.mark.left,true,"mark");e.stacks=s.mark.charges;e.limit=3;out.append(e)
	if s.has("mirror_shield"):
		var e:=row("折光护盾",s.mirror_shield.left,false,"mirror_shield");e.text="剩余护盾 %.0f"%s.mirror_shield.hp;out.append(e)
	var mirrors:=preload("res://scripts/units/mirror_fork.gd").living(unit)
	if not mirrors.is_empty():out.append(row("折光岔路 · W 转移并引爆",float(mirrors[0].special.expansion_temporary.left),false,"mirrors"))
	if s.has("taunt"):out.append(row("潮汐嘲讽 · 命中诱饵一次解除",0,true,"taunt"))
	if s.has("afterburn"):out.append(row("受击加力 · 航速+%d%% / 伤害+%d%%"%[roundi(s.afterburn.speed*100),roundi(s.afterburn.damage*100)],0,false,"afterburn"))
	if s.has("tracking"):out.append(row("航标续追 · 本舰与舰载机",s.tracking.left,false,"tracking"))
	if s.has("capacitor"):out.append(row("接地电容",s.capacitor.left,false,"capacitor"))
	if R.temporary(unit):
		var t:Dictionary=unit.special.expansion_temporary
		out.append(row(unit.display_name,t.left,false,"temporary_"+str(t.kind)))
		var owner=t.owner
		if is_instance_valid(owner) and t.kind in ["post","reserve"] and unit.position.distance_to(owner.position)>5*R.CELL:out.append(row("即将离距",0,true,"post_distance"))
		var owner_state:Dictionary=owner.special.get(R.KEY,{}) if is_instance_valid(owner) else {}
		if owner_state.has("succession"):
			var p:Dictionary=owner_state.succession
			out.append(row("继任中" if is_same(p.chosen,unit) else "继任候补",p.left,false,"succession"))
	return out

static func row(text:String,left:=0.0,debuff:=false,id:="progression") -> Dictionary:
	var icon:String=STATUS_ICONS.get(id,id)
	return {"id":"expansion_"+id,"kind":"progression","icon":icon,"text":text,"name":text,"left":left,"dur":maxf(1,left),"timed":left>0,"col":Color.ORANGE if debuff else Color.CYAN,"col2":Color.TRANSPARENT,"debuff":debuff}
## Only known bookkeeping keys may bypass the overlay. New effects fall back.
static func has_visual_state(unit: Unit, state: Dictionary) -> bool:
	if unit.special.has("expansion_temporary") or unit.passive.get("id")=="ps_watch_succession": return true
	if unit.selected and unit.special.get("academy_hero")=="E1": return true
	if int(state.get("arc_count",0))>0 or float(state.get("prism_damage",0.0))!=0.0: return true
	const Idle = preload("res://scripts/units/unit_expansion_idle.gd")
	if state.size()>Idle.INERT_KEYS.size(): return true
	for key in state:
		if not Idle.INERT_KEYS.has(key): return true
	return false

static func draw(unit: Unit) -> void:
	var s:Dictionary=unit.special.get(R.KEY,{})
	if not has_visual_state(unit, s): return
	var center:=Vector2(0,-unit.radius-16-unit._visual_lift())
	if s.has("mirror_shield"):
		unit.draw_rect(Rect2(center+Vector2(-24,8),Vector2(48,4)),Color("#122b42"))
		unit.draw_rect(Rect2(center+Vector2(-24,8),Vector2(48*clampf(float(s.mirror_shield.hp)/maxf(1,float(s.mirror_shield.maximum)),0,1),4)),Color.CYAN)
	if R.temporary(unit):
		var t:Dictionary=unit.special.expansion_temporary
		var color:=Color.CYAN
		if t.kind in ["post","reserve"]:
			var owner=t.owner
			if is_instance_valid(owner):
				var os:Dictionary=owner.special.get(R.KEY,{})
				var origin:Vector2=os.succession.origin if os.has("succession") else owner.position
				if unit.position.distance_to(origin)>5*R.CELL:color=Color.ORANGE
				if os.has("succession"):
					color=Color.GOLD if is_same(os.succession.chosen,unit) else Color(.7,.8,.9)
					unit.draw_line(center,center+Vector2(0,-18),color,2)
					unit.draw_rect(Rect2(center+Vector2(0,-18),Vector2(12,8)),color,is_same(os.succession.chosen,unit),1.5)
		if t.kind=="twin":
			var trail:Array=t.get("trail",[])
			for i in trail.size():unit.draw_arc(Iso.dir(trail[i]-unit.position),unit.radius,0,TAU,12,Color(.4,.8,1,.3/(i+1)),1.0)
		if t.kind in ["twin","mirror"]:
			unit.draw_arc(Vector2.ZERO,unit.radius+5,unit._anim,unit._anim+TAU*.8,24,Color(.4,.8,1,.7),1.5)
			for i in 6:
				var a:Vector2=Vector2.from_angle(TAU*i/6)*(unit.radius+2)
				unit.draw_line(a,Vector2.from_angle(TAU*(i+1)/6)*(unit.radius+2),Color(.5,.9,1,.7),1.0)
		unit.draw_arc(Vector2.ZERO,unit.radius+2,0,TAU,24,color,1.2)
	if unit.selected and unit.special.get("academy_hero")=="E1":
		for i in 48:unit.draw_line(Iso.dir(Vector2.from_angle(TAU*i/48)*6*R.CELL),Iso.dir(Vector2.from_angle(TAU*(i+1)/48)*6*R.CELL),Color(.4,.8,1,.4),1.0)
	if not s.get("scrap",[]).is_empty():
		var hp:float=0
		for piece in s.scrap:hp+=float(piece)
		var cap:float=unit.max_hp*R.value(unit,"ps_spine_scrap","hp")*R.value(unit,"ps_spine_scrap","count")
		unit.draw_rect(Rect2(center+Vector2(-24,9),Vector2(48,4)),Color(.2,.2,.2))
		unit.draw_rect(Rect2(center+Vector2(-24,9),Vector2(48*clampf(hp/maxf(cap,1),0,1),4)),Color(.7,.75,.8))
	if AlliedAbilities.alive(s.get("twin")):star(unit,center,true)
	if unit.special.get("expansion_temporary",{}).get("kind")=="twin":
		star(unit,center,false)
		var scan:float=fmod(unit._anim*20,unit.radius*2)-unit.radius
		unit.draw_line(Vector2(-unit.radius,scan),Vector2(unit.radius,scan),Color(.4,.9,1,.4),1)
	if s.has("swap_flash"):unit.draw_arc(Vector2.ZERO,unit.radius+15,0,TAU,32,Color.CYAN,3)

static func star(unit,point:Vector2,filled:bool) -> void:
	var vertices:=PackedVector2Array()
	for i in 10:vertices.append(point+Vector2.from_angle(-PI/2+i*PI/5)*(7.0 if i%2==0 else 3.0))
	if filled:unit.draw_colored_polygon(vertices,Color.CYAN)
	else:
		vertices.append(vertices[0]);unit.draw_polyline(vertices,Color.CYAN,1.5)
