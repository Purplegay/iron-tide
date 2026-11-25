extends Control
## Deterministic presentation clock. Seeking never issues a real unit order.
const Cards = preload("res://scripts/units/furnace_legend.gd")
static var LENGTH:float:
	get:return maxf(13.0,DEPLOY+preload("res://scripts/rules/progression_parameters.gd").number("mechanic/ap_furnace_bastion","shield_seconds")+2.0)
const DEPLOY := 1.0
const CONTACT := 2.5
const BREAK := 5.5
const GOLD := Color("#ffe397")
const CYAN := Color("#77dce8")
const RED := Color("#ff9180")
var mode := "furnace_contract"
var w_rank := 0
var p_rank := 0
var ending := 0
var elapsed := 0.0
var playing := true
var playback_speed := 1.0

func _process(delta:float) -> void:
	if not playing: return
	elapsed=minf(LENGTH,elapsed+delta*playback_speed)
	if elapsed>=LENGTH: playing=false
	queue_redraw()

func sample() -> Dictionary:
	var w := GameData.get_skill(Cards.ACTIVE)
	var p := GameData.get_skill(Cards.PASSIVE)
	var deployed := mode!=Cards.PASSIVE and elapsed>=DEPLOY
	var expires:=DEPLOY+preload("res://scripts/rules/progression_parameters.gd").number("mechanic/ap_furnace_bastion","shield_seconds")
	var end_time := expires if ending==2 else minf(expires,BREAK)
	var shield := float(w.shield_by_rank[w_rank]) if deployed and elapsed<end_time else 0.0
	if ending==0 and elapsed>=BREAK-1.2: shield*=0.5
	var age := elapsed-CONTACT
	var life := float(p.life_by_rank[p_rank])
	var engaged := mode!=Cards.ACTIVE and age>=0
	return {"prone":deployed and (ending!=1 or elapsed<BREAK),"shield":shield,
		"blast_age":elapsed-BREAK if deployed and ending!=2 and expires>BREAK else -1.0,
		"air":mode!=Cards.ACTIVE and elapsed>=CONTACT-0.8,"guards":engaged and age<life,
		"guard_hp":maxf(0,1.0-age*age/(life*life)) if engaged else 0.0,
		"guard_left":maxf(0,life-age),"summon_cd":Cards.SUMMON_COOLDOWN-age if engaged else 0.0}

func sprite(id:String,frame:int,foot:Vector2,zoom:float,modulate_color:=Color.WHITE) -> Rect2:
	var art:=RA2Art.art(id)
	if art.get("tex")==null:return Rect2()
	var src:=RA2Art.src_rect(art,frame)
	var dest:=Rect2(foot-RA2Art.anchor(art,[frame])*zoom,src.size*zoom)
	draw_texture_rect_region(art.tex,dest,src,modulate_color)
	return dest

func caption(at:Vector2,line:String,col:Color) -> void:
	draw_string(ThemeDB.fallback_font,at,line,HORIZONTAL_ALIGNMENT_LEFT,-1,15,col)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("#1c232b"))
	var scale_factor:=minf(size.x/680.0,size.y/250.0)
	if scale_factor<=0:return
	draw_set_transform((size-Vector2(680,250)*scale_factor)*0.5,0,Vector2.ONE*scale_factor)
	var s:=sample()
	var w:=GameData.get_skill(Cards.ACTIVE)
	var p:=GameData.get_skill(Cards.PASSIVE)
	var travel_time:=clampf(elapsed-DEPLOY,0,BREAK-DEPLOY if ending==1 else LENGTH-DEPLOY)
	var hero:=Vector2(173,140)
	if mode!=Cards.PASSIVE: hero.x+=travel_time*42*float(w.speed_by_rank[w_rank])
	var facing:=6
	var frame:=RA2Art.seq_frame(RA2Art.seq("E2"),"Crawl" if s.prone else "Guard",facing,int(elapsed*4))
	var dest:=sprite("E2",frame,hero,1.45)
	if s.prone and dest.has_area():
		var region:=Cards.armor_region(frame)
		if region.has_area(): draw_texture_rect_region(Cards.ARMOR,dest,region)
	if s.shield>0:
		draw_circle(hero+Vector2.UP*13,34,Color(CYAN,0.12))
		draw_arc(hero+Vector2.UP*13,34,0,TAU,48,CYAN,2,true)
	caption(hero+Vector2(-18,22),"炉火",GOLD)
	if mode!=Cards.PASSIVE:
		var victim:=Vector2(247,143)
		var splash_hit:bool=s.blast_age>=0 and s.blast_age<0.45
		sprite("E1",2,victim,1.15,RED if splash_hit else Color.WHITE)
		if ending==0:
			for hit in [BREAK-1.2,BREAK]:
				var progress:=clampf((elapsed-float(hit)+0.3)/0.3,0,1)
				if progress>0 and progress<1:draw_circle(victim.lerp(hero,progress)-Vector2(0,11),3,RED)
		if s.blast_age>=0 and s.blast_age<0.65:
			draw_arc(hero,lerpf(8,Cards.RADIUS,s.blast_age/0.65),0,TAU,64,Color(GOLD,1.0-s.blast_age/0.65),3,true)
			caption(victim+Vector2(-16,-44),"溅射",RED)
		var text:="手动 W · 等待部署" if elapsed<DEPLOY else "卧倒 · 护盾 %d%% 最大生命"%roundi(s.shield*100) if s.shield>0 else "自然消盾 · 继续卧倒" if ending==2 else "起身破盾" if ending==1 else "受击破盾 · 继续卧倒"
		if elapsed>=BREAK and ending!=2: text+=" · %s 格溅射 %d%%"%[MetaProgress.Academy.skill_number(Cards.RADIUS/Ra2Damage.PX_PER_CELL),roundi(w.burst_by_rank[w_rank]*100)]
		caption(Vector2(24,204),text,GOLD)
	var plane:=Vector2(526+120*(1.0-clampf((elapsed-CONTACT+0.8)/0.8,0.0,1.0))+12*sin(elapsed),74+4*sin(elapsed*2))
	if s.air: sprite("ORCA",20,plane,0.9)
	if s.guards:
		for i in preload("res://scripts/rules/progression_parameters.gd").count("mechanic/ap_furnace_bastion","summon_count"):
			var car:=Vector2(335+i*76,126+i*27)
			sprite("HTK",5,car,0.9)
			sprite("HTK_tur",5,car-Vector2(0,7),0.9)
			draw_rect(Rect2(car+Vector2(-23,-43),Vector2(46,5)),Color("#10161b"))
			draw_rect(Rect2(car+Vector2(-23,-43),Vector2(46*s.guard_hp,5)),CYAN)
			var period:=float(GameData.get_unit("HTK").anti_air_weapon.cooldown)/float(p.rof_by_rank[p_rank])
			var shot_age:=fposmod(elapsed-CONTACT+i*0.12,period)
			if shot_age<0.2:draw_circle((car-Vector2(0,18)).lerp(plane-Vector2(0,12),shot_age/0.2),3,GOLD)
			elif shot_age<0.45:draw_arc(plane-Vector2(0,12),(shot_age-0.2)*46+3,0,TAU,12,RED,2,true)
	elif mode!=Cards.ACTIVE:
		var decay_age:=elapsed-CONTACT-float(p.life_by_rank[p_rank])
		if decay_age>=0 and decay_age<0.6:
			for i in preload("res://scripts/rules/progression_parameters.gd").count("mechanic/ap_furnace_bastion","summon_count"):
				var at:=Vector2(335+i*76,126+i*27)
				for piece in 6:
					var offset:=Vector2.from_angle(TAU*piece/6.0)*decay_age*40.0
					draw_circle(at+offset,2.5,Color(GOLD,1.0-decay_age/0.6))
	if mode!=Cards.ACTIVE:
		var text:="等待可见空敌进入射程" if s.summon_cd<=0 else "两辆防空车 · %.1f 秒后分解"%s.guard_left if s.guards else "防空车已分解"
		if s.summon_cd>0:text+="　再次召唤 %.1f 秒"%s.summon_cd
		caption(Vector2(24,232),text,CYAN)
