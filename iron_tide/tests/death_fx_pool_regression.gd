extends Node
const Fx=preload("res://scripts/core/yr_death_fx.gd")
class Arena extends Node:
	var effects_root := Node2D.new()
	var paused := true
	var ended := false
	var sight := false
	func position_visible_to(_side,_point): return sight
var failures := 0
var checks := 0
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		print("FAIL ",label)
func _ready():
	var w := Arena.new(); add_child(w); w.add_child(w.effects_root)
	var ids: Array = Fx.Rules.data().animations.keys()
	var a = Fx.play(w,Vector2(3,4),ids[0],true)
	var recycled_id: int = a.get_instance_id()
	a.expiry=""; a.lift=-10; a._process(0.01)
	w.paused=false; a._process(0.01); w.paused=true
	await get_tree().process_frame
	await get_tree().process_frame
	check(a.get_parent()==w.get_node("__IdleDeathEffects"),"parked")
	check(not a.is_processing() and not a.visible and not a.is_in_group("yr_death_effects"),"inactive")
	check(a.texture==null and a.playback.is_empty(),"released assets")
	var b=Fx.play(w,Vector2(11,12),ids[1],false)
	check(b.get_instance_id()==recycled_id,"reuse ID")
	check(b.age==0 and b.lift==0 and b.velocity==Vector2.ZERO and b.vertical_speed==0 and b.expiry=="" and not b.debris,"reset motion")
	check(b.frame==b.playback[0] and b.position==Vector2(11,12) and b.texture!=null and b.is_processing() and not b.visible,"reset playback and fog")
	var nodes := [b]
	for i in 79: nodes.append(Fx.play(w,Vector2.ZERO,ids[1],false))
	check(w.effects_root.get_child_count()==80,"active uncapped")
	for fx in nodes: fx.retire()
	await get_tree().process_frame
	await get_tree().process_frame
	check(w.get_node("__IdleDeathEffects").get_child_count()==64 and w.effects_root.get_child_count()==0,"idle cap")
	check(get_tree().get_nodes_in_group("yr_death_effects").is_empty(),"no active group")
	w.sight=true
	var fresh=Fx.play(w,Vector2.ZERO,ids[0],true)
	check(fresh.visible and fresh.debris and fresh.lift==12,"visible flying reuse")
	w.free()
	var survivors:=0
	for fx in nodes:
		if is_instance_valid(fx):survivors+=1
	check(survivors==0,"no survivors")
	print("POOL_CHECK ",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
