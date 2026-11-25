extends Unit
var completed := false
var mismatches: Array = []
var comparisons := 0
var captured: Array = []
var micro:Array=[]
func draw_body_sprite(art: Dictionary, target: Rect2, source: Rect2, tint := Color.WHITE, waterline := INF) -> void:
	captured.append([art.get("key"),target,source,tint,waterline])
	super.draw_body_sprite(art,target,source,tint,waterline)
func snapshot() -> Array:
	return [captured.duplicate(true),_body_bounds,_art_frame,_art_aframes.duplicate(),_art_sc,_art_lift,_pick_body_rect,_turret_draw_rect,_turret_draw_source,_shadow_draw_rect,art_center(),special.duplicate(true)]
func _draw() -> void:
	if completed:return
	var states:Array=[{}, {"disguise":"E1"},{"disguise":"E1","reveal":1.0},{"mcv_repack_left":0.0},{"mcv_repack_left":1.0,"mcv_repack_image":"GACNST"},{"hero_stationary_shield":{"hp":100.0}},{"furnace_prone":{"hp":100.0,"rank":0}}]
	for state in states:
		for selection in [false,true]:
			selected=selection
			special=state.duplicate(true)
			captured=[]
			original_draw_pose()
			var expected:=snapshot()
			special=state.duplicate(true)
			captured=[]
			_draw_pose()
			comparisons+=1
			if snapshot()!=expected:mismatches.append([state,selection])
	if unit_id in ["MTNK","E1","GGI"]:
		special={};selected=false
		for sample in 20:
			captured=[]
			var begun:=Time.get_ticks_usec()
			for i in 200:
				if (sample%4==0 or sample%4==3):original_draw_pose()
				else:_draw_pose()
			micro.append({"id":unit_id,"variant":"before" if (sample%4==0 or sample%4==3) else "after","us":Time.get_ticks_usec()-begun,"calls":200,"sprites":captured.size()})
	completed=true

func original_draw_pose() -> void:
	preload("res://scripts/world/battle_call_counters.gd").iterations(6,1)
	_body_bounds = Rect2()
	_drew_moving_pose = velocity.length_squared() > 16.0
	RA2Art.begin_detail_draw(self)
	Iso.begin(self)
	var r := radius
	_draw_buffs(r)
	_harvest_fx.draw_on(self, true)
	if tank_finish!=null:tank_finish.draw_on(self,true)
	if _rock_t > 0.0: draw_set_transform_matrix(body_draw_transform())
	preload("res://scripts/ui/unit_selection_outline.gd").begin(self)
	if preload("res://scripts/world/construction_transition.gd").draw_repack(self):
		pass
	elif _ra3_model != null:
		_ra3_model.draw_on()
		_body_bounds = _ra3_model.projected_body_bounds()
	elif AlliedAbilities.draw_disguise(self):
		pass
	elif not _ra2.is_empty():
		_draw_ra2_sprite(r)
	else:
		_draw_procedural_body(r)
	preload("res://scripts/ui/unit_selection_outline.gd").end(self)
	if not _dead and special.has("para_height"): preload("res://scripts/world/american_paradrop.gd").draw_chute(self)
	if _rock_t > 0.0: Iso.begin(self)
	_harvest_fx.draw_on(self, false)
	if tank_finish!=null:tank_finish.draw_on(self,false)
	if yr_finish!=null:yr_finish.draw_on(self)
	AlliedAbilities.draw_status(self)
	TankHero.Shield.draw(self)
	preload("res://scripts/units/expansion_visual.gd").draw(self)
	if _stun_timer>0 and has_buff("tesla_emp"):
		_draw_emp_arcs()
	Ra3Mirage.draw_field(self)
	if not _dead and special.has("contact_reporters"): FactionCards.draw_contact(self)
	if special.has("plate_flash") or special.has("echo_left") or special.has("buoy_left"): FactionCards.draw(self)
	if special.has(DomainCards.STATE):DomainCards.draw(self)

	# 低血冒烟
	if _has_damage_particles:
		DamageParticles.draw(self)
	elif not is_naval and hp < max_hp * 0.42 and not _dead and not ((Ra3Expansion.handles(self) or Ra3Mirage.handles(self) or unit_id in ["R3TESLA","R3APOC"]) and _ra3_model!=null):
		_draw_smoke(r, hp / maxf(1.0, max_hp))

	if is_harvester and cargo_cap > 0.0:
		var fcov: float = clampf(cargo / maxf(1.0, cargo_cap), 0.0, 1.0)
		var bw: float = r * 1.8
		var by: float = -r * 2.2
		if unit_id=="HARV" and side=="ally" and cosmetic_outfit().get("skin")=="night_shift" and _body_bounds.has_area():
			by=minf(by,_body_bounds.position.y-9.0)
		draw_rect(Rect2(-bw * 0.5, by, bw, 5.0), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(-bw * 0.5 + 1.0, by + 1.0, (bw - 2.0) * fcov, 3.0), Color(1.0, 0.6, 0.22))

	_draw_selection(r)

	_draw_reverse_tag(r)
