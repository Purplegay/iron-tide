extends Node
const Pacing = preload("res://scripts/world/battle_frame_pacing.gd")
var checks: Array = []
var failed := 0

func check(ok: bool, name: String, details = null) -> void:
	checks.append({"passed":ok,"name":name,"details":details})
	if not ok:
		failed += 1
		print("FAIL ",name," ",details)

func _ready() -> void:
	var out := OS.get_environment("IRON_TIDE_REPORT_DIR")
	if out.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	await rotating_admission(3, 4)
	await rotating_admission(2, 8)
	await idle_head_expires()
	var pacing := Pacing.new()
	check(pacing.allow_stuck_retry(1) and not pacing.allow_stuck_retry(2,false),"healthy load honors AI admission without delaying retries")
	pacing.free()
	FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed == 0 else 1)

func rotating_admission(tier: int, budget: int) -> void:
	var pacing := Pacing.new()
	pacing.tier = tier
	var granted := {}
	var last_grant := {}
	var max_wait := 0
	var budget_ok := true
	var admission_ok := true
	for frame in 96:
		await get_tree().process_frame
		var count := 0
		for actor in 32:
			# Units receive outer AI slots on different frames. All stalled units
			# still refresh their retry request, including those awaiting admission.
			var admitted := actor / 4 == frame % 8
			var allowed := pacing.allow_stuck_retry(actor,admitted)
			if not allowed: continue
			admission_ok = admission_ok and admitted
			count += 1
			granted[actor] = int(granted.get(actor,0)) + 1
			max_wait = maxi(max_wait,frame-int(last_grant.get(actor,0)))
			last_grant[actor] = frame
		budget_ok = budget_ok and count <= budget
	var repeated := granted.size() == 32
	for count in granted.values(): repeated = repeated and count >= 8
	check(repeated,"tier "+str(tier)+" rotating AI slots cannot starve any stalled unit",granted)
	check(max_wait <= 16,"tier "+str(tier)+" retry wait stays bounded",max_wait)
	check(budget_ok and admission_ok,"tier "+str(tier)+" preserves retry budget and outer AI admission")
	# Consecutive physics steps in one render must share the same budget.
	pacing._retry_waiting.clear()
	pacing._retry_grants.clear()
	for actor in 16: pacing._retry_waiting[actor] = Engine.get_physics_frames()
	var count := 0
	for repeat in 2:
		for actor in 16:
			if pacing.allow_stuck_retry(actor): count += 1
	check(count <= budget,"tier "+str(tier)+" catch-up steps share one render budget",count)
	pacing._retry_waiting.clear()
	pacing._retry_grants.clear()
	pacing._retry_waiting[100] = Engine.get_physics_frames()
	var first := pacing.allow_stuck_retry(100)
	pacing.allow_stuck_retry(100)
	check(first and not pacing.allow_stuck_retry(100),"tier "+str(tier)+" one actor cannot consume multiple retries in the same render")
	pacing.free()

func idle_head_expires() -> void:
	var pacing := Pacing.new()
	pacing.tier = 3
	pacing.allow_stuck_retry(100,false)
	var released := false
	for i in 8:
		await get_tree().physics_frame
		released = pacing.allow_stuck_retry(101) or released
	check(released,"a stopped or removed queue head expires without blocking live followers")
	pacing.free()
