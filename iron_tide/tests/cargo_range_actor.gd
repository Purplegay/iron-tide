extends Unit
var domain_calls:=0
func _weapon_domain_valid(target,check_cover:=false,resolved_weapon:Dictionary={}) -> bool:
	domain_calls+=1
	return super._weapon_domain_valid(target,check_cover,resolved_weapon)
