extends RefCounted

const Book=preload("res://scripts/units/yuriko_school.gd")
const Bonds=preload("res://scripts/units/yuriko_bonds.gd")
const PINK:=Color("#ff9bc9")
const ARCHIVE:="百合子支线 · 秘密档案"

const SHELTER := "百合子初遇 · 雨棚"
const COAST := "yr_oceansid"

const Research = preload("res://scripts/expedition/research.gd")
const FINDS := {"diary":"日常日记", "fragment":"破碎残章"}

const FIND_ICONS := {"diary":"school_diary", "fragment":"school_fragment"}
const Icons = preload("res://scripts/ui/progression_icon.gd")

static func find_stage(run:Dictionary) -> bool:
	var stage := int(run.get("stage",0))
	return stage > 0 and (stage - 1) % 4 == 0

static func encounter(run:Dictionary, map:String) -> bool:
	return not Book.met() and (map==COAST or run.get("yuriko_recruited",false) or maxi(Research.rank(run,"intel"),Research.current_level("intel"))>0)

static func next_fragment() -> int:
	var owned:Dictionary=MetaProgress.yuriko_school.get("fragments",{})
	for story:Dictionary in Bonds.stories:
		if not owned.has(str(int(story.fragment))):return int(story.fragment)
	return 0

static func find_kind(run:Dictionary) -> String:
	if not find_stage(run):return ""
	if int(run.stage)%8==5 and next_fragment()>0:return "fragment"
	return "diary"

static func prepare_finds(field,run:Dictionary) -> void:
	var data:Dictionary=field.data
	var kind:=find_kind(run)
	if data.has("school_finds"):
		var saved:Dictionary=data.school_finds
		if saved.has("diary") and saved.has("fragment"):
			var keep:=kind if saved.has(kind) else "diary"
			if saved.diary.taken:keep="diary"
			elif saved.fragment.taken:keep="fragment"
			var other:="fragment" if keep=="diary" else "diary"
			if saved[other].taken:data.school_extra_fragment=saved[other].fragment
			saved.erase(other)
		return
	if kind.is_empty() or not (Book.met() or run.get("yuriko_recruited",false)):return
	for o:Dictionary in data.objectives:
		if o.has("school_gift") and o.get("done",false):return # Preserve already earned checkpoint loot.
	var home:Vector2=field.world.player_start()
	var enemy:Vector2=field.world.enemy_base_center
	var occupied:Array=field.occupied_points()
	for key in ["shelter_at","archive_at"]:
		if data.has(key):occupied.append(data[key])
	var finds:Dictionary={}
	var fragment:=next_fragment() if kind=="fragment" else 0
	var preferred:=home.lerp(enemy,.43)+home.direction_to(enemy).orthogonal()*(850 if kind=="diary" else -850)
	var at:Vector2=field.find_site(preferred,occupied)
	if not at.is_finite():return
	finds[kind]={"position":at,"taken":false,"fragment":fragment}
	if kind=="diary":
		var receipts:Dictionary=MetaProgress.yuriko_school.get("field_receipts",{})
		finds.diary.gift=Bonds.GIFTS.keys()[receipts.size()%Bonds.GIFTS.size()]
	for o:Dictionary in data.objectives:
		o.erase("school_gift")
		o.erase("school_fragment")
	data.school_finds=finds

static func setup(field,run:Dictionary,restored:=false) -> void:
	var data:Dictionary=field.data
	if not restored and find_stage(run):Bonds.attach(data.objectives,next_fragment() if find_kind(run)=="fragment" else 0)
	var hidden:bool=not data.has("shelter_at") and encounter(run,run.route.map)
	var pages:=Book.pages_open()
	var archive:bool=not restored and pages>=4 and pages<Book.chapter_total() and Book.chapter_count()>=pages and run.get("yuriko_recruited",false)
	if not restored and pages in [1,2,3] and Book.chapter_count()>=pages:data.school_page=pages+1
	if not hidden and not archive:return
	var home:Vector2=field.world.player_start()
	var target:Vector2=field.world.enemy_base_center
	var preferred:=home.lerp(target,.36)+home.direction_to(target).orthogonal()*660.0
	var site:Vector2=field.find_site(preferred,field.occupied_points())
	if not site.is_finite():return
	if hidden:data.shelter_at=site
	else:
		data.archive_at=site
		data.archive_page=pages+1

static func tick(field) -> void:
	var data:Dictionary=field.data
	for kind:String in data.get("school_finds",{}):
		var item:Dictionary=data.school_finds[kind]
		if not item.taken and field.missions.visitor(item.position)!=null:
			item.taken=true
			Events.emit_message("百合子支线 · 已找到%s，获胜后带回。"%FINDS[kind],PINK)
	if data.has("shelter_at") and not data.get("shelter_heard",false):
		if not data.get("shelter_found",false) and field.missions.visitor(data.shelter_at)!=null:data.shelter_found=true
		if data.get("shelter_found",false) and Music.cue not in Music.SUPERWEAPON_CUES:
			Music.play_cue("yuriko_tension")
			if Music.cue=="yuriko_tension":
				data.shelter_heard=true
				Events.emit_message("百合子支线 · 雨棚里传来了饭盒声。赢下本场即可带回第一章。",PINK)
	if data.has("archive_at") and not data.get("archive_taken",false):
		var u=preload("res://scripts/units/yuriko.gd").hero(field.world)
		if u!=null and field.missions.operable(u) and field.missions.near(u.position,data.archive_at):
			data.archive_taken=true
			Events.emit_message("百合子收起秘密档案。胜利后带回下一章。",PINK)

static func marker(data:Dictionary) -> Dictionary:
	return {"key":"school_archive","position":data.archive_at,"title":ARCHIVE,"optional":true,"preferred":true,"color":PINK,"status":"done" if data.get("archive_taken",false) else "active"}

static func draw(field) -> void:
	var data:Dictionary=field.data
	var canvas:Transform2D=field.get_global_transform_with_canvas()
	for kind:String in data.get("school_finds",{}):
		var item:Dictionary=data.school_finds[kind]
		if item.taken:continue
		var pos:Vector2=canvas*Vector2(item.position)
		field.draw_set_transform_matrix(canvas.affine_inverse())
		field.draw_arc(pos,21,0,TAU,32,PINK,3)
		field.draw_texture_rect(Icons.texture(FIND_ICONS[kind]),Rect2(pos-Vector2(16,16),Vector2(32,32)),false)
		field.draw_string(ThemeDB.fallback_font,pos-Vector2(90,25),FINDS[kind],HORIZONTAL_ALIGNMENT_CENTER,180,15,PINK)
		field.draw_set_transform_matrix(Transform2D.IDENTITY)
	if data.has("shelter_at") and not data.get("shelter_heard",false):
		var pin:Vector2=canvas*Vector2(data.shelter_at)
		field.draw_set_transform_matrix(canvas.affine_inverse())
		field.draw_arc(pin,20,0,TAU,32,PINK,3)
		field.draw_string(ThemeDB.fallback_font,pin-Vector2(100,28),SHELTER,HORIZONTAL_ALIGNMENT_CENTER,200,15,PINK)
		field.draw_set_transform_matrix(Transform2D.IDENTITY)
	if data.has("shelter_at") and field.world.position_explored_by("ally",data.shelter_at):
		var anchor:Vector2=canvas*Vector2(data.shelter_at)
		var scale:=canvas.get_scale().length()/sqrt(2.0)
		field.draw_set_transform_matrix(canvas.affine_inverse()*Transform2D(0,Vector2.ONE*scale,0,anchor))
		var timber:=Color("#65584d")
		for x in [-22,21]:field.draw_line(Vector2(x,-23),Vector2(x,5),timber,3)
		field.draw_line(Vector2(-18,-5),Vector2(17,-5),Color("#9a7f67"),5)
		field.draw_colored_polygon(PackedVector2Array([Vector2(-30,-24),Vector2(-21,-36),Vector2(29,-33),Vector2(22,-21)]),Color("#798d87"))
		field.draw_line(Vector2(-30,-24),Vector2(22,-21),Color("#495f60"),3)
		field.draw_set_transform_matrix(Transform2D.IDENTITY)
	if data.has("archive_at") and not data.get("archive_taken",false):
		var at:Vector2=data.archive_at
		field.draw_arc(at,72,0,TAU,36,PINK,3)
		field.draw_set_transform_matrix(canvas.affine_inverse())
		var p:Vector2=canvas*at
		field.draw_rect(Rect2(p-Vector2(10,16),Vector2(20,24)),Color("#622c54"))
		field.draw_rect(Rect2(p-Vector2(10,16),Vector2(20,24)),PINK,false,2)
		field.draw_string(ThemeDB.fallback_font,p-Vector2(95,23),ARCHIVE,HORIZONTAL_ALIGNMENT_CENTER,190,15,PINK)
		field.draw_set_transform_matrix(Transform2D.IDENTITY)
