extends "res://tests/expedition_regression.gd"

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	Expedition.state={}
	MetaProgress.reset_save()
	await preload("res://tests/expedition_income_cases.gd").run(self)
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed},"  "))
	print("EXPEDITION INCOME checks=",checks.size()," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
