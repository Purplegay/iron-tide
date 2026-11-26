extends Node

const Policy = preload("res://scripts/units/yr_blockage_policy.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var q := Policy.new()
	var goal := Vector2(500, 500)
	var dt := 1.0 / BattleClock.RULE_TICKS_PER_SECOND
	var retries := 0
	for i in range(60):
		var result := q.tick(i, dt, goal, true, false, 200.0)
		if result == Policy.Action.RETRY: retries += 1
		check(result == (Policy.Action.RETRY if i > 0 and i % 9 == 0 else Policy.Action.WAIT), "short retry cadence " + str(i))
		check(q.tick(i, dt, goal, true, false, 200.0) == Policy.Action.WAIT, "same-tick duplicate merges " + str(i))
	check(retries == 6 and q.tick(60, dt, goal, true, false, 200.0) == Policy.Action.DETOUR, "short retries do not postpone full detour")
	check(q.tick(60, dt, goal, true, false, 200.0) == Policy.Action.WAIT, "detour cannot execute twice in one step")
	check(q.tick(61, dt, goal, false, true, 0.0) == Policy.Action.CLEAR, "clear route resumes immediately")
	check(q.tick(62, dt, goal, true, true, 0.0) == Policy.Action.WAIT, "new obstruction starts fresh")
	for i in range(63, 71): q.tick(i, dt, goal, true, true, 0.0)
	check(q.tick(71, dt, goal, true, true, Policy.CLOSE_DISTANCE) == Policy.Action.RETRY, "strict CloseEnough threshold")
	for i in range(72, 80): q.tick(i, dt, goal, true, true, 0.0)
	check(q.tick(80, dt, goal, true, true, Policy.CLOSE_DISTANCE - 0.1) == Policy.Action.FINISH, "confirmed blockage close enough")
	check(q.tick(80, dt, goal + Vector2.ONE, true, true, 0.0) == Policy.Action.WAIT, "new destination replaces pending task")
	var u := Unit.new()
	u.setup(GameData.get_unit("MTNK").duplicate(true), "ally", Vector2(100,100))
	u.has_move_order = true
	u.move_target = Vector2(200,100)
	u.special.hollywood_deck_goal = u.move_target
	u._blocked_move_goal = u.move_target
	check(not u._at_order_layer(), "under-deck destination is not reached at ground level")
	check(u._ordinary_move_blockage(dt) == Policy.Action.CLEAR, "old path failure is not a live traffic block")
	u.special[u._local_traffic.CONGESTION] = {"passing": false}
	check(u._ordinary_move_blockage(dt) == Policy.Action.WAIT, "confirmed blocked ground move uses policy")
	u.attack_move = true
	check(u._ordinary_move_blockage(dt) == Policy.Action.CLEAR, "attack move keeps original path recovery")
	u.attack_move = false
	u.order_stop()
	check(u._ordinary_move_blockage(dt) == Policy.Action.CLEAR, "stop clears pending move blockage")
	u.free()
	print("YR blockage rules: ", checks, " checks, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
