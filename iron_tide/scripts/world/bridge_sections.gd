extends RefCounted
const LENGTH := 55.0
static var _cache: Dictionary = {}

static func split(span: Rect2, horizontal := true) -> Array:
	var key := [span,horizontal]
	if _cache.has(key): return _cache[key]
	var result: Array = []
	var length := span.size.x if horizontal else span.size.y
	for index in ceili(length/LENGTH):
		var offset := index*LENGTH
		var size := minf(LENGTH,length-offset)
		result.append(Rect2(span.position+Vector2(offset,0),Vector2(size,span.size.y)) if horizontal else Rect2(span.position+Vector2(0,offset),Vector2(span.size.x,size)))
	_cache[key] = result
	return result

static func native_horizontal(name: String, span: Rect2) -> bool:
	if name in ["BRIDGE1","BRIDGEB1"]:return false
	if name in ["BRIDGE2","BRIDGEB2"]:return true
	if name.begins_with("LOBRDG"):
		var number := int(name.trim_prefix("LOBRDG"))
		# Imported axes are u=-ry, v=rx. The two low-bridge overlay sets rotate.
		return number in range(10,19) or number in range(23,27)
	return span.size.x >= span.size.y
