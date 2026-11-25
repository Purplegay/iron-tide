extends "res://tests/bridge_queue_regression.gd"

func exercise(mode: String) -> void:
	for house in ["ally","enemy"]:
		await exercise_column(mode,house,15,3.0)
