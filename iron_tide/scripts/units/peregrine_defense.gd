extends RefCounted
const P=preload("res://scripts/rules/progression_parameters.gd")
const R=preload("res://scripts/units/expansion_rules.gd")
const KEY="peregrine"
const OPEN_RANK=5
const DEFENSE_DEFAULT = [
	"离场余速：真实打空弹仓后移速 +20%，持续 3 秒；每个补满周期一次，与其他来源相加，不强迫移动。",
	"诱饵抛投：每个补满周期一次，使首枚进入本人 1 格的可诱导防空追踪导弹失效；不拦截必中弹、激光、子弹或范围爆炸。",
	"检修签章：本周期普通导弹或 W 实际命中过真实敌作战目标后，每次真实补满恢复最大生命 5%；无需机场，对空机炮不计。",
	"抗扰飞控：每个补满周期一次抵消新施加的计时 EMP／眩晕，随后 2 秒不能开火或施放 W，仍能移动；不解除已有控制或持续冻结。",
	"停机护罩：按 J 在同方有效机场 3 格内合法空地下降维护；1 秒落地，20% 护盾持续 10 秒、间隔 30 秒。停火且连续 3 秒未受敌伤后每秒回复 2%，自补弹继续；再次 J 或移动起飞，不占机场位。",
	"迫降返修：每局一次普通致命伤触发时立即获得正常最大生命 1000% 耐久，向附近 4 格内陆地迫降；过渡 1 秒仍可受伤，落地不重置耐久。同方工程师连续维修 5 秒或落地后等待 180 秒，恢复正常 100% 生命，空弹起飞；机体被毁不复活，碾压、擦除或强制处决不触发迫降。"
]
static var DEFENSE:Array:
	get:return P.traits("hero/ORCA/survival",DEFENSE_DEFAULT)

static func rank(unit) -> int:
	if not is_instance_valid(unit) or not unit is Unit or unit.special.get("academy_hero")!="ORCA" or not unit.special.has(KEY) or not R.active(unit):return -1
	return clampi(int(unit.special.get("hero_survival_rank",0)),0,5)

static func silent(unit) -> bool:
	return float(unit.special.get(KEY,{}).get("steady_left",0))>0 or unit.special.get(KEY,{}).has("maintenance") or unit.special.has("hero_wreck")

static func tick(unit,dt:float) -> void:
	var s:Dictionary=unit.special[KEY]
	var redraw:bool=s.has("steady_left") or s.has("decoy_flash")
	R.timer(s,"steady_left",dt)
	R.timer(s,"decoy_flash",dt)
	if redraw:unit.queue_redraw()

static func filled(unit) -> void:
	var s:Dictionary=unit.special[KEY]
	s.decoy_ready=true;s.control_ready=true
	if rank(unit)>=2 and s.get("hits",false) and not unit.special.has("hero_wreck"):
		unit.heal(unit.max_hp*P.number("hero/ORCA/survival","refill_heal"))

static func resist(unit,seconds:float,status:String) -> bool:
	if seconds<=0 or not is_finite(seconds) or status not in ["stun","tesla_emp"] or rank(unit)<3 or unit.special.has("hero_wreck"):return false
	var s:Dictionary=unit.special[KEY]
	if not s.get("control_ready",true):return false
	s.control_ready=false;s.steady_left=P.number("hero/ORCA/survival","control_silence")
	unit._cancel_burst()
	unit.queue_redraw()
	return true

static func deflect(projectile,next:Vector2) -> bool:
	var unit=projectile.target
	if rank(unit)<1 or unit.special.has("hero_wreck") or not unit.is_air_target():return false
	# Imported RA2 guided weapons use the generic shell damage category too;
	# flight flags determine guidance, not the damage category name.
	if not projectile.ra2_homing or not projectile.ra2_aa or projectile.ra2_inviso or projectile.ra2_arcing or projectile.attack_type not in ["missile","shell"]:return false
	if projectile._detonated or projectile.is_queued_for_deletion() or BattleRequest.friendly(unit.side,projectile.owner_side):return false
	# Guaranteed hunting rounds live in their own world event stream and never
	# enter this native guided-missile path. Respect explicit protected payloads.
	if projectile.attacker_bonus.get("uninterceptable",false) or projectile.attacker_bonus.get("peregrine_hunt",false):return false
	var s:Dictionary=unit.special[KEY]
	if not s.get("decoy_ready",true):return false
	var nearest:=Geometry2D.get_closest_point_to_segment(unit.global_position,projectile.global_position,next)
	if nearest.distance_to(unit.global_position)>P.number("hero/ORCA/survival","decoy_radius")*R.CELL:return false
	s.decoy_ready=false;s.decoy_flash=.35
	projectile.splinters.peregrine_deflected=true
	projectile._detonated=true
	Projectile.Visual.detach(projectile)
	var world=R.world(unit)
	if world!=null and world.position_visible_to("ally",unit.position):
		var from:Vector2=nearest+RA2Art.art_dir(Vector2(0,-unit._visual_lift()))
		var to:Vector2=from+Vector2.from_angle(projectile._heading.angle()+PI*.5)*28
		Effects.spawn_beam(from,to,Color(1,.75,.3),"laser",2,.18)
		Effects.spawn_impact(to,Color(1,.8,.4),9)
	projectile.queue_free();unit.queue_redraw()
	return true

static func draw(unit) -> void:
	var s:Dictionary=unit.special[KEY]
	var center:=Vector2(0,-unit._visual_lift())
	if float(s.get("decoy_flash",0))>0:
		for direction in [-1,1]:unit.draw_line(center,center+Vector2(direction*32,15),Color(1,.8,.4,.8),2,true)
	if float(s.get("steady_left",0))>0:unit.draw_arc(center,unit.radius+10,0,TAU,28,Color(.85,.8,1,.8),1.5,true)
	if s.has("maintenance_shield"):unit.draw_arc(center,unit.radius+13,0,TAU,28,Color(.4,1,.65,.8),2,true)

static func entries(unit) -> Array:
	var level:=rank(unit)
	if level<1:return []
	const V=preload("res://scripts/units/expansion_visual.gd")
	var s:Dictionary=unit.special[KEY]
	var rows:Array=[V.row("诱饵抛投 · "+("本周期可用" if s.get("decoy_ready",true) else "等待补满"),0,false,"guard")]
	if level>=2:rows.append(V.row("检修签章 · "+("补满将回复 5%" if s.get("hits",false) else "等待普通导弹／W有效命中"),0,false,"heart"))
	if level>=3:rows.append(V.row("抗扰飞控 · "+("本周期可用" if s.get("control_ready",true) else "等待补满"),0,false,"guard"))
	if float(s.get("steady_left",0))>0:rows.append(V.row("应急稳姿 · 禁止开火，仍可移动",s.steady_left,false,"guard"))
	return rows
