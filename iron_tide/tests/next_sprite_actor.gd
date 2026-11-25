extends Unit
const Before=preload("res://tests/next_sprite_reference.gd")
var completed:=false
var mismatches:Array=[]
var micro:Array=[]
var captured:Array=[]
var before:=false
func snapshot() -> Array:
	return [captured.duplicate(true),_art_frame,_art_aframes.duplicate(),_art_sc,_art_lift,_pick_body_rect,_turret_draw_rect,_turret_draw_source,_shadow_draw_rect,_body_bounds,art_center()]
func _draw() -> void:
	if completed:return
	for deployed in [false,true]:
		_deployed=deployed
		for moving in [false,true]:
			velocity=Vector2(10,0) if moving else Vector2.ZERO
			for bearing in [0.0,1.7,4.1]:
				hull_angle=bearing;turret_angle=bearing+0.3
				for firing in [-1.0,0.15]:
					_fire_anim_time=firing
					before=true;captured=[];_body_bounds=Rect2();_draw_ra2_sprite(radius)
					var expected:=snapshot()
					before=false;captured=[];_body_bounds=Rect2();_draw_ra2_sprite(radius)
					if snapshot()!=expected:mismatches.append([deployed,moving,bearing,firing])
	_deployed=false;velocity=Vector2.ZERO;_fire_anim_time=-1
	for sample in 20:
		before=sample%4==0 or sample%4==3
		captured=[];var begun:=Time.get_ticks_usec()
		for i in 250:_draw_ra2_sprite(radius)
		micro.append({"id":unit_id,"variant":"before" if before else "after","us":Time.get_ticks_usec()-begun,"calls":250,"sprites":captured.size()})
	completed=true

func draw_body_sprite(art: Dictionary, target: Rect2, source: Rect2, tint := Color.WHITE, waterline := INF) -> void:
	captured.append([art.get("key"),target,source,tint,waterline])
	if before:Before.draw_sprite(self, art, target, source, tint,waterline)
	else:RA2Art.draw_sprite(self, art, target, source, tint,waterline)
	var bounds := RA2Art.visible_sprite_rect(art, target, source)
	if not bounds.has_area(): return
	if uses_missile_pitch():
		bounds = SovietWeapons.DreadFlight.pose(self, _visual_lift()) * bounds
	elif _rock_t > 0.0:
		bounds = rocking_pose() * bounds
	_body_bounds = _body_bounds.merge(bounds) if _body_bounds.has_area() else bounds

## 血条改由 battle.hp_overlay 在高层级（DepthLayers.WORLD_HUD）统一绘制，
## 恒盖在所有实体（含建筑）之上。
## origin 为 begin 空间坐标（调用方传 Iso.dir(世界坐标)），ci 为其所属 CanvasItem。