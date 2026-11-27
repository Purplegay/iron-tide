extends Node

const Driver = preload("res://scripts/world/allied_retail_script.gd")
const FIRST := "yr_all01umd"
const LAST := "yr_all07smd"
const CHECKPOINT := "user://allied_retail_checkpoint.json"
var failures := 0
var checks := 0
var facts := {}

func verify(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", message)

func query(row: Dictionary, event: Array) -> bool:
	return facts.get(row.id + ":" + event[0] + ":" + event[2], false)

func drain(driver, seconds: float) -> Array:
	var seen := []
	var command: Dictionary = driver.advance(seconds, query)
	while not command.is_empty() and seen.size() < 64:
		if int(command.opcode) in [7, 107, 125]:
			var placement: Dictionary = driver.resolve_spawn(command)
			verify(not placement.is_empty() and placement.waypoint.uv.size() == 2, "world adapter receives a resolved retail spawn")
		seen.append(command)
		verify(driver.acknowledge(int(command.token)), "acknowledge expected token")
		command = driver.advance(0, query)
	verify(command.is_empty(), "finite trigger drain")
	return seen

func count(commands: Array, opcode: int) -> int:
	return commands.filter(func(c): return c.opcode == opcode).size()

func first() -> void:
	facts.clear()
	var d := Driver.new()
	verify(d.start(FIRST, 1), "start supported retail scenario")
	verify(d.state.locals["25"] and not d.state.locals["49"], "retail local defaults")
	verify(d.enable("0691357C"), "camera sequence can arm power after handoff")
	facts["0691357c:58:0"] = true
	var opening := drain(d,0)
	var zero_time_teams := []
	for order in opening:
		if order.opcode==4: zero_time_teams.append(order.fields[2])
	zero_time_teams.sort()
	verify(zero_time_teams==["06B9CD4C","089305FC","08934B5C","096C680C","096FCB5C","0AEB68DC","0E0F469C"],"seven zero-time map team orders")
	verify(opening.size()==40 and count(opening,99)==32 and count(opening,48)==1 and not d.state.fired.has("0691357c"),"full power without owned plant cannot start")
	verify(d.set_local(49, true), "plant ownership fact sets local")
	facts["0691357c:58:0"] = false
	verify(drain(d, 0).is_empty(), "plant without full power cannot start")
	facts["0691357c:58:0"] = true
	var command := d.advance(0, query)
	verify(command.get("opcode") == 7 and command.fields[2] == "0DC53EFC", "first power action is original engineer reinforcement")
	verify(d.definition.teams["0dc53efc"].task_force["0"] == "1,ENGINEER", "retail engineer formation retained")
	verify(d.resolve_spawn(command).get("waypoint", {}).get("id") == 58, "first mission engineer uses retail waypoint BG")
	verify(not d.acknowledge(int(command.token) + 1), "stale token rejected")
	verify(d.advance(1000, query) == command and d.state.time == 0.0, "unacknowledged world command not skipped or timed through")
	verify(d.acknowledge(int(command.token)), "acknowledge reinforcement")
	var actions := drain(d, 0)
	verify(count(actions, 16) == 1 and d.state.locals["47"], "reveal and power-online local")
	verify(d.rows.has("0462b74c") and not d.state.enabled.has("0462b74c") and not d.state.fired.has("0462b74c"), "power cancels the now-wired hospital trigger before discovery")
	verify(drain(d, 1).any(func(c): return c.opcode == 14), "radar ownership emitted after original delay")
	actions = drain(d, 10)
	verify(actions.filter(func(c):return c.opcode==11 and c.trigger=="09515b9c").size()==1 and count(actions,11)==1 and count(actions,117)==0 and actions.filter(func(c):return c.trigger=="0c077bcc" and c.opcode==7).size()==2, "objective text precedes the movie delay")
	actions = drain(d, 1)
	verify(count(actions, 117) == 1, "original in-game film action after 12 simulated seconds")
	actions = drain(d, 5)
	verify(d.state.enabled.has("0c6f847c") and d.state.enabled.has("0a8e0e9c"), "movie schedules camera and travel concurrently")
	actions = drain(d, 11)
	verify(count(actions,46)==1 and count(actions,48)==1 and count(actions,139)==0, "camera precedes travel")
	actions = drain(d, 1)
	verify(count(actions, 127) == 1 and count(actions, 139) == 1, "time travel effects retain both retail actions")
	facts["08a3e03c:48:0"] = true
	verify(count(drain(d, 0), 68) == 1, "destroyed time machine before travel emits retail loss announcement")
	facts["08a3e03c:48:0"] = false
	verify(count(drain(d,1),111)==4,"four tagged evacuations at second one")
	actions = drain(d,3)
	verify(count(actions,119)==1 and count(actions,120)==1 and count(actions,121)==6 and count(actions,122)==3 and count(actions,130)==1,"original room cleanup and bridge actions")
	verify(count(drain(d,2),100)==1,"arrival film after room changes")
	verify(d.enable("089ec19c"), "arm post-travel dominator branch through battle adapter")
	facts["089ec19c:61:0"] = true
	verify(drain(d, 0).is_empty(), "dominator defeat starts delay instead of granting immediate win")
	verify(count(drain(d, 3), 113) == 1, "cheer follows dominator defeat")
	verify(count(drain(d, 7), 1) == 1 and drain(d, 20).is_empty(), "delayed victory exactly once")
	var report := Driver.new()
	report.start(FIRST,1)
	report.state.enabled.clear()
	report.enable("05e9106c")
	facts["0790df3c:61:0"] = true
	verify(count(drain(report,2),100)==1 and drain(report,34).is_empty(),"absence of APOC alone does not bypass the 35-second wait")
	var resumed := Driver.new()
	verify(resumed.restore(report.snapshot()),"resume Kirov delay with one second remaining")
	actions = drain(resumed,1)
	verify(actions.size()==1 and actions[0].fields[2]=="KirovCreated" and drain(resumed,35).is_empty(),"report fires at second 35 exactly once across restore")

func finale() -> void:
	facts.clear()
	var d := Driver.new()
	verify(d.start(LAST, 1), "terminal scenario starts")
	verify(d.state.locals["15"] and d.state.locals["27"], "finale retail locals retained, radar gate still checks building")
	d.enable("0a57f46c")
	verify(drain(d, 0).is_empty(), "no radar progress from pre-set local alone")
	facts["0b2eb76c:32:13"] = true
	var radar_commands := drain(d, 0)
	verify(radar_commands.size() == 1 and radar_commands[0].opcode == 54 and radar_commands[0].fields[2] == "08F6724C", "radar arms countdown and surfaces reminder cancellation")
	verify(not d.state.enabled.has("0a57f46c"), "radar cancels loss-of-Fireland-yard trigger")
	facts["0a57f46c:61:0"] = true
	verify(count(drain(d, 3), 21) == 1, "radar confirmation after delay")
	verify(drain(d, 116).is_empty(), "no jump at second 119")
	verify(count(drain(d, 1), 21) == 1, "countdown message at second 120")
	verify(drain(d, 14).is_empty(), "no MCV before additional 15 seconds")
	var mcv: Dictionary = d.advance(1, query)
	verify(mcv.get("opcode") == 107 and mcv.fields[2] == "0964C97C" and mcv.fields[7] == "AA", "MCV gets retail team and waypoint")
	verify(d.definition.teams["0964c97c"].task_force["0"] == "1,AMCV", "MCV actual retail unit")
	var spawn := d.resolve_spawn(mcv)
	verify(spawn.get("chrono") == true and spawn.waypoint.uv == [43.5,76.5], "MCV waypoint AA resolves to retail map coordinates")
	var file := FileAccess.open(CHECKPOINT, FileAccess.WRITE)
	verify(file != null, "checkpoint path available")
	if file != null:
		file.store_string(JSON.stringify(d.snapshot()))
		file.close()
	verify(d.acknowledge(int(mcv.token)), "MCV confirmed")
	var actions := drain(d, 0)
	verify(count(actions, 107) == 8 and count(actions, 125) == 2, "eight retail escort teams and exactly two Yuri superweapons")
	verify(actions.filter(func(c): return c.opcode == 125).map(func(c): return [c.fields[2],c.fields[7]]) == [["YAGNTC","GM"],["YAPPET","PD"]], "superweapons retain retail types and waypoints")
	verify(d.state.locals["23"], "MCV arrival sets local")
	facts["09000cdc:61:0"] = true
	facts["0900786c:61:0"] = true
	verify(drain(d, 19).is_empty(), "dominator destruction is not immediate victory")
	verify(count(drain(d, 1), 11) == 1, "switch to destroy all Yuri objective")
	facts["07ca72bc:9:9"] = true
	verify(drain(d, 10).is_empty(), "one remaining retail house condition still blocks victory")
	facts["07ca72bc:9:14"] = true
	verify(drain(d, 0).is_empty() and count(drain(d, 3), 113) == 1 and count(drain(d, 7), 1) == 1, "both original house checks, cheer and win")
	facts.clear()
	d.start(LAST, 1)
	d.enable("0a57f46c")
	facts["0a57f46c:61:0"] = true
	verify(count(drain(d, 0), 21) == 1 and drain(d, 4).is_empty(), "early Fireland yard loss warns first")
	verify(count(drain(d, 1), 2) == 1, "early yard loss is defeat after five seconds")
	facts.clear()
	d.start(LAST, 1)
	d.enable("08ed7a3c")
	facts["08ed7a3c:11:0"] = true
	verify(drain(d, 2).is_empty() and count(drain(d, 1), 2) == 1, "all-player-assets loss has original three-second gate")

func cold() -> void:
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHECKPOINT))
	verify(saved is Dictionary, "cold checkpoint exists")
	if not saved is Dictionary: return
	var d := Driver.new()
	verify(d.restore(saved), "cold restore rejects no retail data fields")
	var mcv := d.advance(999.0)
	verify(mcv.get("opcode") == 107 and mcv.fields[2] == "0964C97C", "pending unacknowledged MCV survives cold restore")
	if mcv.is_empty(): return
	verify(d.acknowledge(int(mcv.token)), "resume original token")
	var copied := Driver.new()
	verify(copied.restore(JSON.parse_string(JSON.stringify(d.snapshot()))), "resume between acknowledgement and next action")
	var rest := drain(copied, 0)
	verify(count(rest, 107) == 8 and count(rest, 125) == 2, "no duplicate MCV after restored acknowledgement")
	saved.hash = "wrong"
	verify(not d.restore(saved), "wrong retail hash rejected")

func _ready() -> void:
	if "--cold" in OS.get_cmdline_user_args():
		cold()
	else:
		first()
		if "--first-only" not in OS.get_cmdline_user_args(): finale()
	print("allied retail slice: ", checks - failures, "/", checks)
	get_tree().quit(1 if failures else 0)
