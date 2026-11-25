extends RefCounted
## Independent simulation registry. Godot nodes are adapters, not the registry.
## Components run in registration order. New registrations wait for the next
## step; removing an entity/component takes effect before its next invocation.
var neighborhood := preload("res://scripts/world/battle_neighborhood.gd").new()
var entities: Dictionary = {}
var _components: Array = []
var _next_token := 1
var tick := 0
var _stepping := false

func register(actor: Node2D, extent: float, structure: bool) -> void:
	entities[actor] = structure
	neighborhood.register(actor, extent, structure)

func relocate(actor: Node2D) -> void:
	if entities.has(actor): neighborhood.relocate(actor)

func remove(actor: Node2D) -> void:
	neighborhood.remove(actor)
	entities.erase(actor)
	for component in _components:
		if is_same(component.actor, actor): component.active = false
	if not _stepping: _compact()

func attach(actor: Node2D, callback: Callable) -> int:
	if not entities.has(actor) or not callback.is_valid(): return 0
	var token := _next_token
	_next_token += 1
	_components.append({"token":token,"actor":actor,"callback":callback,"active":true})
	return token

func detach(token: int) -> void:
	for component in _components:
		if component.token == token:
			component.active = false
			break
	if not _stepping: _compact()

func step(delta: float) -> void:
	assert(not _stepping, "Simulation steps cannot be nested")
	if _stepping: return
	_stepping = true
	tick += 1
	var count := _components.size()
	for index in count:
		var component: Dictionary = _components[index]
		if not component.active: continue
		if not is_instance_valid(component.actor) or not entities.has(component.actor) or not component.callback.is_valid():
			component.active = false
			continue
		component.callback.call(delta)
	_stepping = false
	_compact()

func _compact() -> void:
	for index in range(_components.size()-1, -1, -1):
		if not _components[index].active: _components.remove_at(index)
