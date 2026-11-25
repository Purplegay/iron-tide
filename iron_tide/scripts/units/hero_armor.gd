extends RefCounted

const OPTIC := preload("res://assets/cosmetics/heroes/sentinel_optic.svg")
const AEGIS := preload("res://assets/cosmetics/heroes/sentinel_aegis.svg")
const FURNACE := preload("res://assets/cosmetics/heroes/ember_furnace.svg")
const PAULDRON := preload("res://assets/cosmetics/heroes/ember_pauldron.svg")

# The SHP frame includes the rifle, and deployed frames also include the sandbags.
# The upper band of the visible figure tracks its head as the body changes pose.
static func head(actor, frame: int, src: Rect2, target: Rect2) -> Vector2:
	var art: Dictionary = actor._ra2
	var anchors: Dictionary = art.get_or_add("hero_head_by_frame", {})
	if not anchors.has(frame):
		var bounds := RA2Art.visible_sprite_rect(art, Rect2(Vector2.ZERO,src.size),src)
		var img := RA2Art.sprite_image(art)
		var sum_x := 0.0
		var count := 0
		if img != null and bounds.has_area():
			var start := Vector2i(src.position + bounds.position)
			for y in range(start.y, start.y + mini(5, int(bounds.size.y))):
				for x in range(start.x, start.x + int(bounds.size.x)):
					var pixel := img.get_pixel(x,y)
					if pixel.a > 0.5 and pixel.v > 0.13:
						sum_x += x + 0.5 - src.position.x
						count += 1
		anchors[frame] = Vector2(sum_x / count if count else bounds.get_center().x, bounds.position.y)
	return target.position + Vector2(anchors[frame]) * target.size / src.size

# Torso bearings read from GI.SHP and CONS.SHP, in native 45-degree steps.
# Both 15-frame idle clips are single-facing; the rifle can move independently.
const IDLE_BEARINGS := {
	"E1": [
		[3.0,3.0,3.0,3.1,3.15,3.25,3.3,3.35,3.45,3.55,3.7,3.85,3.75,3.45,3.0],
		[5.0,5.2,5.35,5.25,5.1,4.8,4.5,4.3,4.15,4.1,4.1,4.2,4.4,4.75,5.0],
	],
	"E2": [
		[3.0,2.3,1.65,1.0,0.3,-0.6,-0.9,-1.0,-1.0,-1.0,-1.0,-1.0,-1.0,-0.9,-0.7],
		[5.0,5.0,5.05,5.15,5.3,5.4,5.45,5.45,5.45,5.4,5.35,5.25,5.15,5.05,5.0],
	],
}

static func pose_bearing(actor,frame:int,facing:int) -> float:
	var idle=actor.idle_pose
	if idle!=null and idle.frame==frame and idle.appearance==actor.unit_id and idle.clip in ["Idle1","Idle2"]:
		var step:=frame-int(actor._seq[idle.clip].start)
		var bearings:Array=IDLE_BEARINGS[actor.unit_id][0 if idle.clip=="Idle1" else 1]
		if step>=0 and step<bearings.size():return bearings[step]
	return float(facing)

# Guard frames 0..7 face N, NW, W, SW, S, SE, E, NE on the infantry sheet.
static func draw_layer(actor, anchor: Vector2, facing: float, behind: bool, opacity: float) -> void:
	var allied: bool = actor.unit_id == "E1"
	var forward := Vector2.UP.rotated(-facing * TAU / RA2Art.INFANTRY_FACINGS)
	var shoulder := Vector2(forward.y, -forward.x)
	var transform: Transform2D = actor.body_draw_transform()
	var shade := Color(1, 1, 1, opacity)
	for pack in [true, false]:
		var offset := -forward * 5.0 if pack else shoulder * 5.5 + forward * 1.3
		if (offset.y < -0.1) != behind: continue
		var mount := anchor + Vector2(offset.x, offset.y * 0.5 + (5.0 if pack else 10.0))
		var outward := -forward if pack else shoulder
		var width := lerpf(0.48, 1.0, absf(outward.y))
		var mirror := -1.0 if outward.x > 0.1 else 1.0
		var pose := Transform2D(Vector2(width * mirror, 0), Vector2.DOWN, mount)
		actor.draw_set_transform_matrix(transform * pose)
		if pack:
			var texture := OPTIC if allied else FURNACE
			actor.draw_texture_rect(texture, Rect2(-6.5, -8.5, 13, 17), false, shade)
		else:
			var plate := AEGIS if allied else PAULDRON
			actor.draw_texture_rect(plate, Rect2(-6.25, -6, 12.5, 14), false, shade)
			var cycle := fposmod(float(actor._anim) + float(actor.get_instance_id()%17)*0.1, 3.2)
			var pulse := maxf(0.0, 1.0-absf(cycle-0.45)/0.45)
			if pulse > 0:
				var jewel := Vector2(-3.35, 5.5) if allied else Vector2(-3.95, 6.1)
				var light := Color("#a9fffa") if allied else Color("#ffbd61")
				light.a = pulse * opacity
				actor.draw_line(jewel-Vector2(1.7,0),jewel+Vector2(1.7,0),light,0.55,true)
				actor.draw_line(jewel-Vector2(0,1.8),jewel+Vector2(0,1.8),light,0.55,true)
	actor.draw_set_transform_matrix(transform)
