extends Projectile
# Original ready/physics entrypoints; remaining simulation is unchanged.
func _ready() -> void:
	if splinters.get("weapon_look","")==Effects.Looks.Sonar.ID and is_instance_valid(shooter()):
		Effects.Looks.Sonar.spawn(Effects._host(),global_position,true,global_position.direction_to(target_point))
	# Original Inviso projectiles snap to their target; hiding a travelling
	# projectile is not equivalent. Keep the same warhead/splash/kill-credit path.
	# Sonic waves own their separate advancing, repeated-damage simulation.
	if ra2_inviso and not is_sonic:
		global_position = target_point
		_explode()

func _physics_process(delta: float) -> void:
	var _call_log_scope = preload("res://scripts/world/battle_call_counters.gd").enter(36)
	if delta <= 0.0: return
	var steps := maxi(1, ceili(delta / (Engine.time_scale / 60.0) - 0.000001))
	var step := delta / steps
	for i in steps:
		if is_queued_for_deletion() or _detonated: break
		_advance_projectile(step)

func _process(_delta: float) -> void:
	pass
