extends "res://tests/ground_control_regression.gd"
const Native = preload("res://scripts/world/native_maps.gd")

func exercise(mode: String) -> void:
 for broad_phase in [false, true]:
  BattleRequest.configure_skirmish(mode, {"map_layout":"yr_crctbrd", "opening":"mcv", "fog_of_war":false})
  screen = load("res://scenes/battle.tscn").instantiate()
  add_child(screen)
  screen.process_mode = Node.PROCESS_MODE_DISABLED
  battle = screen.battle
  var point := Vector2(117.5,57.5)*Native.CELL
  var unit = battle.spawn_unit("MTNK", "ally", point)
  activate(unit)
  if broad_phase:
   for i in 100:
    var filler = battle.spawn_unit("E1", "ally", Vector2(600+i*25,600))
    activate(filler)
  # A destroyed actor may remain in a candidate snapshot until housekeeping.
  # Keep that stale reference deliberately in both candidate sources.
  var ghost := Node2D.new()
  battle.units.push_front(ghost)
  battle.neighborhood.membership[ghost] = Vector2i(point/battle.neighborhood.CELL)
  battle.neighborhood.buckets.get_or_add(Vector2i(point/battle.neighborhood.CELL), []).push_front(ghost)
  ghost.free()
  await get_tree().physics_frame
  unit.velocity = Vector2(80,0)
  var before:Vector2 = unit.position
  unit._slide_across_bridge_layers(1.0/60)
  check(unit.position.x>before.x,mode+" stale bridge candidate does not cancel movement broad="+str(broad_phase),[before,unit.position])
  var blocker = battle.spawn_unit("HTNK","ally",point+Vector2(72,0))
  activate(blocker)
  await get_tree().physics_frame
  for tick in 120:
   unit.velocity=Vector2(80,0)
   unit._slide_across_bridge_layers(1.0/60)
   await get_tree().physics_frame
  check(unit.position.distance_to(blocker.position)>=unit.radius+blocker.radius-0.2,mode+" live bridge traffic still collides")
  check(unit.get_collision_exceptions().is_empty(),mode+" temporary bridge exceptions do not leak")
  check(unit._domain_ok(unit.position),mode+" movement remains on bridge")
  await finish()
