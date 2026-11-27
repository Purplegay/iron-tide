class_name RA2Art
extends RefCounted
## Step C 阶段2：RA2 SHP/VXL 素材装载与取帧（把程序化建模换成红警2 原图）。
##
## 素材由离线管线 ra2pipe/ 产出，路径 res://assets/ra2/{vxl,shp}/<id>.png + <id>.json：
##   vxl/<id>.png  —— 载具 8 朝向横排；帧 i 的源矩形 = (pad + i*(frameW+pad), pad, frameW, frameH)，pad=2；
##   shp/<id>.png  —— 帧网格（cols 列）；源矩形直接取自 json.rects[i]（每帧独立 x/y/w/h）。
##
## 步兵 SHP 帧序（art.ini Sequence）实测：Guard 段总在最前，占帧 0..7 = 8 朝向站立。
## 因此步兵只要取 facing_index() 选 0..7 即得站立朝向帧；行进/开火动画帧待后续接入。
## 建筑 SHP 为动画网格，本阶段先取帧 0 静态呈现。

const ShpDetail = preload("res://scripts/core/shp_detail.gd")

const VXL_DIR := "res://assets/ra2/vxl/"
const SHP_DIR := "res://assets/ra2/shp/"
## RA2 建筑动画层描述（art.ini 的 ActiveAnim/IdleAnim…），由 ra2pipe/art_build.mjs 的 anim 段产出。
## 每层指向一张独立动画 SHP（与主体同画布），运行时叠在主体之上。
const BLDANIM_DIR := "res://assets/ra2/bldanim/"
## 战斗特效动画（炮口火光 / 命中爆炸 / 可见弹体）：res://assets/ra2/fx/<IMAGE>.png + .json
## 由 ra2pipe/art_build.mjs 的 fx 段产出（ANIM.PAL 上色；已裁到全动画并集包围盒）。
const FX_DIR := "res://assets/ra2/fx/"
const VXL_PAD := 2.0
## 步兵站立朝向帧数（Guard 帧 0..7）
const INFANTRY_FACINGS := 8

## RA2 facing 0 在屏幕上的方位：素材朝向 0 对应「屏幕正上」(-PI/2)。
## 若实测发现整体旋转偏移，改 FACING_OFFSET（阶数，0..7）即可全局校正。
const FACING_OFFSET := 0

static var _cache: Dictionary = {}
static var _theaters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHP_DIR + "theaters/index.json"))
static var _theater: Dictionary = _theaters.NEWURBAN

static func set_building_theater(name: String) -> void:
	var next: Dictionary = _theaters.get(name.to_upper(), _theaters.TEMPERATE)
	if is_same(next, _theater): return
	for id in _theater.sheets: _cache.erase(id)
	_theater = next

static func theater_sheet_id(id: String) -> String:
	return _theater.sheets.get(id, id)

static var _weapon_descriptors: Dictionary = {}
static var _shp_geometry: Dictionary = {}
static var _unit_shadow_cache: Dictionary = {}

## Union coverage masks before applying 50% opacity: overlapping parts
## must not become a darker double shadow. Bound the rotating-frame cache.
static func unit_shadow_texture(body: Dictionary, turret: Dictionary, body_frame: int, turret_frame: int) -> Texture2D:
	var key := "%s:%d|%s:%d" % [body.key, body_frame, turret.key, turret_frame]
	if _unit_shadow_cache.has(key): return _unit_shadow_cache[key]
	for art_data in [body, turret]:
		if not art_data.has("img"):
			var img: Image = art_data.tex.get_image()
			if img.is_compressed(): img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			art_data["img"] = img
	var merged := _shadow_union(body, turret, body_frame, turret_frame)
	var texture := ImageTexture.create_from_image(merged)
	if _unit_shadow_cache.size() >= 128: _unit_shadow_cache.erase(_unit_shadow_cache.keys()[0])
	_unit_shadow_cache[key] = texture
	return texture

static func _shadow_union(body: Dictionary, turret: Dictionary, body_frame: int, turret_frame: int) -> Image:
	var merged: Image = body.img.get_region(Rect2i(src_rect(body, body_frame)))
	# Turret coverage depends on turret facing alone. Its sparse mask can
	# serve every hull facing, including the antialiased edge pixels.
	var poses: Dictionary = turret.get_or_add("shadow_coverage", {})
	if not poses.has(turret_frame):
		var overlay: Image = turret.img.get_region(Rect2i(src_rect(turret, turret_frame)))
		var top := overlay.get_data()
		var samples := PackedInt32Array()
		for offset in range(3, top.size(), 4):
			if top[offset] != 0:
				samples.append(((offset >> 2) << 8) | top[offset])
		poses[turret_frame] = samples
	var coverage: PackedInt32Array = poses[turret_frame]
	var mask := merged.get_data()
	for sample in coverage:
		var offset := (sample >> 8) * 4 + 3
		if offset >= mask.size(): break
		mask[offset] = maxi(mask[offset], sample & 255)
	merged.set_data(merged.get_width(), merged.get_height(), false, Image.FORMAT_RGBA8, mask)
	return merged

## 取得某 id 的素材元数据（无素材则返回 {}）。结果缓存，失败也缓存（避免反复探测文件）。
static func art(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var m := _load(theater_sheet_id(id))
	_cache[id] = m
	return m

static func allied_finale_site(id: String) -> Dictionary:
	if BattleRequest.skirmish or BattleRequest.mission_id != "yr_allied_finale": return {}
	var key := "allied_finale:" + id
	if not _cache.has(key):
		var base := "res://assets/maps/yr/allied_finale/" + id
		var result := {}
		if FileAccess.file_exists(base+".json") and ResourceLoader.exists(base+".png"):
			result = JSON.parse_string(FileAccess.get_file_as_string(base+".json"))
			result.merge({"kind":"shp","key":id,"tex":load(base+".png")},true)
			if ResourceLoader.exists(base+"_detail.png"):
				var detail := load(base+"_detail.png") as Texture2D
				if detail != null and detail.get_size() == result.tex.get_size()*2.0:
					result.merge({"detail_tex":detail,"detail_scale":2.0})
		_cache[key] = result
	return _cache[key]

static func has_art(id: String) -> bool:
	return not art(id).is_empty()

## Shared by unit setup, IFV turret changes and airport dock alignment.
static func weapon_descriptor(id: String) -> Dictionary:
	if not _weapon_descriptors.has(id):
		var path := "res://assets/ra2/unitweapon/%s.json" % id
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		var descriptor: Dictionary = parsed if parsed is Dictionary else {}
		descriptor.make_read_only()
		_weapon_descriptors[id] = descriptor
	return _weapon_descriptors[id]

static func clear_cache() -> void:
	_weapon_descriptors.clear()
	ShpDetail.clear_cache()
	_cache.clear()
	_unit_shadow_cache.clear()
	_bldanim_cache.clear()
	_fx_cache.clear()

static var _fx_cache: Dictionary = {}

## RA2 战斗特效动画表（image -> {tex, cell, count, rects, fps, shadow, translucent}）。
## cell 是【全动画并集包围盒】，因此 cell 中心 == 动画内容中心：
## 把 cell 居中画在目标像素上，即与 RA2「动画居中于落点/炮口」一致。
static func fx(image: String) -> Dictionary:
	if image == "":
		return {}
	var key := image.to_upper()
	if _fx_cache.has(key):
		return _fx_cache[key]
	var out: Dictionary = {}
	var png := FX_DIR + key + ".png"
	if ResourceLoader.exists(png):
		var tex := load(png) as Texture2D
		if tex != null:
			var rects: Array = []
			var cell := Vector2.ZERO
			var count := 1
			var fps := 15.0
			var shadow := false
			var translucent := false
			var sound := ""
			var jp := FX_DIR + key + ".json"
			if FileAccess.file_exists(jp):
				var j = JSON.parse_string(FileAccess.get_file_as_string(jp))
				if typeof(j) == TYPE_DICTIONARY:
					var rr = j.get("rects", [])
					if typeof(rr) == TYPE_ARRAY:
						rects = rr
					var c = j.get("cell", [])
					if typeof(c) == TYPE_ARRAY and c.size() >= 2:
						cell = Vector2(float(c[0]), float(c[1]))
					count = int(j.get("count", 1))
					fps = float(j.get("fps", 15.0))
					shadow = (j.get("shadow", false) == true)
					translucent = (j.get("translucent", false) == true)
					var sv = j.get("sound", null)
					if sv != null:
						sound = str(sv)
			out = { "kind": "fx", "image": key, "tex": tex, "rects": rects, "cell": cell, "count": count, "fps": fps, "shadow": shadow, "translucent": translucent, "sound": sound }
	_fx_cache[key] = out
	return out

## 特效动画第 frame 帧的源矩形
static func fx_rect(m: Dictionary, frame: int) -> Rect2:
	if m.is_empty():
		return Rect2()
	var rects: Array = m.get("rects", [])
	if frame >= 0 and frame < rects.size():
		var r = rects[frame]
		if typeof(r) == TYPE_DICTIONARY:
			return Rect2(float(r.get("x", 0.0)), float(r.get("y", 0.0)), float(r.get("w", 0.0)), float(r.get("h", 0.0)))
	var t: Texture2D = m.get("tex")
	if t != null:
		return Rect2(0, 0, t.get_width(), t.get_height())
	return Rect2()

static func has_fx(image: String) -> bool:
	return not fx(image).is_empty()

# ---- (b) 单位 sprite 自动提亮（grade）----
# 依据：ra2pipe 体素着色下限 shade = 0.42 + 0.58*max(0,N·L) 整体压暗，且部分素材本身偏暗
# （CMIN 车体 R36 G37 B39 中性深灰、未走房色 ramp）。实测不透明像素均值：
#   CMIN 37.6（最暗） / MTNK 59.4 / E1 57.6 / 建筑 92–127。
# 做法：把每个 sprite 的不透明像素平均亮度向 GRADE_TARGET 靠拢（只提不压、带上限），
# 缓存到 _grade_cache。纯代码、可逆：GRADE_TARGET 置 0 即整体关闭。
# 该值直接作为 draw_texture_rect_region 的 modulate（见 unit.gd _draw_ra2_sprite）。
const GRADE_TARGET := 58.0     # ≈ 现役单位中位亮度（MTNK/E1）；高于此值的素材保持原样
const GRADE_MAX_LIFT := 1.6    # 提亮上限，防止极端暗素材被拉爆
static var _grade_cache: Dictionary = {}

## 单 sprite 的提亮 modulate。同一 key 只算一次。返回 Color(lift,lift,lift)。
static func sprite_grade(m: Dictionary) -> Color:
	if m.is_empty() or not m.has("tex") or m.get("palette_lit",false) or GRADE_TARGET <= 0.0:
		return Color.WHITE
	var key := str(m.get("key", ""))
	if key == "":
		return Color.WHITE
	if _grade_cache.has(key):
		return _grade_cache[key]
	var g := Color.WHITE
	var tex: Texture2D = m.get("tex")
	if tex != null:
		var img := tex.get_image()
		if img != null:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			var w := img.get_width()
			var h := img.get_height()
			var px := w * h
			if px > 0:
				# 均匀抽样（沿行主序字节流跨步），~2 万样本 -> 均值稳定且快
				var data := img.get_data()
				var stride := maxi(1, px / 20000)
				var sum := 0.0
				var n := 0
				var i := 0
				while i < px:
					var b := i * 4
					if data[b + 3] > 8:
						sum += (float(data[b]) + float(data[b + 1]) + float(data[b + 2])) / 3.0
						n += 1
					i += stride
				if n > 0:
					var mean := sum / float(n)
					if mean > 1.0:
						var lift: float = clampf(GRADE_TARGET / mean, 1.0, GRADE_MAX_LIFT)
						g = Color(lift, lift, lift)
	_grade_cache[key] = g
	return g


static func _load(id: String) -> Dictionary:
	if id == "":
		return {}
	var directory := "res://assets/ra3/mirage/" if id.begins_with("R3MIRAGE") else VXL_DIR
	var vp := directory + id + ".png"
	if ResourceLoader.exists(vp):
		var tex := load(vp) as Texture2D
		if tex != null:
			if _vehicle_centers.is_empty():
				var path := "res://assets/ra2/vehicle_selection_centers.json"
				if FileAccess.file_exists(path):
					var baked = JSON.parse_string(FileAccess.get_file_as_string(path))
					if baked is Dictionary: _vehicle_centers = baked
			var fac := 8
			var fw := 0.0
			var fh := 0.0
			var jp := directory + id + ".json"
			var extra: Dictionary = {}
			if FileAccess.file_exists(jp):
				var j = JSON.parse_string(FileAccess.get_file_as_string(jp))
				if typeof(j) == TYPE_DICTIONARY:
					fac = int(j.get("facings", 8))
					fw = float(j.get("frameW", 0.0))
					fh = float(j.get("frameH", 0.0))
					extra = { "turret": str(j.get("turret", "")), "dmg": int(j.get("dmg", 1)), "count": int(j.get("count", 0)),
						"split_shadow": bool(j.get("split_shadow", false)),
						"detail_scale": float(j.get("detail_scale", 1.0)), "palette_lit": bool(j.get("palette_lit",false)),
						"facing_offset": int(j.get("facing_offset", 0)),
						"poses": int(j.get("poses", 1)), "fps": float(j.get("fps", 0.0)), "draw_offset": j.get("draw_offset", [0, 0]), "fixed_anchor": j.get("fixed_anchor", []) }
			if fw <= 0.0:
				fw = float(tex.get_width()) / float(maxi(1, fac))
			if fh <= 0.0:
				fh = float(tex.get_height())
			var ov := { "kind": "vxl", "key": id, "tex": tex, "facings": fac, "fw": fw, "fh": fh }
			ov.merge(extra, true)
			# Detail atlas uses twice the pixels, while all layout/hit/muzzle coordinates
			# continue to use the native atlas. No unit size or selection scale change.
			if float(extra.get("detail_scale", 1.0)) == 2.0:
				var detail_path := directory + id + "_detail.png"
				if ResourceLoader.exists(detail_path):
					var detail := load(detail_path) as Texture2D
					if detail != null and detail.get_size() == tex.get_size() * 2.0:
						ov["detail_tex"] = detail
					else: push_error("Invalid voxel detail atlas: " + id)
				else: push_error("Missing voxel detail atlas: " + id)
				# Missing detail must fall back at native source coordinates.
				if not ov.has("detail_tex"): ov["detail_scale"] = 1.0
			return ov
	var sp := SHP_DIR + id + ".png"
	if ResourceLoader.exists(sp):
		var tex2 := load(sp) as Texture2D
		if tex2 != null:
			var rects: Array = []
			var extra2: Dictionary = {}
			if FileAccess.file_exists(SHP_DIR + id + ".json"):
				var j2 = JSON.parse_string(FileAccess.get_file_as_string(SHP_DIR + id + ".json"))
				if typeof(j2) == TYPE_DICTIONARY:
					var rr = j2.get("rects", [])
					if typeof(rr) == TYPE_ARRAY:
						rects = rr
					extra2 = { "dmg": int(j2.get("dmg", 1)), "count": int(j2.get("count", 0)), "cell": j2.get("cell", []),
						"fixed_anchor": j2.get("fixed_anchor", []), "wall_layout": j2.get("wall_layout", {}), "baked_layers": j2.get("baked_layers", []) }
			var frame_regions: Array[Rect2] = []
			var full_page := Rect2(Vector2.ZERO, tex2.get_size())
			for region in rects:
				if region is Dictionary:
					frame_regions.append(Rect2(region.get("x", 0), region.get("y", 0), region.get("w", 0), region.get("h", 0)))
				else:
					frame_regions.append(full_page)
			var ov2 := { "kind": "shp", "key": id, "tex": tex2, "rects": rects, "frame_regions": frame_regions }
			ov2.merge(extra2, true)
			if _building_frame_bounds.is_empty():
				var path := "res://assets/ra2/building_frame_bounds.json"
				if FileAccess.file_exists(path):
					var baked = JSON.parse_string(FileAccess.get_file_as_string(path))
					if baked is Dictionary: _building_frame_bounds = baked
			var crops: Array = _building_frame_bounds.get(id, [])
			if not crops.is_empty() and crops.size() == rects.size():
				var by_source := {}
				for i in crops.size():
					var frame: Dictionary = rects[i]
					var box: Array = crops[i]
					by_source[Rect2i(frame.x, frame.y, frame.w, frame.h)] = Rect2(box[0], box[1], box[2], box[3])
				ov2.body_frame_bounds = by_source
			_bind_shp_geometry(ov2)
			if id == "SQD":
				# Swim frames rotate around the native cell centre, with no standing foot.
				var pivot := frame_size(ov2) * 0.5
				ov2["fixed_anchor"] = [pivot.x, pivot.y]
			ov2["detail"] = ShpDetail.manifest(id, tex2.get_size())
			return ov2
	return {}

## Retain current/previous draw pages to avoid reloading an evicted live page. Stationary lists retain
## their references until Godot calls _draw again, so cache eviction is safe.
static func begin_detail_draw(canvas: CanvasItem) -> void:
	if canvas.has_meta("shp_detail_textures"):
		var previous: Dictionary = canvas.get_meta("shp_detail_previous", {})
		previous.clear()
		canvas.set_meta("shp_detail_previous", canvas.get_meta("shp_detail_textures"))
		canvas.set_meta("shp_detail_textures", previous)
## Draw at logical size from a denser atlas, preserving every shared anchor.
## Freeze a draw command without keeping an actor, texture resource or animation clock in the save.
static func remember_sprite(layers: Array, art_data: Dictionary, target: Rect2, source: Rect2, tint: Color) -> void:
	if not target.has_area() or not source.has_area(): return
	var detail: Dictionary = art_data.get("detail", {})
	if not detail.is_empty():
		var entry: Dictionary = detail.lookup.get(Vector4i(source.position.x, source.position.y, source.size.x, source.size.y), {})
		if not entry.is_empty():
			var page_index := int(entry.page)
			if page_index < 0: return
			var geometry: Array = entry.fog_region
			var crop: Rect2 = geometry[1]
			var ratio := target.size / source.size
			layers.append([geometry[0], Rect2(target.position + crop.position * ratio, crop.size * ratio), geometry[2], tint])
			return
	var texture: Texture2D = art_data.get("detail_tex", art_data.get("tex"))
	if texture == null or texture.resource_path.is_empty(): return
	var density := float(art_data.get("detail_scale", 1.0))
	layers.append([texture.resource_path, target, Rect2(source.position * density, source.size * density), tint])

static func draw_sprite(canvas: CanvasItem, art_data: Dictionary, target: Rect2, source: Rect2, tint: Color = Color.WHITE, waterline := INF) -> void:
	if art_data.has("detail") and ShpDetail.draw(canvas, art_data, target, source, tint, waterline): return
	var texture: Texture2D = art_data["detail_tex"] if art_data.has("detail_tex") else art_data.get("tex")
	if texture == null: return
	var density := float(art_data.get("detail_scale", 1.0))
	ShpDetail.draw_region(canvas,texture,target,source if density==1.0 else Rect2(source.position*density,source.size*density),tint,waterline)

## 帧 i 的源矩形（用于 draw_texture_rect_region）
static func src_rect(m: Dictionary, frame: int) -> Rect2:
	if m.is_empty():
		return Rect2()
	var kind := str(m.get("kind", ""))
	if kind == "vxl":
		var fac := int(m.get("facings", 8))
		var fi := posmod(frame, fac)
		var fw := float(m.get("fw", 0.0))
		var fh := float(m.get("fh", 0.0))
		var pose := posmod(frame / fac, maxi(1, int(m.get("poses", 1))))
		return Rect2(VXL_PAD + float(fi) * (fw + VXL_PAD), VXL_PAD + float(pose) * (fh + VXL_PAD), fw, fh)
	if kind == "shp":
		if m.has("frame_regions") and frame >= 0 and frame < m.frame_regions.size():
			return m.frame_regions[frame]
		var rects: Array = m.get("rects", [])
		if frame >= 0 and frame < rects.size():
			var r = rects[frame]
			if typeof(r) == TYPE_DICTIONARY:
				return Rect2(float(r.get("x", 0.0)), float(r.get("y", 0.0)), float(r.get("w", 0.0)), float(r.get("h", 0.0)))
		var t: Texture2D = m.get("tex")
		return Rect2(0, 0, float(t.get_width()), float(t.get_height()))
	return Rect2()

## 单帧画布尺寸（VXL = frameW×frameH；SHP = rects[0] 的 w×h）
static func frame_size(m: Dictionary) -> Vector2:
	if m.is_empty():
		return Vector2.ZERO
	var kind := str(m.get("kind", ""))
	if kind == "vxl":
		return Vector2(float(m.get("fw", 0.0)), float(m.get("fh", 0.0)))
	if kind == "shp":
		var rects: Array = m.get("rects", [])
		if rects.size() > 0:
			var r = rects[0]
			if typeof(r) == TYPE_DICTIONARY:
				return Vector2(float(r.get("w", 0.0)), float(r.get("h", 0.0)))
		var t: Texture2D = m.get("tex")
		if t != null:
			return Vector2(t.get_width(), t.get_height())
	return Vector2.ZERO

# Optional baked crops avoid reading entire building atlases back from the GPU on a hit.
static var _vehicle_centers: Dictionary = {}
static var _building_frame_bounds: Dictionary = {}


# Offline native-alpha geometry avoids retaining a second, decompressed copy of
# entire animation atlases just to locate feet and visible bounds. Custom/unbaked
# frames fall back to the original pixel scan; pixel picking still reads pixels.
static func _bind_shp_geometry(art: Dictionary) -> void:
	if _shp_geometry.is_empty():
		var path := "res://assets/ra2/shp_geometry.json"
		if FileAccess.file_exists(path):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary: _shp_geometry = parsed
	var baked: Dictionary = _shp_geometry.get(art.key, {})
	var size: Array = baked.get("size", [])
	var rows: Array = baked.get("frames", [])
	if size.size()!=2 or Vector2(size[0],size[1])!=art.tex.get_size() or rows.size()!=art.frame_regions.size(): return
	var anchors := {}
	var crops := {}
	for i in rows.size():
		var row: Array = rows[i]
		if row.size()!=12: return
		var source := Rect2i(row[0],row[1],row[2],row[3])
		if source!=Rect2i(art.frame_regions[i]): return
		crops[source] = Rect2(row[4],row[5],row[6],row[7])
		anchors[source] = Rect2(row[8],row[9],row[10],row[11])
	art.body_frame_bounds = crops
	art.foot_bounds = anchors

static func _geometry_anchor(art: Dictionary, frames: Array) -> Vector2:
	var low := Vector2.INF
	var high := -Vector2.INF
	for frame in frames:
		var source := Rect2i(src_rect(art, int(frame)))
		if not art.foot_bounds.has(source): return Vector2.INF
		var bounds: Rect2 = art.foot_bounds[source]
		if not bounds.has_area(): continue
		low = low.min(bounds.position)
		high = high.max(bounds.end)
	return Vector2((low.x+high.x)*0.5, high.y) if low.is_finite() else Vector2.ZERO

static func sprite_image(m: Dictionary) -> Image:
	var tex: Texture2D = m.get("tex")
	if tex == null: return null
	var img: Image = m.get("img")
	if img == null:
		img = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			m["img"] = img
	return img

## 内容锚点（相对帧左上角）：横向内容中心 x、纵向内容底边 y。
## 用于把素材「脚底中点」对齐脚下原点 —— 画布四周有大量透明留白，
## 直接用画布底边做锚点会让步兵整体偏高（实测 E1 偏 31px）。
## 传 frames 为要参与并集的帧号集合：旋转类（载具/步兵朝向）应传全部朝向帧，
## 使锚点在转向时保持稳定、不抖动；建筑传 [0]。
static func anchor(m: Dictionary, frames: Array) -> Vector2:
	var fixed: Array = m.get("fixed_anchor", [])
	if fixed.size() == 2: return Vector2(float(fixed[0]), float(fixed[1]))
	if m.is_empty():
		return Vector2.ZERO
	var tex: Texture2D = m.get("tex")
	if tex == null: return Vector2.ZERO
	var poses: Dictionary = m["pose_anchors"] if m.has("pose_anchors") else m.get_or_add("pose_anchors", {})
	var cached = poses.get(frames)
	if cached != null: return cached
	if m.has("foot_bounds"):
		var baked := _geometry_anchor(m, frames)
		if baked.is_finite():
			poses[frames.duplicate()] = baked
			return baked
	var img := sprite_image(m)
	var res := Vector2.ZERO
	if img != null:
		var left := 2147483647
		var right := -1
		var bottom := -1
		var atlas := Rect2i(Vector2i.ZERO, img.get_size())
		for frame in frames:
			var src := Rect2i(src_rect(m, int(frame)))
			var clipped := src.intersection(atlas)
			if not clipped.has_area(): continue
			var bounds := img.get_region(clipped).get_used_rect()
			if not bounds.has_area(): continue
			bounds.position += clipped.position - src.position
			# Only pixels outside the existing three extrema can move the foot anchor.
			for x in range(bounds.position.x, mini(left, bounds.end.x)):
				for y in range(bounds.position.y, bounds.end.y):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						left = x
						break
				if left == x: break
			for x in range(bounds.end.x - 1, maxi(right, bounds.position.x - 1), -1):
				for y in range(bounds.position.y, bounds.end.y):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						right = x
						break
				if right == x: break
			for y in range(bounds.end.y - 1, maxi(bottom, bounds.position.y - 1), -1):
				for x in range(bounds.position.x, bounds.end.x):
					if img.get_pixel(src.position.x + x, src.position.y + y).a > 0.06:
						bottom = y
						break
				if bottom == y: break
		if right >= 0: res = Vector2((left + right + 1) * 0.5, bottom + 1)
	poses[frames.duplicate()] = res
	return res

## Contiguous unit poses use a fixed-size key instead of hashing every frame
## on each draw. Keep both key forms in the same cache so clearing/replacing
## pose_anchors invalidates either lookup, including live artwork changes.
static func span_anchor(m: Dictionary, span: Vector4i) -> Vector2:
	var fixed: Array = m.get("fixed_anchor", [])
	if fixed.size() == 2: return Vector2(float(fixed[0]), float(fixed[1]))
	if m.is_empty() or m.get("tex") == null: return Vector2.ZERO
	var poses: Dictionary = m["pose_anchors"] if m.has("pose_anchors") else m.get_or_add("pose_anchors", {})
	var cached = poses.get(span)
	if cached != null: return cached
	var frames: Array = range(span.x, span.x + span.y)
	if span.w > 0: frames.append_array(range(span.z, span.z + span.w))
	var result := anchor(m, frames)
	poses[span] = result
	return result

static var _base_diamond_cache: Dictionary = {}

## 建筑底盘菱形（帧内像素坐标）：由素材可见底边（水泥底盘）的左/右角与底尖推得，
## 返回 [T, R, B, L]（上/右/下/左）。用于把选中角标/地基环贴合建筑底盘。
static func base_diamond(m: Dictionary, frames: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if m.is_empty():
		return out
	var key := str(m.get("key", "")) + "|" + str(frames)
	if _base_diamond_cache.has(key):
		return _base_diamond_cache[key]
	var tex: Texture2D = m.get("tex")
	if tex == null:
		return out
	var img: Image = m.get("img")
	if img == null:
		img = tex.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			m["img"] = img
	if img != null:
		var iw := img.get_width()
		var ih := img.get_height()
		for f in frames:
			var src := src_rect(m, int(f))
			var x0 := int(src.position.x)
			var y0 := int(src.position.y)
			var x1 := mini(x0 + int(src.size.x), iw)
			var y1 := mini(y0 + int(src.size.y), ih)
			var minx := 1e9
			var maxx := -1.0
			var miny := 1e9
			var maxy := -1.0
			for y in range(maxi(y0, 0), y1):
				for x in range(maxi(x0, 0), x1):
					if img.get_pixel(x, y).a > 0.06:
						var lx := float(x - x0)
						var ly := float(y - y0)
						minx = minf(minx, lx)
						maxx = maxf(maxx, lx)
						miny = minf(miny, ly)
						maxy = maxf(maxy, ly)
			if maxx < 0.0:
				continue
			var y_thresh := maxy - maxf(1.0, (maxy - miny) * 0.35)
			var blx := 1e9
			var brx := -1.0
			var bly := 0.0
			var bry := 0.0
			for y in range(maxi(y0, 0), y1):
				var ly2 := float(y - y0)
				if ly2 < y_thresh:
					continue
				for x in range(maxi(x0, 0), x1):
					if img.get_pixel(x, y).a > 0.06:
						var lx2 := float(x - x0)
						if lx2 < blx:
							blx = lx2
							bly = ly2
						if lx2 > brx:
							brx = lx2
							bry = ly2
			if brx < 0.0:
				continue
			var l_pt := Vector2(blx, bly)
			var r_pt := Vector2(brx, bry)
			var b_pt := Vector2((blx + brx) * 0.5, maxy + 1.0)
			var t_pt := l_pt + r_pt - b_pt
			out = PackedVector2Array([t_pt, r_pt, b_pt, l_pt])
	_base_diamond_cache[key] = out
	return out

## 世界朝向角（弧度）→ 素材朝向索引（0..facings-1）。
##
## 不能把屏幕方位均分 45° 取整 —— 2:1 等距会把方位角非线性压扁
## （RA2 素材里 facing 0/2/4/6 的屏幕角只有 ±26.57°/±153.4°，并不在 45° 网格上）。
## 正确做法：算出单位前向在本工程屏幕上的方向向量 s（= Iso.dir），再与每个素材朝向
## 在该投影下应有的屏幕方向 u_f 做最近邻匹配。
## u_f 由素材管线的相机方位推导：az_f = 45° - f*(360°/facings)，
## 模型前向为世界 -X 时屏幕方向 = (sin az_f, -0.5*cos az_f)（与 RA2 规范 facing0=正北=屏幕右上一致）。
static var _seq_cache: Dictionary = {}

## 步兵动画帧序：由 art.ini 的 [<image>Sequence] 导出为 res://assets/ra2/shp/<id>.seq.json。
## 返回 { Name: {start, per, facings} }；无则返回 {}。facings=8 表示按朝向分段，=1 表示非朝向连续帧。
static func seq(id: String) -> Dictionary:
	if _seq_cache.has(id):
		return _seq_cache[id]
	var out: Dictionary = {}
	var path := "res://assets/ra2/shp/" + id + ".seq.json"
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(j) == TYPE_DICTIONARY:
			out = j.get("seq", {})
	_seq_cache[id] = out
	return out


## 由序列名 + 朝向索引 + 播放相位取实际帧号（不存在或 per<=0 返回 -1）。
static func seq_frame(seq_table: Dictionary, name: String, facing: int, phase: int) -> int:
	if not seq_table.has(name):
		return -1
	var st = seq_table[name]
	if typeof(st) != TYPE_DICTIONARY:
		return -1
	var per := int(st.get("per", 0))
	if per <= 0:
		return -1
	var start := int(st.get("start", 0))
	var fac := int(st.get("facings", 1))
	if fac > 1:
		return start + posmod(facing, fac) * int(st.get("stride", per)) + posmod(phase, per)
	return start + posmod(phase, per)


static var _bldanim_cache: Dictionary = {}

## 建筑动画层表（RA2 art.ini 原版做法）：返回 [{kind, image, loopStart, loopEnd, rate, frames, shadow, dmg?}]。
##   kind   —— activeanim / activeanimtwo / activeanimthree / activeanimfour / idleanim …
##   image  —— 动画 SHP 的 id，用 art() 取到与主体同 cell 的帧表（所以 offset 可直接复用主体的）
##   frames —— 可见帧数；shadow=true 时黑影帧 = 同一动作的帧号 + frames（SHP 后半就是黑影）
##   dmg    —— 受损态变体（同结构），无则沿用普通帧
static func building_anims(id: String) -> Array:
	if _theater.layers.has(id): return _theater.layers[id]
	if _bldanim_cache.has(id):
		return _bldanim_cache[id]
	var out: Array = []
	# Permanent layers baked into the body must not draw twice (especially shadows).
	var baked: Array = art(id).get("baked_layers", [])
	var path := BLDANIM_DIR + id + ".json"
	if FileAccess.file_exists(path):
		var j = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(j) == TYPE_DICTIONARY:
			var ls = j.get("layers", [])
			if typeof(ls) == TYPE_ARRAY:
				for l in ls:
					if typeof(l) == TYPE_DICTIONARY and not baked.has(str(l.get("image", ""))):
						out.append(l)
	_bldanim_cache[id] = out
	return out


static var _facing_axes: Dictionary = {}

static func facing_index(world_angle: float, facings: int) -> int:
	if facings <= 1:
		return 0
	var s: Vector2 = Iso.dir(Vector2(cos(world_angle), sin(world_angle)))
	if s.length_squared() < 0.000001:
		return 0
	s = s.normalized()
	# Undo the baked 2:1 projection to locate the adjacent art facings.
	# Their projected angular spacing is uneven, so compare in screen space.
	var phase := (PI * 0.25 - atan2(s.x, -2.0 * s.y)) * float(facings) / TAU
	var first := posmod(floori(phase), facings)
	var second := (first + 1) % facings
	var axes: PackedVector2Array
	if _facing_axes.has(facings):
		axes = _facing_axes[facings]
	else:
		for i in facings:
			var az := PI * 0.25 - float(i) * TAU / float(facings)
			axes.append(Vector2(sin(az), -0.5 * cos(az)).normalized())
		_facing_axes[facings] = axes
	var a := s.dot(axes[first])
	var b := s.dot(axes[second])
	var best := first if a > b else second
	if a == b: best = mini(first, second)
	return posmod(best + FACING_OFFSET, facings)


# =====================================================================
# 点击命中判定（WYSIWYG）
# 铁律「判定几何 = 绘制几何」：这里的 base/rect 公式必须与
# Building._draw_ra2_sprite / Unit._draw_ra2_sprite 一字不差，
# 把鼠标世界点反解到「绘制(begin)空间」后按贴图 alpha 判定。
# =====================================================================

## 绘制(begin)空间向量 -> 世界空间向量（Iso.dir 的逆）
static func art_dir(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y / Iso.K).rotated(Iso.eff_angle())


## 可见精灵矩形（绘制空间坐标）。frames 必须与绘制时传给 anchor() 的帧集合一致。
static func draw_rect(m: Dictionary, radius: float, frames: Array, lift: float = 0.0, sc: float = 1.0) -> Rect2:
	if m == null or m.is_empty():
		return Rect2()
	var sz: Vector2 = frame_size(m)
	if sz.x <= 0.0 or sz.y <= 0.0:
		return Rect2()
	var a: Vector2 = anchor(m, frames)
	return Rect2(Vector2(-a.x * sc, radius * 0.35 - a.y * sc - lift), sz * sc)


## 精灵可见像素的世界坐标中心（拖框选择 / 就近判定用，与贴图对齐）。
static func draw_center(origin: Vector2, m: Dictionary, radius: float, frames: Array, lift: float = 0.0, sc: float = 1.0) -> Vector2:
	var r: Rect2 = draw_rect(m, radius, frames, lift, sc)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return origin
	return origin + art_dir(r.get_center())

## Map the nontransparent part of the native frame into the drawing rectangle.
static func visible_sprite_rect(art: Dictionary, target: Rect2, source: Rect2) -> Rect2:
	if not source.has_area(): return Rect2()
	var cache: Dictionary = art.get_or_add("body_frame_bounds", {})
	var key := Rect2i(source)
	if not cache.has(key):
		var image: Image = art.get("img")
		if image == null and art.get("tex") != null:
			image = art.tex.get_image()
			if image != null and image.is_compressed(): image.decompress()
			art["img"] = image
		cache[key] = Rect2(image.get_region(key).get_used_rect()) if image != null else Rect2(Vector2.ZERO, source.size)
	var crop: Rect2 = cache[key]
	var ratio := target.size / source.size
	return Rect2(target.position + crop.position * ratio, crop.size * ratio)

## Voxel canvases also contain room for shadows/turrets. Use a visible hull
## pixel near its own bounding-box center, not the center of transparent padding.
static func visible_unit_center(origin: Vector2, m: Dictionary, radius: float, frames: Array, frame: int, lift: float, sc: float) -> Vector2:
	var rect := draw_rect(m, radius, frames, lift, sc)
	var rows: Array = _vehicle_centers.get(m.get("key", ""), [])
	if frame >= 0 and frame < rows.size():
		var pixel = rows[frame]
		if pixel == null: return origin
		return origin + art_dir(rect.position + Vector2(pixel[0] + 0.5, pixel[1] + 0.5) * sc)
	var centers: Dictionary = m.get("visible_centers", {})
	if not centers.has(frame):
		var src := Rect2i(src_rect(m, frame))
		var img: Image = m.get("img")
		if img == null: return draw_center(origin, m, radius, frames, lift, sc)
		var points: Array[Vector2] = []
		var lower := Vector2.INF
		var upper := -Vector2.INF
		for y in src.size.y:
			for x in src.size.x:
				if img.get_pixelv(src.position + Vector2i(x, y)).a * 255.0 >= 20.0:
					var p := Vector2(x + 0.5, y + 0.5)
					points.append(p)
					lower = lower.min(p)
					upper = upper.max(p)
		if points.is_empty(): return origin
		var middle := (lower + upper) * 0.5
		var nearest := points[0]
		for point in points:
			if point.distance_squared_to(middle) < nearest.distance_squared_to(middle): nearest = point
		centers[frame] = nearest
		m["visible_centers"] = centers
	return origin + art_dir(rect.position + (centers[frame] as Vector2) * sc)


## 世界点是否落在该素材「当前帧的可见像素」上。
## origin —— 对象原点（世界坐标，即 Iso.begin 的锚点）；frame —— 当前实际绘制的帧号。
static func hits_pixel(world_p: Vector2, origin: Vector2, m: Dictionary, radius: float, frames: Array, frame: int, lift: float = 0.0, sc: float = 1.0, alpha_min: int = 20) -> bool:
	if m == null or m.is_empty():
		return false
	var r: Rect2 = draw_rect(m, radius, frames, lift, sc)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return false
	var lp: Vector2 = Iso.dir(world_p - origin)   # 世界点 -> 绘制空间
	if not r.has_point(lp):
		return false
	var img := sprite_image(m)
	if img == null:
		return true
	var src: Rect2 = src_rect(m, frame)
	var px: int = int(src.position.x + floor((lp.x - r.position.x) / sc))
	var py: int = int(src.position.y + floor((lp.y - r.position.y) / sc))
	if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
		return false
	return img.get_pixel(px, py).a * 255.0 >= float(alpha_min)
