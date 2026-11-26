extends Node
## All non-expedition battle modes share a dedicated, recoverable automatic slot.
## Count active real seconds, independent of combat speed; never save paused/results.
const INTERVAL := 60.0
var world
var elapsed := 0.0

var trace

func setup(battle, battle_trace = null) -> void:
	world = battle
	trace = battle_trace

func _process(delta: float) -> void:
	if not is_instance_valid(world) or world.ended or world.paused or get_tree().paused: return
	# Expedition owns its checkpoint and reinforcement state; do not save it twice.
	if preload("res://scripts/expedition/rules.gd").active(): return
	elapsed += BattleClock.control_delta(delta)
	if elapsed < INTERVAL: return
	elapsed = 0.0
	if trace != null:
		trace.mark("autosave.begin")
	var result: Dictionary = BattleSaves.save_slot(world, "auto")
	if trace != null:
		trace.mark("autosave.end", {"ok": result.ok})
	if not result.ok:
		Events.emit_message("自动保存失败：" + result.message, Color.ORANGE)
