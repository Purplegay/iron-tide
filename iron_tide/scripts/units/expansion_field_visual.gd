extends Node2D
var world
const FIELD_KEYS := [preload("res://scripts/units/leizhu_cards.gd").FIELDS,
	preload("res://scripts/units/expansion_2_calibration.gd").ZONES,
	preload("res://scripts/units/expansion_2_aircraft.gd").FIELDS,
	preload("res://scripts/units/expansion_2_overload.gd").TARGETS,
	preload("res://scripts/units/expansion_2_tractor.gd").FIELDS, "expansion_zones", "expansion_scraps"]
var _had_fields := false

func _process(_delta:float) -> void:
	var active := false
	if is_instance_valid(world):
		for key in FIELD_KEYS:
			var fields = world.allied_state.get(key)
			if fields != null and not fields.is_empty():
				active = true
				break
	if active or _had_fields: queue_redraw()
	_had_fields = active
func _draw() -> void:
	if not is_instance_valid(world):return
	Iso.begin(self)
	preload("res://scripts/units/leizhu_cards.gd").draw_fields(self,world)
	preload("res://scripts/units/expansion_2_calibration.gd").draw_fields(self,world)
	preload("res://scripts/units/expansion_2_aircraft.gd").draw_fields(self,world)
	preload("res://scripts/units/expansion_2_overload.gd").draw_fields(self,world)
	preload("res://scripts/units/expansion_2_tractor.gd").draw_fields(self,world)
	for zone in world.allied_state.get("expansion_zones",[]):
		if not world.position_visible_to("ally",zone.point):continue
		var point:Vector2=Iso.dir(zone.point)
		var radius:float=zone.radius
		var color:=Color(.8,.6,.25,.6)
		for i in 40:
			var a:Vector2=point+Iso.dir(Vector2.from_angle(TAU*i/40)*radius)
			var b:Vector2=point+Iso.dir(Vector2.from_angle(TAU*(i+1)/40)*radius)
			draw_line(a,b,color,2)
		draw_string(ThemeDB.fallback_font,point,"余震 %.1fs"%zone.left if zone.kind=="seismic" else "废铁减速 %.1fs"%zone.left,HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.GOLD)
	for scrap in world.allied_state.get("expansion_scraps",[]):
		if world.position_visible_to("ally",scrap.point):draw_rect(Rect2(Iso.dir(scrap.point)-Vector2(5,3),Vector2(10,6)),Color.GOLD)
