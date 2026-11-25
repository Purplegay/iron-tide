extends Node
func _ready() -> void:
	var p := PathService.new()
	p.cols = 43
	p.rows = 33
	var rng := RandomNumberGenerator.new()
	rng.seed = 39471
	var failures := 0
	var checks := 0
	for version in 3:
		p.epoch += 1
		for domain in 4:
			var grid := PackedFloat32Array()
			var zones := PackedInt32Array()
			for i in p.cols*p.rows:
				var z := rng.randi_range(0,6)
				grid.append(-1.0 if z==0 else 1.0)
				zones.append(z)
			for n in 1500:
				var point := Vector2i(rng.randi_range(-5,p.cols+5),rng.randi_range(-5,p.rows+5))
				var radius := rng.randi_range(-1,25)
				var zone := rng.randi_range(-1,7)
				var expected := p._nearest_walkable(point,grid,zones,zone,radius)
				var actual := p._row_snap(point,grid,zones,zone,radius,domain)
				checks += 1
				if actual != expected: failures += 1
	p.free()
	print("ROW_CHECK ",checks," failures=",failures)
	get_tree().quit(1 if failures else 0)
