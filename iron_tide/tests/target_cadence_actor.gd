extends Unit
var scans:=0
var shots:=0
func _refresh_target()->void:
	scans+=1
	if not AlliedAbilities.alive(attack_target):attack_target=null
func _fire_shot(_target)->void:
	shots+=1
