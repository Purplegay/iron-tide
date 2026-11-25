extends "res://tests/allied_abilities_regression.gd"
const Outline = preload("res://scripts/ui/unit_selection_outline.gd")

func exercise_mode(mode: String) -> void:
	setup_logistics_scene(mode,"美国")
	if battle.fog != null: battle.fog.free(); battle.fog=null
	battle.camera.position=Vector2(1700,1600)
	battle.camera.reset_smoothing(); battle.camera.force_update_scroll()
	var a=actor("MTNK","ally",Vector2(1500,1600))
	var b=actor("E1","ally",Vector2(1500,1700))
	var target=actor("HTNK","enemy",Vector2(1700,1600))
	var other=actor("E2","enemy",Vector2(1800,1600))
	a.order_target(target,false,false); b.order_target(target,false,false)
	battle.attack_target_outlines.refresh(battle)
	check(target.has_meta(Outline.ATTACK_META) and not a.has_meta(Outline.ATTACK_META),mode+": actual attack order marks target, not attacker")
	check(battle.attack_target_outlines.marked.size()==1,mode+": multiple attackers share one target outline")
	await get_tree().process_frame; await get_tree().process_frame
	var root=target.get_node_or_null("SelectionOutline")
	check(root!=null and root.visible and root.used==2,mode+": actual enemy tank draw captures hull and turret")
	if root!=null:
		check(root.get_child(0).material.get_shader_parameter("outline_color")==Outline.ATTACK_COLOR,mode+": attack target uses red silhouette")
	a.order_stop(); battle.attack_target_outlines.refresh(battle)
	check(target.has_meta(Outline.ATTACK_META),mode+": one attacker stopping retains remaining attack")
	b.order_target(other,false,false); battle.attack_target_outlines.refresh(battle)
	check(not target.has_meta(Outline.ATTACK_META) and other.has_meta(Outline.ATTACK_META),mode+": switched target transfers outline")
	check(root==null or not root.visible,mode+": old target silhouette is cleared immediately")
	other.special.echo_cloaked=true; battle.attack_target_outlines.refresh(battle)
	check(not other.has_meta(Outline.ATTACK_META),mode+": concealed target is not exposed by outline")
	other.special.erase("echo_cloaked"); battle.attack_target_outlines.refresh(battle)
	b.order_stop(); battle.attack_target_outlines.refresh(battle)
	check(battle.attack_target_outlines.marked.is_empty(),mode+": stop clears final target")
	# AI attacks never reveal its target choice on the player's screen.
	target.order_target(a,false,false); battle.attack_target_outlines.refresh(battle)
	check(not a.has_meta(Outline.ATTACK_META),mode+": enemy AI target does not acquire player attack outline")
	var building=battle._place_building("GAPOWR","enemy",Vector2(1700,1750),true)
	building._buildup_play=-1
	a.order_target(building,false,false); battle.attack_target_outlines.refresh(battle)
	await get_tree().process_frame; await get_tree().process_frame
	var structure=building.get_node_or_null("SelectionOutline")
	check(structure!=null and structure.visible and structure.used>0,mode+": actual building art is outlined")
	if structure!=null:
		check(structure.color==Outline.ATTACK_COLOR and structure.transform==Transform2D(Iso.eff_angle(),Iso.up(),0,Vector2.ZERO),mode+": building outline uses body projection and attack color")
	# Ordinary green selection is retained when the last red attack ends.
	target.set_selected(true); a.order_target(target,false,false)
	battle.attack_target_outlines.refresh(battle)
	Outline.begin(target); Outline.capture(target,target._ra2.tex,Rect2(-20,-40,40,40),RA2Art.src_rect(target._ra2,0)); Outline.end(target)
	check(root.color==Outline.ATTACK_COLOR,mode+": target red takes precedence over green selection")
	a.order_stop(); battle.attack_target_outlines.refresh(battle)
	Outline.begin(target); Outline.capture(target,target._ra2.tex,Rect2(-20,-40,40,40),RA2Art.src_rect(target._ra2,0)); Outline.end(target)
	check(root.visible and root.get_child(0).material.get_shader_parameter("outline_color")==Outline.COLOR,mode+": ending attack restores green selection without changing texture")
	a.order_target(building,false,false); battle.attack_target_outlines.refresh(battle)
	building._die(null,true)
	check(structure==null or not structure.visible,mode+": building death clears outline immediately")
	battle.attack_target_outlines.refresh(battle)
	check(not battle.attack_target_outlines.marked.has(building),mode+": dead target removed from tracker")
	a.order_target(other,false,false); battle.attack_target_outlines.refresh(battle)
	battle.ended=true; battle.attack_target_outlines.refresh(battle)
	check(battle.attack_target_outlines.marked.is_empty() and not other.has_meta(Outline.ATTACK_META),mode+": battle end clears target indicators")
	screen.free(); Ra2Sfx.stop_all(); Music.stop()
	await get_tree().process_frame
