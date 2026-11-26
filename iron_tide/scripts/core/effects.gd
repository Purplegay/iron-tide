extends Node2D
class_name Effects
const Looks = preload("res://scripts/core/weapon_look.gd")
## 轻量特效：命中闪光、光束、伤害飘字。全部程序化绘制，无贴图依赖。

static func spawn_impact(pos: Vector2, color: Color, radius: float = 14.0) -> void:
	var host := _host()
	if host == null:
		return
	var e := Impact.new()
	e.position = pos
	e.color = color
	e.max_radius = max(8.0, radius)
	host.add_child(e)

## 程序化光束。kind: "laser"（层叠实心激光）/ "rad"（辐射束，点串）/ "tesla"（锯齿电弧）。
## thickness = 内芯线宽（像素）；duration = 存活秒数。旧调用（不传 kind）等价于 laser。
static func spawn_beam(from: Vector2, to: Vector2, color: Color, kind: String = "laser",
		thickness: float = 2.5, duration: float = 0.12, look := "", host: Node = null, branch := false, signature := false, hold_first_frame := false, sight_from := Vector2.INF, sight_to := Vector2.INF) -> void:
	if host == null:host = _host()
	if host == null:
		return
	var b: Beam = ElectricBolt.new() if kind == "yr_bolt" else Beam.new()
	b.look = look
	b.branch = branch
	b.signature = signature
	b.hold_first_frame = hold_first_frame
	b.sight_from = sight_from if sight_from.is_finite() else from
	b.sight_to = sight_to if sight_to.is_finite() else to
	b.from = from
	b.to = to
	b.color = color
	b.kind = kind
	b.thickness = maxf(1.0, thickness)
	b.duration = maxf(0.05, duration)
	host.add_child(b)

## Presentation coordinate only; damage/range/splash continue using ground positions.
static func hit_lift(target) -> float:
	if target is Unit and (target.is_air or target.is_air_target()):
		return target._visual_lift()
	return 0.0

static func hit_position(target) -> Vector2:
	return target.global_position + RA2Art.art_dir(Vector2.UP * hit_lift(target))

static func spawn_text(pos: Vector2, text: String, color: Color, art_offset := Vector2.ZERO) -> void:
	var host := _host()
	if host == null:
		return
	var t := FloatText.new()
	t.position = pos
	t.text = text
	t.art_offset = art_offset
	t.color = color
	host.add_child(t)

static func spawn_sparks(pos: Vector2, count: int, color: Color = Color(1.0, 0.85, 0.45)) -> void:
	var host := _host()
	if host == null:
		return
	var s := Sparks.new()
	s.position = pos
	s.count = maxi(1, count)
	s.color = color
	host.add_child(s)


static func spawn_flash(pos: Vector2, radius: float = 26.0, color: Color = Color(1.0, 0.86, 0.60), visual_offset := Vector2.ZERO) -> void:
	var host := _host()
	if host == null:
		return
	var f := Flash.new()
	f.position = pos
	f.visual_offset = visual_offset
	f.max_radius = maxf(8.0, radius)
	f.color = color
	host.add_child(f)


static func _host() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree := loop as SceneTree
		var fx := tree.get_first_node_in_group("effects_root")
		if fx != null:
			return fx
		# 兜底：挂到当前场景根节点，避免特效丢失
		var cur := tree.current_scene
		if cur != null:
			return cur
	return null


class Impact extends Node2D:
	var color: Color = Color.WHITE
	var max_radius: float = 14.0
	var t: float = 0.0
	var duration: float = 0.22
	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := t / duration
		var r := max_radius * (0.35 + k * 0.65)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 18, Color(color.r, color.g, color.b, 1.0 - k), 2.0)
		draw_circle(Vector2.ZERO, max_radius * 0.5 * (1.0 - k), Color(color.r, color.g, color.b, 0.35 * (1.0 - k)))


class Sparks extends Node2D:
	var color: Color = Color(1.0, 0.85, 0.45)
	var count: int = 8
	var t: float = 0.0
	var duration: float = 0.3
	var _dirs: PackedVector2Array = PackedVector2Array()
	var _lens: PackedFloat32Array = PackedFloat32Array()
	func _ready() -> void:
		for i in count:
			var a := randf() * TAU
			var d := Vector2(cos(a), sin(a) * 0.6)
			_dirs.append(d)
			_lens.append(randf_range(5.0, 16.0))
	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := 1.0 - t / duration
		var spread := 1.0 + (1.0 - k) * 1.6
		for i in _dirs.size():
			var a := _dirs[i] * _lens[i] * spread
			draw_line(a * 0.25, a, Color(color.r, color.g, color.b, k), 1.6 * k + 0.6)


class Flash extends Node2D:
	var visual_offset := Vector2.ZERO
	var color: Color = Color(1.0, 0.86, 0.60)
	var max_radius: float = 26.0
	var t: float = 0.0
	var duration: float = 0.13
	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := t / duration
		draw_set_transform(visual_offset)
		var r := max_radius * (0.5 + k * 0.5)
		draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.42 * (1.0 - k)))
		draw_circle(Vector2.ZERO, r * 0.45, Color(1.0, 1.0, 1.0, 0.5 * (1.0 - k)))


class Beam extends Node2D:
	var sight_from := Vector2.INF
	var sight_to := Vector2.INF
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var color: Color = Color.WHITE
	const Duplex=preload("res://scripts/core/prism_duplex.gd")
	var branch := false
	var signature := false
	var look := ""
	var kind: String = "laser"   # laser / rad / tesla
	var thickness: float = 2.5
	var t: float = 0.0
	var hold_first_frame := false
	var duration: float = 0.12
	var _jag: PackedVector2Array = PackedVector2Array()
	func _ready() -> void:
		if kind == "tesla":
			_build_jag()
	func _build_jag() -> void:
		# 电弧：a→b 切段，每段沿法向随机偏移，形成锯齿；中段振幅最大
		var d := to - from
		var seg := clampi(int(d.length() / 20.0), 3, 9)
		var dir := d.normalized()
		var nrm := Vector2(-dir.y, dir.x)
		_jag.append(from)
		for i in range(1, seg):
			var f := float(i) / float(seg)
			var amp := sin(f * PI) * 8.0
			_jag.append(from + d * f + nrm * randf_range(-amp, amp))
		_jag.append(to)
	func _process(delta: float) -> void:
		if hold_first_frame:
			hold_first_frame = false
			return
		t += delta
		if t >= duration+(Duplex.AFTERGLOW if look in ["prism_blue","prism_red"] else 0.0):
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var k := clampf(1.0 - t / duration, 0.0, 1.0)
		var a := to_local(from)
		var b := to_local(to)
		if signature and branch:
			# Each shard converges on this actual splinter's endpoint.
			var axis:=(b-a).normalized()
			for i in 3:
				var ray:=axis.rotated((i-1)*0.28)
				var at:=b-ray*(2.0+13.0*k)
				draw_line(at-ray*(2.0+2.0*k),at,Color(Color("#ffc86c"),k),1.4,true)
		if look=="time_fracture":
			Looks.Signature.time_beam(self,a,b,1-k)
			return
		if look in ["prism_blue","prism_red"]:
			Duplex.draw_beam(self,a,b,look=="prism_blue",branch,thickness,t,duration)
			return
		match kind:
			"rail":
				var direction := (b - a).normalized()
				var normal := direction.orthogonal()
				draw_line(a, b, Color(color, k * 0.8), thickness * 0.6, true)
				for i in range(0, int(a.distance_to(b)), 9):
					var center := a + direction * float(i)
					var spread := normal * (2.0 + (1.0 - k) * 4.0)
					draw_line(center - spread, center + spread, Color(color, k * 0.5), 1.2, true)
			"tesla":
				var pts := PackedVector2Array()
				if _jag.size() >= 2:
					for p in _jag:
						pts.append(to_local(p))
				else:
					pts = PackedVector2Array([a, b])
				draw_polyline(pts, Color(color.r, color.g, color.b, 0.30 * k), thickness * 3.6, true)
				draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.55 * k), thickness * 1.7, true)
				draw_polyline(pts, Color(color.r, color.g, color.b, k), thickness, true)
			"rad":
				var rd := b - a
				var n := maxi(2, int(rd.length() / 16.0))
				draw_line(a, b, Color(color.r, color.g, color.b, 0.30 * k), thickness * 2.2)
				for i in range(n + 1):
					var f := float(i) / float(n)
					draw_circle(a + rd * f, thickness * 0.75, Color(color.r, color.g, color.b, k))
			_:
				var core := Color(minf(1.0, color.r + 0.45), minf(1.0, color.g + 0.45), minf(1.0, color.b + 0.45), k)
				draw_line(a, b, Color(color.r, color.g, color.b, 0.26 * k), thickness * 3.4)
				draw_line(a, b, Color(color.r, color.g, color.b, 0.85 * k), thickness * 1.5)
				draw_line(a, b, core, thickness * 0.6)


## YR EBolt: three independently visible filaments, eight arcs, PALETTE.PAL 10/5 and 15.
class ElectricBolt extends Beam:
	const ARC_COUNT := 8
	const TICK_RATE := 15.0
	var strands: Array[PackedVector2Array] = []
	var noise := RandomNumberGenerator.new()

	func _ready() -> void:
		noise.randomize()
		if look=="spectrum":
			for i in 3:
				var line:=Line2D.new()
				line.texture=Looks.SPECTRUM
				line.texture_mode=Line2D.LINE_TEXTURE_STRETCH
				line.width=thickness*(2.4 if i==1 else 1.5)
				add_child(line)
		reshape()

	func reshape() -> void:
		var axis := Iso.dir(to - from)
		var normal := axis.normalized().orthogonal()
		var spread := clampf(axis.length() * 0.07, 1.0, 16.0)
		strands.clear()
		for strand in 3:
			strands.append(PackedVector2Array([to_local(from)]))
		for i in range(1, ARC_COUNT):
			var f := float(i) / ARC_COUNT
			var envelope := sin(f * PI) * spread
			var bend := noise.randf_range(-1.0, 1.0)
			for strand in strands.size():
				var offset := (bend + noise.randf_range(-0.65, 0.65)) * envelope
				strands[strand].append(to_local(from.lerp(to, f) + RA2Art.art_dir(normal * offset)))
		for strand in strands.size():
			strands[strand].append(to_local(to))
			if look=="spectrum":
				var line:Line2D=get_child(strand)
				line.points=strands[strand]

	func _process(delta: float) -> void:
		var previous := floori(t * TICK_RATE)
		super(delta)
		if not is_queued_for_deletion() and floori(t * TICK_RATE) != previous:
			reshape()

	func _draw() -> void:
		if signature and not strands.is_empty():
			var fade:=clampf(1.0-t/duration,0,1)
			for j in [2,4,6]:
				var root:=strands[0][j]
				var tangent:=(strands[0][j+1]-root).normalized()
				var fork:=tangent.orthogonal()*(1.0 if j==4 else -1.0)
				var joint:=root+tangent*2+fork*3
				draw_polyline(PackedVector2Array([root,joint,joint+tangent*3+fork*2]),Color(Color("#ffc768"),fade),1.2,true)
		if look=="spectrum":
			self.modulate.a=clampf(1.0-t/duration,0,1)
			return
		if from.is_equal_approx(to): return
		var opacity := clampf(1.0 - t / duration, 0.0, 1.0)
		for i in strands.size():
			var tint := Color8(252, 252, 252) if i == 2 else color
			draw_polyline(strands[i], Color(tint, opacity), thickness, true)


class FloatText extends Node2D:
	var art_offset := Vector2.ZERO
	var text: String = ""
	var color: Color = Color.WHITE
	var t: float = 0.0
	var duration: float = 0.6
	func _process(delta: float) -> void:
		t += delta
		position.y -= 26.0 * delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		Iso.begin(self)
		var k := 1.0 - t / duration
		var font := ThemeDB.fallback_font
		draw_string(font, art_offset + Vector2(-10, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color.r, color.g, color.b, k))
