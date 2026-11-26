extends RefCounted

static func stage(charge:float,thresholds:Array) -> int:
	return 2 if charge>=thresholds[1] else (1 if charge>=thresholds[0] else 0)

# Retail HVA supplies two barrel poses. The playback rate increases with gun stage.
static func spin(actor,dt:float,charge:float,thresholds:Array) -> int:
	if charge<=0:
		actor.special.erase("barrel_phase")
		return 0
	var fps:=BattleClock.RULE_TICKS_PER_SECOND*(1+stage(charge,thresholds))
	var phase:=fposmod(float(actor.special.get("barrel_phase",0.0))+dt*fps,2.0)
	actor.special.barrel_phase=phase
	return floori(phase)

static func frame(unit) -> int:
	return unit._sprite_facing(unit._ra2_tur,unit.turret_angle)+int(unit.special.get("barrel_phase",0))*int(unit._ra2_tur.facings)

static func bunker_rect(site,unit) -> Rect2:
	var base:=RA2Art.draw_rect(site._ra2,site.radius,site.body_anchor_frames(site._body_damage_frame())).position
	var wall:=RA2Art.art("NATBNK_B")
	var foot:=RA2Art.anchor(wall,[0])
	# Half of the 2x2 foundation's projected depth, from its front edge to its centre.
	var dock:=base+foot-Vector2(0,30)
	var origin:Array=unit._weapon_art.origins[frame(unit)]
	return Rect2(dock-Vector2(origin[0],origin[1])*Unit.RA2_SPRITE_SCALE,RA2Art.frame_size(unit._ra2)*Unit.RA2_SPRITE_SCALE)

static func draw_bunker_vehicle(site,turret:bool) -> void:
	var occupants:Array=site.special.get("occupants",[])
	if occupants.is_empty(): return
	var unit=occupants[0]
	if not AlliedAbilities.alive(unit) or unit.embarked_in!=site: return
	var art:Dictionary=unit._ra2_tur if turret else unit._ra2
	var index:=frame(unit) if turret else int(unit._sprite_facing(art,unit.hull_angle))
	RA2Art.draw_sprite(site,art,bunker_rect(site,unit),RA2Art.src_rect(art,index),RA2Art.sprite_grade(art))

static func aim_in_bunker(unit,target,dt:float) -> bool:
	var angle:float=unit.global_position.angle_to_point(target.global_position)
	unit.turret_angle=rotate_toward(unit.turret_angle,angle,deg_to_rad(float(unit._mv("rot",0)))*dt)
	unit.aim_dir=Vector2.from_angle(unit.turret_angle)
	unit.embarked_in.queue_redraw()
	return absf(angle_difference(unit.turret_angle,angle))<=deg_to_rad(2)
