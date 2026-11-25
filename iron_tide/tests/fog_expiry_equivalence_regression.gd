extends "res://tests/base_recovery_regression.gd"
const Fog = preload("res://scripts/world/fog_of_war.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for variant in 12:
		for clock in [0.0,1.0,4.999999,5.0,5.000001,10.0]:
			var expected=fixture(variant,clock)
			var actual=fixture(variant,clock)
			var original_tables: Dictionary=actual.sight_until.duplicate()
			var explored: Dictionary=actual.explored_cells.duplicate(true)
			reference_expire(expected)
			actual._expire_held_sight()
			check(actual.visible_cells==expected.visible_cells and actual.sight_until==expected.sight_until,"expiry matches original per-observer traversal "+str([variant,clock]))
			check(actual.explored_cells==explored,"expiry preserves explored terrain")
			for side in actual.sight_until:
				check(is_same(actual.sight_until[side],original_tables[side]),"retained observer dictionary identity "+side)
			if variant!=11:
				actual.sight_until.ally[63]=1000.0
				actual.visible_cells.ally[63]=1
				check(not actual.sight_until.ai2.has(63) and actual.visible_cells.ai2[63]==0,"later observer writes stay independent")
			actual.sight_clock=11.0;expected.sight_clock=11.0
			if variant!=11: actual.sight_until.ally.erase(63)
			reference_expire(expected);actual._expire_held_sight()
			check(actual.visible_cells==expected.visible_cells and actual.sight_until==expected.sight_until,"second expiry after independent reveal matches reference")
			actual.free();expected.free()
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)

func fixture(variant: int, clock: float):
	var fog=Fog.new()
	fog.width=8;fog.sight_clock=clock
	fog.sight_until={}
	for side in ["ally","ai2","ai3","enemy","ai4","ai5"]:
		var cells:=PackedByteArray();cells.resize(64);cells.fill(1)
		fog.visible_cells[side]=cells
		fog.explored_cells[side]=cells.duplicate()
		var held := {}
		var indices := range(32)
		if side=="ai2": indices.reverse()
		for i in indices: held[i]=[1.0,5.0,10.0][i%3]
		if variant==1 and side=="enemy": held.clear()
		if variant==2 and side=="ai2": held[2]=5.000001
		if variant==3 and side=="ai3": held.erase(3)
		if variant==4 and side=="ally": held[45]=10.0
		if variant==5: held.clear()
		if variant>=6 and variant<=10:
			for i in range(variant): held[i]=float(side.hash()%7)+float(i)*0.01
		fog.sight_until[side]=held
	if variant==11: fog.sight_until.ai2=fog.sight_until.ally
	return fog

func reference_expire(fog) -> void:
	# Frozen original loop: no equality grouping and no copied results.
	for side in fog.visible_cells:
		var cells: PackedByteArray=fog.visible_cells[side]
		cells.fill(0)
		var held: Dictionary=fog.sight_until[side]
		for index in held.keys():
			if fog.sight_clock>=float(held[index]): held.erase(index)
			else: cells[int(index)]=1
		fog.visible_cells[side]=cells
