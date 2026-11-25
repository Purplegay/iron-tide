extends Node
## All non-expedition battle modes share a dedicated, recoverable automatic slot.
## Count active real seconds, independent of combat speed; never save paused/results.
const INTERVAL := 60.0
var world
var elapsed := 0.0

func setup(battle) -> void:
	world = battle

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.ended or world.paused or get_tree().paused: return
	# Expedition owns its checkpoint and reinforcement state; do not save it twice.
	if preload("res://scripts/expedition/rules.gd").active(): return
	elapsed += BattleClock.control_delta(delta)
	if elapsed < INTERVAL: return
	elapsed = 0.0
	var result: Dictionary = BattleSaves.save_slot(world, "auto")
	if not result.ok:
		Events.emit_message("自动保存失败：" + result.message, Color.ORANGE)
