extends RefCounted
## EP1 Weapon.xml / SovietCrushWeapon; the separate harpoon uses its own weapons.
const CRUSHER_LEVEL:=30
# BaseVehicle.CrusherInfo DefaultCrushKillDelay, inherited by the Apocalypse.
const KILL_DELAY:=1.5
const DAMAGE:=999999.0
const SPEED_AFTER_CRUSH:=0.2

static func target_level(target) -> int:
	if target is Building:return 25 if WallArt.is_wall(target.data) else 40
	if MetaProgress.Academy.crush_immune(target):return CRUSHER_LEVEL
	if target.unit_id in ["R3APOC","R3FUTURE"]:return 31
	# YR has no numeric CrusherInfo. Respect heavy-crush immunity in mixed games.
	if AlliedAbilities.flag(target,"OmniCrushResistant") or target.unit_id in ["APOC","BFRT"]:return 31
	return 10 if AlliedAbilities.infantry(target) else 20

static func eligible(tank,target) -> bool:
	if not is_instance_valid(target) or not (target is Unit or target is Building) or not AlliedAbilities.alive(target):return false
	# IGNORE_WALL_RELATIONSHIP permits walls of either side.
	if BattleRequest.friendly(target.side,tank.side) and not (target is Building and WallArt.is_wall(target.data)):return false
	if target is Unit and (target.embarked_in!=null or target.is_air or target.is_naval):return false
	return target_level(target)<CRUSHER_LEVEL

# Return true when the tracks are still pressing against this victim.
static func contact(tank,step:Vector2,delta:float) -> bool:
	if step.is_zero_approx() or tank._stun_timer>0 or tank.repairing or AlliedAbilities.frozen(tank):
		tank.special.erase("rolling_crush")
		return false
	var hit:KinematicCollision2D=tank.move_with_traffic_exceptions(step,true)
	if hit==null or step.dot(hit.get_normal())>=0 or not eligible(tank,hit.get_collider()):
		tank.special.erase("rolling_crush")
		return false
	var target=hit.get_collider()
	var pending:Dictionary=tank.special.get("rolling_crush",{})
	if pending.get("target")!=target:
		pending={"target":target,"elapsed":0.0}
		tank.special.rolling_crush=pending
	else:
		pending.elapsed+=delta
	if float(pending.elapsed)+0.000001<KILL_DELAY:
		# Advance to contact without sliding around the victim during the crush.
		tank.move_with_traffic_exceptions(step)
		return true
	tank.special.erase("rolling_crush")
	target.receive_hit(DAMAGE,"crush",{},tank,"RA3_EXPANSION")
	if not AlliedAbilities.alive(target):
		tank.velocity*=SPEED_AFTER_CRUSH
		tank._spd_cur*=SPEED_AFTER_CRUSH
	return false
