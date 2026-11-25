extends RefCounted
class_name Formations
## 编队阵型布局（纯静态函数）。给定数量 / 中心点 / 朝向，返回各单位的相对落点。

const MODES: Array[String] = ["line", "wedge", "column"]

static func label(mode: String) -> String:
	match mode:
		"line":
			return "横列"
		"wedge":
			return "楔形"
		"column":
			return "纵队"
	return mode

## facing：阵型推进方向（单位从 -facing 一侧排向 center）
static func layout(count: int, center: Vector2, facing: Vector2, mode: String, spacing: float = 34.0) -> Array:
	var out: Array = []
	if count <= 0:
		return out
	var f := facing
	if f.length() < 0.001:
		f = Vector2.UP
	f = f.normalized()
	var right := Vector2(f.y, -f.x)

	match mode:
		"column":
			for i in range(count):
				out.append(center - f * (float(i) * spacing))
		"wedge":
			var placed := 0
			var row := 0
			while placed < count:
				var per := row + 1
				for k in range(per):
					if placed >= count:
						break
					var off := (float(k) - float(per - 1) * 0.5) * spacing
					out.append(center + right * off - f * (float(row) * spacing))
					placed += 1
				row += 1
		_:
			var per_row: int = max(1, int(ceil(sqrt(float(count)))))
			for i in range(count):
				var r := i / per_row
				var c := i % per_row
				var off2 := (float(c) - float(per_row - 1) * 0.5) * spacing
				out.append(center + right * off2 - f * (float(r) * spacing))
	return out
