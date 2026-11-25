extends Node2D
## Cosmetic only: the shield resolves damage once; this wave never deals damage.
const LIFE := 1.2
const EXPAND := 0.65
var radius := 110.0
var age := 0.0

static func spawn(world,center:Vector2,reach:float) -> Node2D:
	if not is_instance_valid(world) or not is_instance_valid(world.effects_root):return null
	var wave=load("res://scripts/core/shield_break_wave.gd").new()
	wave.position=center
	wave.radius=reach
	wave.add_to_group("shield_break_wave")
	world.effects_root.add_child(wave)
	return wave

static func front(time:float) -> float:
	var t:=clampf(time/EXPAND,0,1)
	return 1.0-pow(1.0-t,2.0)

## World drawing inherits the battlefield projection; the UI supplies its own flattening.
static func paint(canvas:CanvasItem,center:Vector2,reach:float,time:float,flatten:=1.0) -> void:
	if time<0 or time>=LIFE:return
	var alpha:=1.0-smoothstep(EXPAND,LIFE,time)
	for i in 2:
		var delay:=i*0.12
		if time<delay:continue
		var r:=reach*front(time-delay)*(1.0-i*0.08)
		if r<1:continue
		var ring:=Transform2D(Vector2(1,0),Vector2(0,flatten),center)*Iso.ground_circle(Vector2.ZERO,r,64)
		var strength:=alpha*(1.0-i*0.3)
		Iso.outline(canvas,ring,Color(0.15,0.65,1,strength*0.12),12)
		Iso.outline(canvas,ring,Color(0.3,0.85,1,strength*0.5),4)
		Iso.outline(canvas,ring,Color(0.85,1,1,strength),1.5)
	# Fixed shard count and deterministic angles; no particle nodes or gameplay RNG.
	for i in 12:
		var direction:=Vector2.from_angle(i*TAU/12.0+0.13)
		var head:=direction*reach*front(time)*(0.88+0.03*(i%4))
		var tail:=head-direction*(4.0+i%3*2.0)*alpha
		canvas.draw_line(center+tail*Vector2(1,flatten),center+head*Vector2(1,flatten),Color(0.55,0.95,1,alpha*0.8),1.5,true)

func _process(delta:float) -> void:
	age+=delta
	if age>=LIFE:queue_free();return
	queue_redraw()

func _draw() -> void:
	paint(self,Vector2.ZERO,radius,age)
