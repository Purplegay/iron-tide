extends "res://tests/core_draw_reference.gd"

var prepared_calls := 0

func draw_prepared_voxel(prepared, target: Rect2, frame: int, tint: Color) -> void:
	prepared_calls += 1
	super.draw_prepared_voxel(prepared,target,frame,tint)

func compare(label: String) -> void:
	_body_bounds = Rect2()
	captured = []
	_draw_ra2_sprite_uncached(radius)
	var expected := snapshot() + [_body_bounds, _shadow_draw_texture]
	_body_bounds = Rect2()
	captured = []
	_draw_ra2_sprite(radius)
	comparisons += 1
	if snapshot() + [_body_bounds, _shadow_draw_texture] != expected: mismatches.append(label)

func _draw() -> void:
	if completed: return
	for angle in [0.0, 0.01, 1.7, 4.1]:
		hull_angle = angle
		turret_angle = angle + 0.3
		for i in 3: compare("cold/warm bearings")
	# Continuous logical rotation must invalidate only when a rendered frame changes.
	for sample in 720:
		hull_angle = sample * TAU / 720.0
		turret_angle = -sample * TAU / 640.0
		compare("quantized facing and shadow boundary")
	for altitude in [0.0,0.27,0.99,1.0]:
		logistics.air_lift = altitude
		for moment in [0.0,0.23,0.75]:
			_anim = moment
			compare("live lift and wobble")
	for selected_value in [true, false]:
		selected = selected_value
		compare("selection")
	for alpha_state in [true, false]:
		if alpha_state: special.echo_cloaked = true
		else: special.erase("echo_cloaked")
		for i in 3: compare("live opacity")
	for offline in [true, false]:
		powered_unit.offline = offline
		for i in 3: compare("live powered grade")
	for height in [7.0, 0.0]:
		hover_motion.lift = height
		for i in 3: compare("hover lift")
	for k in [0.4, 0.5]:
		Iso.K = k
		for i in 3: compare("projection")
	for rocking in [0.2, 0.0]:
		_rock_t = rocking
		for i in 3: compare("rocking fallback/reentry")
	var body := _ra2
	_ra2 = body.duplicate(true)
	_ra2.fixed_anchor = [31, 42]
	for i in 3: compare("replacement art")
	_ra2.fixed_anchor[0] = 32
	for i in 3: compare("in-place fixed anchor")
	_ra2 = body
	for i in 3: compare("original art restored")
	var gun := _ra2_tur
	_ra2_tur = gun.duplicate(true)
	_ra2_tur.draw_offset = [3, 4]
	for i in 3: compare("replacement turret")
	_ra2_tur.draw_offset[0] = 7
	for i in 3: compare("in-place turret offset")
	_ra2_tur = gun
	for i in 3: compare("turret restored")
	for i in 3: compare("final warm")
	micro.append({"shared_atlases":VoxelRenderer.resources.size(),"prepared_calls":prepared_calls})
	completed = true
