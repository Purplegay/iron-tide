extends RefCounted
const Demo=preload("res://scripts/ui/lost_missile_demo.gd")
const Talents=preload("res://scripts/units/expansion_talents.gd")

static func run(t) -> void:
	t.start(MatchRules.EXTENDED)
	var launcher=t.battle.spawn_unit("V3","ally",Vector2(1000,1200))
	var enemy=t.battle.spawn_unit("FV","enemy",Vector2(1500,1200))
	for rank in 4:
		BattleRequest.combat_context.unit_talents.V3={"lost_missile":rank}
		var before:=Demo.sample(1.9,rank)
		var after:=Demo.sample(2.0,rank)
		t.check(before.missile and not after.missile and after.intercepted,"interception removes airborne rocket rank "+str(rank))
		t.check(is_equal_approx(after.after,after.before*(1.0-[.1,.15,.2,.25][rank])) and after.saved>0,"demo reduces remaining reload rather than total cycle rank "+str(rank))
		var rocket=t.battle.spawn_unit("V3ROCKET","ally",Vector2(1200,1200))
		rocket.special.flight={"source":launcher,"phase":"flight","elapsed":5.0,"windup":1.0,"rack_slot":0}
		launcher.special.missile_racks=[after.before]
		Talents.missile_destroyed(rocket,enemy)
		t.check(is_equal_approx(launcher.special.missile_racks[0],after.after),"demo matches actual interception talent handler rank "+str(rank))
		Talents.missile_destroyed(rocket,enemy)
		t.check(is_equal_approx(launcher.special.missile_racks[0],after.after),"same missile cannot grant second reduction rank "+str(rank))
		var ready_clock:float=Demo.INTERCEPT+after.after/Demo.RATE+.01
		var ready:=Demo.sample(ready_clock,rank)
		t.check(ready.remaining==0 and ready.baseline>0,"talent reload completes before baseline rank "+str(rank))
	await t.finish()
	await interface(t)

static func interface(t) -> void:
	var ui=load("res://scenes/meta.tscn").instantiate();t.add_child(ui)
	ui._show_talent_demo("V3","lost_missile",0)
	var shade=ui.get_node("TalentDemo")
	var preview=shade.find_child("Preview",true,false)
	var slider:HSlider=shade.find_child("DemoTimeline",true,false)
	var levels:OptionButton
	for option in shade.find_children("*","OptionButton",true,false):
		if option.item_count==4 and option.get_item_text(0)=="解锁 0 级":levels=option;break
	t.check(levels!=null and slider!=null,"existing talent popup exposes level and seek controls")
	if levels!=null and slider!=null:
		for rank in 4:
			levels.select(rank);levels.item_selected.emit(rank)
			for clock in [0.0,1.5,2.2,Demo.duration()-.1]:
				slider.set_value_no_signal(clock);slider.value_changed.emit(clock)
				await t.get_tree().process_frame
				await t.get_tree().process_frame
				var state:=Demo.sample(clock,rank)
				t.check(preview.rank==rank and not preview.playing and is_equal_approx(preview.actor.special.missile_racks[0],state.remaining),"timeline drives real model rack state rank %d time %.1f"%[rank,clock])
				var art:=RA2Art.art("V3WO" if state.remaining>0 else "V3")
				t.check(not art.is_empty() and preview.actor._ra2.tex==art.tex,"launcher art removes spent rocket and restores loaded rocket rank %d time %.1f"%[rank,clock])
			slider.value=0.0
			t.check(preview.actor.special.missile_racks[0]==0,"backward seeking restores initial loaded model rank "+str(rank))
	shade.free();ui.free()
	await t.get_tree().process_frame
