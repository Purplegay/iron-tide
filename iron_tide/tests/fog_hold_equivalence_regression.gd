extends "res://tests/base_recovery_regression.gd"
const Fog = preload("res://scripts/world/fog_of_war.gd")
const Reference = preload("res://tests/fog_hold_reference.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	BattleRequest.house_teams={"ally":0,"ai2":0,"ai3":0,"enemy":1,"ai4":1,"ai5":1}
	for variant in 10:
		for clock in [0.0,4.999,10.0]:
			var expected=fixture(Reference,variant,clock)
			var actual=fixture(Fog,variant,clock)
			var aliases:Dictionary=actual.sight_until.duplicate()
			var scouts:Dictionary=actual._scouts.duplicate(true)
			for id in scouts.keys():
				if id%5==0:scouts.erase(id)
				elif id%7==0:scouts[id].side="enemy"
				elif id%3!=0:scouts[id].point+=Vector2(80,-40)
			expected._hold_vacated_scouts(scouts,5.0)
			actual._hold_vacated_scouts(scouts,5.0)
			check(actual.sight_until==expected.sight_until,"exact hold deadlines "+str([variant,clock]))
			check(actual.visible_cells==expected.visible_cells,"exact current sight")
			check(actual.explored_cells==expected.explored_cells,"exact exploration")
			for side in aliases:check(is_same(aliases[side],actual.sight_until[side]),"retain observer dictionary identity")
			actual.sight_clock+=5.0;expected.sight_clock+=5.0
			actual._expire_held_sight();expected._expire_held_sight()
			check(actual.sight_until==expected.sight_until and actual.visible_cells==expected.visible_cells,"exact expiry boundary")
			actual.free();expected.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func fixture(script,variant:int,clock:float):
	var fog=script.new()
	fog.width=64;fog.sight_clock=clock;fog.sight_until={}
	for side in BattleRequest.house_teams:
		var cells:=PackedByteArray();cells.resize(4096);cells.fill(0)
		fog.visible_cells[side]=cells
		fog.explored_cells[side]=cells.duplicate()
		var held:Dictionary={1:2.0,4:100.0,81:4.999}
		if variant%3==1 and side=="ai2":held[5]=12.0
		if variant%3==2 and side=="ai3":held.erase(1)
		fog.sight_until[side]=held
		if variant>=3 and side=="ai2":fog.visible_cells[side][31]=1
		if variant>=6 and side=="ai3":fog.explored_cells[side][57]=1
	if variant==9:fog.sight_until.ai2=fog.sight_until.ally
	for i in 80:
		fog._scouts[i]={"side":BattleRequest.house_teams.keys()[i%6],"point":Vector2((i*131)%2400,(i*193)%2400),"radius":float(80+(i%5)*40)}
	return fog
