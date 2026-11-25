extends Unit
var completed := false
var mismatches: Array = []
var comparisons := 0
var micro:Array=[]
var captured: Array = []
func draw_body_sprite(art: Dictionary, target: Rect2, source: Rect2, tint := Color.WHITE, waterline := INF) -> void:
	captured.append([art.get("key"),target,source,tint,waterline])
	super.draw_body_sprite(art,target,source,tint,waterline)
func draw_prepared_voxel(prepared, target: Rect2, frame: int, tint: Color) -> void:
	captured.append([prepared.art.get("key"),target,prepared.sources[frame],tint,INF])
	super.draw_prepared_voxel(prepared,target,frame,tint)
func snapshot() -> Array:
	return [captured.duplicate(true),_art_frame,_art_aframes.duplicate(),_art_sc,_art_lift,_pick_body_rect,_turret_draw_rect,_turret_draw_source,_shadow_draw_rect,art_center()]
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
					captured=[]
					original_draw_sprite(radius)
					var expected:=snapshot()
					captured=[]
					_draw_ra2_sprite(radius)
					comparisons+=1
					if snapshot()!=expected:mismatches.append([deployed,moving,bearing,firing])
	if not _ra2.is_empty():
		_deployed=false;velocity=Vector2.ZERO;_fire_anim_time=-1
		for sample in 20:
			captured=[]
			var begun:=Time.get_ticks_usec()
			for i in 200:
				if (sample%4==0 or sample%4==3):original_draw_sprite(radius)
				else:_draw_ra2_sprite(radius)
			micro.append({"id":unit_id,"variant":"before" if (sample%4==0 or sample%4==3) else "after","us":Time.get_ticks_usec()-begun,"calls":200,"sprites":captured.size()})
	completed=true

func original_draw_sprite(r: float) -> void:
	var tex: Texture2D = _ra2.get("tex")
	if tex == null:
		return
	var sz: Vector2 = RA2Art.frame_size(_ra2)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return
	var kind := str(_ra2.get("kind", "vxl"))
	var rects: Array = _ra2.get("rects", [])
	var facings := RA2Art.INFANTRY_FACINGS if kind == "shp" else int(_ra2.get("facings", 8))
	var fidx := _sprite_facing(_ra2, hull_angle) if kind == "vxl" or unit_id in ["DLPH","SQD"] else RA2Art.facing_index(hull_angle, facings)
	var frame := fidx
	var aframes: Array = range(facings)
	if _seq.has("Guard"):
		frame = RA2Art.seq_frame(_seq, "Guard", fidx, 0)
		var guard: Dictionary = _seq.Guard
		aframes = range(int(guard.start), int(guard.start) + int(guard.per) * int(guard.facings))
	if kind == "vxl" and int(_ra2.get("poses", 1)) > 1:
		var poses := int(_ra2.poses)
		aframes = range(facings * poses)
		if logistics.air_lift > 0.1:
			frame += posmod(int(_anim * float(_ra2.get("fps", 20.0))), poses) * facings
	elif _dying <= 0.0 and unit_id == "DESO" and _deployed:
		# DesoSequence has one shared deployed pose, independent of facing.
		frame = RA2Art.seq_frame(_seq, _fire_sequence(), fidx, int(_fire_anim_time * 16.0)) if _fire_anim_time >= 0 else _deploy_frame
		aframes = [_deploy_frame]
	elif unit_id=="GGI" and yr_finish!=null and _dying<=0.0 and yr_finish.fold>0 and yr_finish.fold<1 and _fire_anim_time<0:
		var transition:="Down" if _deployed else "Up"
		var fraction:float=yr_finish.fold if _deployed else 1.0-yr_finish.fold
		frame=RA2Art.seq_frame(_seq,transition,fidx,mini(1,int(fraction*2)))
	elif _dying <= 0.0 and _deployed and _deploy_frame >= 0 and kind == "shp" and _deploy_frame + facings <= rects.size():
		frame = _deploy_frame + fidx
		aframes = range(_deploy_frame, _deploy_frame + facings)
		if _seq.has("DeployedFire"):
			var firing: Dictionary = _seq.DeployedFire
			# One shared anchor prevents the body jumping between idle and gunfire.
			aframes.append_array(range(int(firing.start), int(firing.start) + int(firing.per) * facings))
			if _fire_anim_time >= 0.0:
				frame = RA2Art.seq_frame(_seq, "DeployedFire", fidx, int(_fire_anim_time * 16.0))
	elif not _seq.is_empty():
		var nm := ""
		var fps := 14.0
		if _dying > 0.0:
			nm = str(special.get("death_sequence", "Die1"))
			fps = flight.TICKS if flight.crash_lift >= 0.0 else 13.0
		elif special.has(Furnace.STANCE) and _seq.has("Crawl"):
			nm = "FireProne" if _fire_anim_time >= 0 and _seq.has("FireProne") else "Crawl"
		elif special.has("para_height"):
			nm = "Paradrop"
		elif unit_id == "BORIS" and is_instance_valid(attack_target) and attack_target is Building and attack_target.special.get("airstrike_mark", {}).get("spotter") == self:
			nm = "SecondaryFire" # Original eight-direction laser-designator pose.
		elif _fire_anim_time >= 0.0 or _muzzle > 0.0:
			nm = _fire_sequence()
			fps = 16.0
		elif is_air_target() and _seq.has("Fly"):
			# RocketeerSequence has distinct airborne poses; never use Walk aloft.
			nm = "Fly" if _moving() or not _seq.has("Hover") else "Hover"
		elif _moving():
			nm = "Walk"
			fps = 14.0
		if nm.is_empty() and unit_id in ["DLPH","SQD"]:
			nm = "Walk" # Naval SHP uses the swimming cycle even at rest.
		if _swimming():
			if _dying > 0.0: nm = str(special.get("death_sequence", nm))
			elif nm == "Walk": nm = "Swim" if _seq.has("Swim") else nm
			elif nm.is_empty(): nm = "Tread" if _seq.has("Tread") else "Guard"
		if nm != "":
			var t := int(_anim * fps + 0.00001)
			if _dying > 0.0 and _seq.has(nm): t = mini(t, int(_seq[nm].per) - 1)
			if nm == _fire_sequence() and _fire_anim_time >= 0.0:
				t = int(_fire_anim_time * fps + 0.00001)
			if nm == "Walk":
				var wseg: Dictionary = _seq[nm]
				var wper := int(wseg.get("per", 6))
				if unit_id == "DLPH" and not _moving():
					t = int(_anim * _naval_idle_fps)
				else:
					t = int(_walk_phase * float(wper))
			if special.has(Furnace.STANCE) and nm=="Crawl": t=int(_walk_phase * int(_seq.Crawl.per)) if _moving() else 0
			var f2 := RA2Art.seq_frame(_seq, nm, fidx, t)
			if f2 >= 0 and f2 < rects.size():
				frame = f2
		if nm in ["", "Tread", "Guard"] and idle_pose != null and idle_pose.appearance == unit_id and idle_pose.frame >= 0:
			frame = idle_pose.frame
	if unit_id == "SCHP" and _ra2.get("key") == "SCHPDEPL":
		var count := maxi(1, rects.size() / 2)
		aframes = range(count)
		frame = clampi(int(float(special.get("siege_progress", 0.0)) * count), 0, count - 1)
	var src := RA2Art.src_rect(_ra2, frame)
	var sc := RA2_SPRITE_SCALE
	var dive := NavalContact.dive_fraction(self)
	var lift := _visual_lift()
	if unit_id in ["SUB","DLPH"]: lift -= NavalContact.DIVE_DEPTH_PIXELS * dive
	var a := RA2Art.anchor(_ra2, aframes)
	var base := Vector2(-a.x * sc, r * 0.35 - a.y * sc - lift)
	# (b) 单位贴图自动提亮：抵消体素着色下限 0.42 与偏暗素材（CMIN 等）。可逆。
	var grade: Color = RA2Art.sprite_grade(_ra2)
	if special.get("hero_skin", false) and unit_id in ["E1","E2"]:
		grade *= Color(0.68, 0.93, 1.15) if unit_id == "E1" else Color(1.18, 0.79, 0.60)
	var cloak_alpha := Ra3Mirage.CloakVisual.opacity(self)
	if unit_id in ["SQD", "SUB", "DLPH"]:
		grade *= Color.WHITE.lerp(Color(0.53, 0.76, 0.88), dive)
	grade.a *= cloak_alpha * (1.0 - 0.5 * dive)
	if powered_unit.offline:
		grade = grade.darkened(0.45)
	# 地面投影：优先用管线烘出的 RA2 体素阴影（<id>_shd.png，VXL 沿光向压平、与主体同 base/cell，
	# 见 ra2pipe/vxl_lib.mjs 的 shadow 模式；方向与建筑 SHP 影子帧一致 = 屏幕右侧）。
	# 没有影子图（步兵 SHP、程序化单位）时退回等距椭圆。
	var shd_tex: Texture2D = _ra2_shd.get("tex")
	var joint_shadow: Texture2D
	if bool(_ra2.get("split_shadow", false)) and not _ra2_tur.is_empty():
		var turret_shadow := RA2Art.art(str(_ra2_tur.get("key", "")) + "_shd")
		if not turret_shadow.is_empty():
			joint_shadow = RA2Art.unit_shadow_texture(_ra2_shd, turret_shadow, frame, _sprite_facing(turret_shadow, turret_angle))
	if _rock_t > 0.0: Iso.begin(self)
	_shadow_draw_texture = joint_shadow
	_shadow_draw_rect = Rect2()
	var dolphin_waterline:=INF
	var water_center:=Vector2.ZERO
	if unit_id=="DLPH":
		water_center=base+sz*sc*0.5+Vector2.DOWN*(4.0-NavalContact.DIVE_DEPTH_PIXELS*dive)
		dolphin_waterline=water_center.y-18.0*dive
		NavalContact.draw_dolphin_wake(self,water_center,dive,false)
	elif dive >= 1.0 or unit_id == "SQD" or uses_missile_pitch():
		pass # Submerged hulls and NoShadow missiles omit the surface shadow.
	elif unit_id=="SCHP" and _ra2.get("key")=="SCHPDEPL":
		_shadow_draw_rect=Rect2(base+Vector2.DOWN*lift,sz*sc)
		draw_texture_rect_region(_ra2.tex,_shadow_draw_rect,RA2Art.src_rect(_ra2,frame+aframes.size()),Color(0,0,0,0.5*cloak_alpha))
	elif shd_tex != null:
		var ssz: Vector2 = RA2Art.frame_size(_ra2_shd)
		if ssz.x > 0.0:
			_shadow_draw_rect = Rect2(base + Vector2(0.0, lift), ssz * sc)
			if joint_shadow != null:
				draw_texture_rect(joint_shadow, _shadow_draw_rect, false, Color(0.0, 0.0, 0.0, 0.5 * cloak_alpha * (1.0 - dive)))
			else:
				draw_texture_rect_region(shd_tex, _shadow_draw_rect, RA2Art.src_rect(_ra2_shd, frame), Color(0.0, 0.0, 0.0, 0.5 * cloak_alpha * (1.0 - dive)))
	else:
		Iso.shadow(self, Vector2(r * 0.34, r * 0.4), r * 0.85, 0.34 * cloak_alpha * (1.0 - dive))
	if _rock_t > 0.0: draw_set_transform_matrix(body_draw_transform())
	if uses_missile_pitch():
		draw_set_transform_matrix(Transform2D(Iso.eff_angle(), Iso.up(), 0.0, Vector2.ZERO) * SovietWeapons.DreadFlight.pose(self,lift))
	var armored: bool = not special.has(Furnace.STANCE) and special.get("hero_skin", false) and unit_id in ["E1","E2"] and _dying <= 0.0
	var armor_anchor := Vector2.ZERO
	var armor_bearing:=float(fidx)
	if armored:
		armor_bearing=HeroArmor.pose_bearing(self,frame,fidx)
		armor_anchor = HeroArmor.head(self,frame,src,Rect2(base,sz*sc))
		HeroArmor.draw_layer(self,armor_anchor,armor_bearing,true,grade.a)
	var coastal:=unit_id=="GGI" and yr_finish!=null and _dying<=0.0 and not _dead and not special.has("para_height")
	if coastal:CoastalRig.draw_layer(self,base,frame,fidx,true)
	if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_tail(self,base,fidx,false,grade.a)
	if casemate_thruster!=null:casemate_thruster.exhaust(self,base,fidx,grade.a,true)
	draw_body_sprite(_ra2, Rect2(base, sz * sc), src, grade,dolphin_waterline)
	if special.has(Furnace.STANCE) and not _dead: Furnace.draw_armor(self,frame,Rect2(base,sz*sc),grade.a)
	TankHeroSkin.draw_layer(self,base,fidx,false,grade.a)
	if unit_id=="SREF" and yr_finish!=null:yr_finish.solar_hull(self,Rect2(base,sz*sc),fidx,grade.a)
	if casemate_thruster!=null:
		casemate_thruster.armor(self,Rect2(base,sz*sc),src,fidx,grade.a)
		casemate_thruster.exhaust(self,base,fidx,grade.a,false)
	if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_tail(self,base,fidx,true,grade.a)
	if unit_id=="DLPH":NavalContact.draw_dolphin_wake(self,water_center,dive,true)
	if uses_missile_pitch():
		Iso.begin(self)
		SovietWeapons.DreadFlight.draw_exhaust(self)
	# 独立炮塔：与车体同画布对齐，按 turret_angle 单独取帧叠加
	_turret_draw_rect = Rect2()
	if not _ra2_tur.is_empty():
		var ttex: Texture2D = _ra2_tur.get("tex")
		if ttex != null:
			var tsz: Vector2 = RA2Art.frame_size(_ra2_tur)
			if tsz.x > 0.0 and tsz.y > 0.0:
				var tfi := _sprite_facing(_ra2_tur, turret_angle)
				var draw_offset: Array = _ra2_tur.get("draw_offset", [0, 0])
				_turret_draw_rect = Rect2(base + Vector2(draw_offset[0], draw_offset[1]) * sc, tsz * sc)
				_turret_draw_source = RA2Art.src_rect(_ra2_tur, tfi)
				var turret_grade := RA2Art.sprite_grade(_ra2_tur)
				turret_grade.a *= cloak_alpha * (1.0 - 0.5 * dive)
				if powered_unit.offline:
					turret_grade = turret_grade.darkened(0.45)
				draw_body_sprite(_ra2_tur, _turret_draw_rect, _turret_draw_source, turret_grade)
				TankHeroSkin.draw_layer(self,base,tfi,true,turret_grade.a)
				if unit_id=="TTNK" and yr_finish!=null:yr_finish.pika_head(self,base,tfi,turret_grade.a)
	# 记录本帧绘制参数，供 hit_test()/art_center() 复用（铁律：判定几何 = 绘制几何）
	if armored:
		HeroArmor.draw_layer(self,armor_anchor,armor_bearing,false,grade.a)
	if coastal:CoastalRig.draw_layer(self,base,frame,fidx,false)
	if unit_id=="HARV" and side=="ally" and cosmetic_outfit().get("skin")=="night_shift":
		preload("res://scripts/units/night_shift.gd").truck(self,base,fidx,facings,sc)
	_pick_body_art = _ra2
	_pick_body_rect = Rect2(base, sz * sc)
	_art_frame = frame
	_art_aframes = aframes
	_art_sc = sc
	_art_lift = lift
