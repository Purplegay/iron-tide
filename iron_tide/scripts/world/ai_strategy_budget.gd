extends RefCounted
## Spread due strategic house decisions over rendered frames. Never gates unit
## physics, combat, mining, income, existing orders, or player commands.
var frame := -1
var owner := ""
var deferred := 0
var waiting: Array[String] = []
var grants_by_house: Dictionary = {}

func claim(house: String, current_frame: int) -> bool:
	if frame != current_frame:
		frame = current_frame
		owner = ""
	if owner == house: return true
	if not waiting.has(house): waiting.append(house)
	# A lower scene-order house may already be overdue. Reserve the next slot
	# for the oldest request instead of letting the first caller take every frame.
	if owner.is_empty() and waiting[0] == house:
		waiting.pop_front()
		owner = house
		grants_by_house[house] = int(grants_by_house.get(house,0)) + 1
		return true
	deferred += 1
	return false

func forget(house: String) -> void:
	waiting.erase(house)

func diagnostics() -> Dictionary:
	return {"deferred_requests":deferred,"grants_by_house":grants_by_house.duplicate(),"pending_houses":waiting.duplicate()}
