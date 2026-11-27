extends RefCounted
const Outline = preload("res://scripts/ui/unit_selection_outline.gd")
var marked := {}
var friendly_marked := {}
var elapsed := 0.0
var view_scale := Vector2.ZERO

func tick(world, delta: float) -> void:
	elapsed += delta
	if elapsed < 0.10 and not world.ended: return
	elapsed = 0.0
	refresh(world)

func refresh(world) -> void:
	var current := {}
	var friends := {}
	var scale: Vector2 = world.camera.zoom if is_instance_valid(world.camera) else Vector2.ONE
	var changed_view := scale != view_scale
	view_scale = scale
	if not world.ended:
		for actors: Array in [world.units,world.buildings]:
			for actor in actors:
				if not is_instance_valid(actor) or not BattleRequest.friendly("ally",actor.side): continue
				if not world.actor_alive(actor): continue
				# A live friendly actor passes visibility unless carried by another actor.
				if not (actor is Unit and actor.embarked_in != null):
					var friend = visual_actor(actor)
					if is_instance_valid(friend): friends[friend] = true
				if actor.side!="ally": continue
				if actor is Building and not actor.is_operational(): continue
				var target = actor.attack_target
				if not world.actor_alive(target) or not (target is Unit or target is Building) or not world.actor_visible_to("ally",target): continue
				# Support orders use their own UI. A force-fire order can still mark a friend.
				if actor.weapon.is_empty() or float(actor.weapon.get("damage",0))<=0.0: continue
				var visual = visual_actor(target)
				if is_instance_valid(visual): current[visual] = true
	_sync_marks(marked,current,Outline.ATTACK_META,changed_view)
	_sync_marks(friendly_marked,friends,Outline.FRIEND_META,changed_view)
	marked = current
	friendly_marked = friends

func visual_actor(actor):
	return actor.get_node_or_null("ReaperMount") if actor is Building and actor.building_id=="R3REAPERTURRET" else actor

func _sync_marks(previous: Dictionary, current: Dictionary, marker: StringName, changed_view: bool) -> void:
	for actor in previous:
		if not is_instance_valid(actor) or current.has(actor): continue
		actor.remove_meta(marker)
		Outline.clear(actor)
		actor.queue_redraw()
	for actor in current:
		if not previous.has(actor):
			actor.set_meta(marker,true)
			actor.queue_redraw()
		elif changed_view: actor.queue_redraw()
