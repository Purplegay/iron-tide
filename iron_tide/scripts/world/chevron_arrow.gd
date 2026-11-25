extends Node2D
## A short-lived cosmetic attached to the terrain, with no collision or targeting.
# James Cram, Wikimedia Commons, public domain. Cropped, oriented and widened at RTS scale.
const ART := preload("res://assets/cosmetics/chevron_arrow.png")
const ARROW_LENGTH := 30.0
const LIFE := 2.8
const SETTLE := 0.23
var age := 0.0
var heading := 0.0
var world

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	if is_instance_valid(world):
		visible = world.position_visible_to("ally",global_position)
	modulate.a = 1.0-smoothstep(LIFE-0.65,LIFE,age)
	queue_redraw()

func _draw() -> void:
	Iso.begin(self)
	var t := clampf(age / SETTLE, 0.0, 1.0)
	var landed := age - SETTLE
	var lean := Iso.dir(Vector2.from_angle(heading)).normalized().x
	var axis := Vector2(lean * 0.30, -1.0).normalized()
	# Keep the entry point fixed when the buried shaft rings down.
	if landed > 0.0:
		axis = axis.rotated(0.09 * sin(landed * 48.0) * exp(-12.0 * landed))
	var height := (1.0-t*t) * 35.0
	var tip := axis * height
	var soil := clampf(landed / 0.045, 0.0, 1.0)
	var buried := 4.2 * soil
	var visible_length := ARROW_LENGTH - buried
	var shadow := Vector2(10.0+lean*4.0, 2.0)
	draw_line(Vector2.ZERO, shadow, Color(0.12,0.10,0.08,0.10+0.24*t), 1.5, true)
	if landed >= 0.0 and landed < 0.28:
		var f := landed / 0.28
		for i in 4:
			var dir := Vector2.from_angle(i*2.4+heading)*Vector2(1.0,0.45)
			var chip := dir*(2.0+f*(3.0+i)) + Vector2.UP*(1.0+i)*sin(f*PI)
			draw_circle(chip, 0.85-f*0.4, Color(0.45,0.35,0.22,(1.0-f)*0.82))
	var pose := Transform2D(Iso.eff_angle(),Iso.up(),0.0,Vector2.ZERO)
	draw_set_transform_matrix(pose * Transform2D(axis.angle()+PI/2.0,tip))
	var texture_size := ART.get_size()
	var width := ARROW_LENGTH * texture_size.x / texture_size.y
	var destination := Rect2(-width*0.5, -visible_length, width, visible_length)
	var source := Rect2(Vector2.ZERO, Vector2(texture_size.x, texture_size.y*visible_length/ARROW_LENGTH))
	draw_texture_rect_region(ART,destination,source)
