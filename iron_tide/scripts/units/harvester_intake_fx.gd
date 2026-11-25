class_name HarvesterIntakeFx
extends RefCounted
## Presentation only. Positive extraction refreshes the short-lived intake stream.
## Draw in the actor's Iso.begin space so fog, depth, pause and lifetime follow it.

var remaining := 0.0
var phase := 0.0
var source: WeakRef
var kind := "ore"

func tick(actor, delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	phase += delta
	# Also redraw the final expired frame, including unselected, stationary miners.
	actor.queue_redraw()

func extracted(actor, node, quantity: float) -> void:
	if quantity <= 0.0 or not is_instance_valid(node):
		return
	if source == null or source.get_ref() != node:
		phase = 0.0
	source = weakref(node)
	kind = str(node.resource_kind)
	remaining = 0.15
	actor.queue_redraw()

func active(actor) -> bool:
	return remaining > 0.0 and source != null and is_instance_valid(source.get_ref()) \
		and actor.resource_node == source.get_ref() and actor.is_harvester \
		and actor.harvest_state == "harvesting" and not actor.has_move_order \
		and not actor._dead and actor.hp > 0.0 and actor.embarked_in == null \
		and actor._stun_timer <= 0.0 and not actor.repairing and actor._harvest_facing_ready()

func intake(actor) -> Vector2:
	return Iso.dir(Vector2.RIGHT.rotated(actor.hull_angle) * actor.radius * 1.65) + Vector2(0, -3.0)

func draw_on(actor, behind_body: bool) -> void:
	if not active(actor):
		return
	var mouth := intake(actor)
	if (mouth.y < -3.0) != behind_body:
		return
	var node = source.get_ref()
	var toward: Vector2 = (actor.global_position - node.global_position).normalized()
	var start := Iso.dir(node.global_position + toward * minf(node.radius * 0.45, 10.0) - actor.global_position)
	var across := Vector2(-(mouth - start).y, (mouth - start).x).normalized()
	var gold := Color(1.0, 0.79, 0.17)
	for i in 16:
		var progress := fposmod(phase * 1.9 + float(i) / 16.0, 1.0)
		var t := progress * progress
		var spread := sin(float(i) * 2.4) * (1.0 - t) * 7.0
		var p := start.lerp(mouth, t) + across * spread + Vector2(0, -sin(progress * PI) * 5.0)
		var size := lerpf(2.6, 0.7, t)
		var color: Color = gold if kind != "gems" else [Color(0.3, 0.92, 1.0), Color(1.0, 0.4, 0.75), Color(0.5, 1.0, 0.5)][i % 3]
		color.a = minf(1.0, progress * 8.0)
		actor.draw_colored_polygon(PackedVector2Array([p + Vector2(-size, 0), p + Vector2(0, -size), p + Vector2(size, 0), p + Vector2(0, size * 0.6)]), color)
		actor.draw_line(p + Vector2(-size * 0.4, -0.5), p + Vector2(0, -size * 0.7), Color(1, 1, 0.85, color.a * 0.8), 1.0)
	# Small ground dust at the intake, not a weapon beam or a persistent emitter.
	for i in 4:
		var t := fposmod(phase * 2.5 + i * 0.25, 1.0)
		actor.draw_circle(mouth + across * sin(i * 2.1) * 3.0 + Vector2(0, -t * 6.0), 1.0 + t * 2.0, Color(0.72, 0.62, 0.38, (1.0 - t) * 0.3))
