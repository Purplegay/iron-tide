extends RefCounted
const R=preload("res://scripts/units/expansion_rules.gd")
const Q=preload("res://scripts/rules/expansion_contracts.gd")

static func prepare_death(target,source,bonus:Dictionary) -> void:
	target.special.erase("leizhu_killing_side")
	if not bonus.get("leizhu_primary",false) or bonus.get("expansion_extra",false) or bonus.get("equipment_secondary",false) or bonus.get("expansion_scatter",false):return
	var owner=R.owner(source)
	if not preload("res://scripts/units/leizhu.gd").active(owner) or owner.side!=bonus.get("leizhu_side"):return
	if source is Projectile and (source.target!=target or source.owner_side!=owner.side):return
	target.special.leizhu_killing_side=owner.side

static func killed(world,target) -> void:
	if target.special.get("leizhu_killing_side")!="ally" or not Q.eligible(world,"TTNK") or not Q.vehicle(target):return
	if target.side=="neutral" or BattleRequest.friendly("ally",target.side):return
	Q.progress(world,"TTNK").first+=1
