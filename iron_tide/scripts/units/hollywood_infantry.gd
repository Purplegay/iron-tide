extends RefCounted

const FPS := BattleClock.RULE_TICKS_PER_SECOND
const SUPPRESSION := 30.0 / FPS

static func begin_pulse(u) -> bool:
	if AlliedAbilities.frozen(u): return false
	if u.special.has("psi_elapsed"):
		if float(u.special.psi_elapsed)*FPS<int(u._seq.Deploy.per) or pose(u)=="Undeploy": return false
		start_folding(u)
		return true
	if float(u.special.get("psi_reload",0))>0: return false
	u.order_stop(false)
	u._cancel_burst()
	u.special.psi_elapsed = 0.0
	u.special.psi_fire_at = 1.0 + maxf(0,u._cd_timer) + float(u.data.fire_up_ticks)/FPS
	u.special.psi_fold_at = float(u.data.undeploy_ticks)/FPS
	u._request_pose_redraw()
	return true

static func start_folding(u) -> void:
	if u.special.has("psi_elapsed"):
		u.special.psi_fold_at=minf(u.special.psi_fold_at,u.special.psi_elapsed)
		u._request_pose_redraw()

static func fire_pulse(u) -> void:
	var world = u._battle_world()
	var gun:Dictionary = u.data.secondary_weapon
	var wh:String = gun.ra2_warhead
	u.special.psi_reload=float(gun.cooldown)
	u._cd_timer=float(u.weapon.cooldown)
	var ring = Ra2Fx.play(world.effects_root,u.position,"RING1")
	if ring != null: ring.draw_offset=Iso.dir(u.HollywoodFx.muzzle(u,true)-u.global_position)
	Ra2Sfx.play_weapon(gun,u.position)
	for target in world.units.duplicate():
		if not world.actor_alive(target) or target.embarked_in != null or target.is_air_target() or BattleRequest.friendly(target.side,u.side): continue
		var distance:float = u.position.distance_to(target.position)
		if Ra2Damage.in_spread(distance,wh) and not AlliedAbilities.flag(target,"ImmuneToPsionicWeapons"):
			var damage := Ra2Damage.target_damage(gun.damage,wh,target,distance)
			if damage > 0: target.receive_hit(damage,"bullet",{},u,wh,u.position,gun.damage)

static func suppress(u) -> void:
	if not u.special.has("prone_left"): u.special.prone_transition = float(u._seq.Down.per)/FPS
	u.special.prone_left = SUPPRESSION

static func tick(u,delta:float) -> bool:
	if u.special.has("psi_reload"):
		u.special.psi_reload -= delta
		if u.special.psi_reload <= 0: u.special.erase("psi_reload")
	if u.special.has("psi_elapsed"):
		var previous:float = u.special.psi_elapsed
		var elapsed := previous + delta
		u._cd_timer=maxf(0,u._cd_timer-delta)
		var fire_at:float = u.special.psi_fire_at
		if previous < fire_at and elapsed >= fire_at and fire_at < u.special.psi_fold_at: fire_pulse(u)
		u.special.psi_elapsed = elapsed
		if elapsed >= float(u.special.psi_fold_at) + float(u._seq.Undeploy.per)/FPS:
			u.special.erase("psi_elapsed")
			u.special.erase("psi_fire_at")
			u.special.erase("psi_fold_at")
		u.velocity = Vector2.ZERO
		u._request_pose_redraw()
		return true
	if u.special.has("prone_left"):
		u.special.prone_left -= delta
		u.special.prone_transition = maxf(0,float(u.special.get("prone_transition",0))-delta)
		if u.special.prone_left <= 0:
			u.special.erase("prone_left")
			u.special.erase("prone_transition")
		u._request_pose_redraw()
	if u.special.has("cheer_elapsed"):
		u.special.cheer_elapsed += delta
		u._request_pose_redraw()
	return false

static func pose(u) -> String:
	if u.special.has("psi_elapsed"):
		var frame := int(float(u.special.psi_elapsed)*FPS)
		if u.special.psi_elapsed>=u.special.psi_fold_at: return "Undeploy"
		return "Deploy" if frame<int(u._seq.Deploy.per) else "Deployed"
	if u.special.has("prone_left"):
		if u.special.prone_transition > 0: return "Down"
		if u.special.prone_left < float(u._seq.Up.per)/FPS: return "Up"
		if u._fire_anim_time >= 0: return "FireProne"
		return "Crawl" if u._moving() else "Prone"
	if u.special.has("cheer_elapsed"): return "Cheer"
	if u.special.get("shoveling",false): return "Shovel"
	if u.unit_id=="SLAV" and u.cargo>0 and u._moving(): return "Carry"
	return ""

static func frame(u,clip:String) -> int:
	match clip:
		"Deploy": return int(float(u.special.psi_elapsed)*FPS)
		"Deployed": return int(float(u.special.psi_elapsed)*FPS)-int(u._seq.Deploy.per)
		"Undeploy": return int((float(u.special.psi_elapsed)-float(u.special.psi_fold_at))*FPS)
		"Down": return maxi(0,int(u._seq.Down.per)-ceili(float(u.special.prone_transition)*FPS))
		"Up": return maxi(0,int(u._seq.Up.per)-ceili(float(u.special.prone_left)*FPS))
		"Crawl","Carry": return int(u._walk_phase*int(u._seq[clip].per))
		"FireProne": return int(u._fire_anim_time*16)
		"Cheer": return int(float(u.special.cheer_elapsed)*FPS)
		"Shovel": return int(u._anim*FPS)
	return 0

static func sequence_sound(u,clip:String,frame_index:int) -> void:
	var cue:Dictionary = u.data.sequence_sounds.get(clip,{})
	var previous:String = u.get_meta("native_sound_clip","")
	var last:int = u.get_meta("native_sound_frame",-1)
	if not cue.is_empty() and frame_index>=int(cue.frame) and (previous!=clip or last<int(cue.frame) or frame_index<last):
		Ra2Sfx.play(cue.sound,u.position)
	u.set_meta("native_sound_clip",clip)
	u.set_meta("native_sound_frame",frame_index)

static func gatling(u,delta:float) -> void:
	var levels:Array = u.data.elite_stages if u.veteran_level>=2 else u.data.stages
	var engaged:bool = AlliedAbilities.alive(u.attack_target) and u._weapon_target_valid(u.attack_target)
	var amount:float = u.data.rate_up if engaged else -float(u.data.rate_down)
	u.special.gatling_charge = clampf(float(u.special.get("gatling_charge",0))+delta*FPS*amount,0,float(levels[2]))
	var previous:=int(u.special.get("barrel_phase",0))
	if u.HollywoodTurrets.spin(u,delta,u.special.gatling_charge,levels)!=previous: u.queue_redraw()
	u._refresh_weapon_derived()

static func gun_at_stage(u,airborne:bool) -> Dictionary:
	var levels:Array = u.data.elite_stages if u.veteran_level>=2 else u.data.stages
	var charge:float = u.special.get("gatling_charge",0)
	var stage := 2 if charge>=levels[1] else (1 if charge>=levels[0] else 0)
	var guns:Array = u.data.elite_guns if u.veteran_level>=2 else u.data.guns
	return guns[stage*2+int(airborne)]

static func choose(u,target) -> Dictionary:
	if u.unit_id=="YTNK": return gun_at_stage(u,is_instance_valid(target) and target is Unit and target.is_air_target())
	if is_instance_valid(target):
		var armor := Ra2Damage.armor_of(target)
		if GameData.ra2_verse(u.weapon.ra2_warhead,armor)==0 and GameData.ra2_verse(u.data.secondary_weapon.ra2_warhead,armor)>0:
			return u.data.secondary_weapon
	return u.weapon
