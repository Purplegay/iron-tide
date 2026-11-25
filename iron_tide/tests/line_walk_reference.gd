extends PathService
func line_walkable(a: Vector2, b: Vector2, grid: PackedFloat32Array) -> bool:
	var d := b - a
	var current := _cell_of(a)
	var goal := _cell_of(b)
	if grid[current.y * cols + current.x] < 0.0:
		return false
	var sx := signi(goal.x - current.x)
	var sy := signi(goal.y - current.y)
	var tx := INF
	var ty := INF
	var dx := INF
	var dy := INF
	if sx != 0:
		dx = cell / absf(d.x)
		var edge := (current.x + (1 if sx > 0 else 0)) * cell
		tx = (edge - a.x) / d.x
	if sy != 0:
		dy = cell / absf(d.y)
		var edge := (current.y + (1 if sy > 0 else 0)) * cell
		ty = (edge - a.y) / d.y
	while current != goal:
		# A clamped endpoint can lie before the next real grid crossing. Once
		# an axis reaches its goal cell it must not step beyond the map edge.
		if current.x == goal.x: tx = INF
		if current.y == goal.y: ty = INF
		if absf(tx - ty) < 0.000001:
			if grid[current.y * cols + current.x + sx] < 0.0 \
					or grid[(current.y + sy) * cols + current.x] < 0.0:
				return false
			current += Vector2i(sx, sy)
			tx += dx
			ty += dy
		elif tx < ty:
			current.x += sx
			tx += dx
		else:
			current.y += sy
			ty += dy
		if current.x < 0 or current.y < 0 or current.x >= cols or current.y >= rows:
			return false
		if grid[current.y * cols + current.x] < 0.0:
			return false
	return true
