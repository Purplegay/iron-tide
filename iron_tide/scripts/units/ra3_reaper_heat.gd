extends Node2D
## One marker per talent and victim, refreshed by successive damaging rounds.
const SPLIT_MARK := &"reaper_split_fx"
const MARK := &"reaper_heat_fx"
const LIFETIME := 0.45
var card_label := ""
var stacks:=1
var mark:=MARK
var victim
var world
var center := Vector2.ZERO
var radius := 14.0
var age := 0.0
var pulse := 0.0

static func on_hit(battle,target,split:bool,count:=1) -> void:
	_show(battle,target,SPLIT_MARK if split else MARK,count,"")

static func card_hit(battle,target,label:String,count:int) -> void:
	_show(battle,target,StringName("faction_hit_"+label),count,label)

static func _show(battle,target,key:StringName,count:int,label:String) -> void:
	var fx=target.get_meta(key) if target.has_meta(key) else null
	if not is_instance_valid(fx) or fx.is_queued_for_deletion():
		fx=new()
		fx.mark=key
		fx.victim=target
		fx.world=battle
		fx.radius=clampf(target.radius*0.85,11.0,35.0)
		fx.position=target.global_position
		battle.effects_root.add_child(fx)
		target.set_meta(key,fx)
	fx.card_label=label
	fx.stacks=count
	fx.age=0.0
	fx._track()
	fx.queue_redraw()

func _track() -> void:
	position=victim.global_position
	center=Iso.dir(victim.art_center()-position)

func _process(delta:float) -> void:
	age+=delta
	pulse+=delta
	if age>=LIFETIME:
		queue_free()
		return
	if AlliedAbilities.alive(victim):
		if not world.actor_visible_to("ally",victim):
			queue_free()
			return
		_track()
	queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(victim) and victim.has_meta(mark) and is_same(victim.get_meta(mark),self):
		victim.remove_meta(mark)

func _draw() -> void:
	Iso.begin(self)
	var progress:=fposmod(pulse,LIFETIME)/LIFETIME
	var opacity:=1.0-smoothstep(0.55,1.0,age/LIFETIME)
	var hot:=Color(1.0,0.64,0.16,opacity)
	var rim:=Color(1.0,0.33,0.05,(1.0-progress)*opacity)
	if not card_label.is_empty():
		match card_label:
			"Echo": hot=Color(0.77,0.95,1.0,opacity)
			"Flux": hot=Color(0.84,0.70,1.0,opacity)
			"Tag", "Ping": hot=Color(0.48,1.0,0.84,opacity)
			"Burst": hot=Color(1.0,0.75,0.62,opacity)
		rim=Color(hot.darkened(0.12),(1.0-progress)*opacity)
	var size:=radius*(0.65+0.60*progress)
	if (mark==MARK and card_label.is_empty()) or card_label=="Flux":
		hot=Color(preload("res://scripts/ui/talent_stack_indicator.gd").layer_color(stacks-1),opacity)
		rim=Color(hot,(1.0-progress)*opacity)
	var caption:="Heat ×%d" % stacks if stacks>1 else "Heat"
	var origin:=center+Vector2(-27,-radius-6)
	if mark==SPLIT_MARK:
		caption="Split"
		hot=Color(0.38,0.92,1.0,opacity)
		rim=Color(0.12,0.77,1.0,(1.0-progress)*opacity)
		for side in [-1,1]:
			var tip:=center+Vector2(side*(size+3),0)
			draw_polyline(PackedVector2Array([tip+Vector2(-side*4,-5),tip,tip+Vector2(-side*4,5)]),rim,2.0,true)
		if is_instance_valid(victim) and victim.has_meta(MARK):origin.y-=15
	else:
		draw_arc(center,size,0,TAU,32,rim,1.5,true)
		for i in 8:
			var direction:=Vector2.from_angle(TAU*i/8.0+0.2)
			draw_line(center+direction*(size+1),center+direction*(size+4.5),rim,1.5,true)
	if not card_label.is_empty():
		caption=card_label if stacks<=1 else "%s ×%d" % [card_label,stacks]
		if card_label=="Flux" and is_instance_valid(victim) and victim.has_meta("faction_hit_Echo"):origin.y-=15
	# Hit rings remain; the shared status adapter exposes name, stacks and lifetime.
