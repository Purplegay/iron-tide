extends "res://tests/base_recovery_regression.gd"
const Leases = preload("res://scripts/world/held_sight_leases.gd")

func expected_mask(source: Dictionary, size: int, clock: float) -> PackedByteArray:
	var cells:=PackedByteArray();cells.resize(size);cells.fill(0)
	for index in source.keys():
		if clock >= float(source[index]): source.erase(index)
		else: cells[int(index)]=1
	return cells

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for variant in 12:
		var index=Leases.new()
		var actual:Dictionary={}
		var expected:Dictionary={}
		for tick in 100:
			var clock:=tick*0.1
			if tick in [15,40,70]:
				actual={0:clock+0.1,"0":clock+1.0,1:clock-0.1}
				expected=actual.duplicate()
			if tick==25:
				actual.clear();expected.clear()
			var changed: Array=[]
			var deadline:=clock+0.15+variant*0.05
			for n in 8:
				var cell: int=(tick*7+n*3+variant)%64
				actual[cell]=deadline;expected[cell]=deadline
				changed.append(cell)
			if variant%2==0: index.record(actual,changed,deadline)
			# Same-cardinality edits and deletion bypass the derived index.
			if tick%7==0:
				actual[3]=clock-0.1;expected[3]=clock-0.1
				actual.erase(4);expected.erase(4)
			var cells:PackedByteArray=index.expire(actual,64,clock)
			check(cells==expected_mask(expected,64,clock),"mask follows live deadlines "+str([variant,tick]))
			check(actual==expected,"authoritative table and exact expiry "+str([variant,tick]))
			cells.fill(0)
			check(index.expire(actual,64,clock)==expected_mask(expected,64,clock),"returned mask is independent")
		check(index.expire(actual,64,1000).count(1)==0 and actual.is_empty(),"all leases expire")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	get_tree().quit(0 if failed==0 else 1)
