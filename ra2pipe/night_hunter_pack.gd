extends SceneTree
## Asset compilation only: preserve source detail; geometry stays in 128-unit coordinates.
## No generated directions, image morphing, optical flow or model projection.
const TILE:=224
const LOGICAL:=128.0
# Source-sheet neighbours protrude into these cells. Insets lie in the clear
# gap before this cell's hull; retain original placement and logical geometry.
const HELI_LEFT_GUTTERS:=[{1:10,14:6},{1:10,2:10,14:8},{1:9,2:14,3:14,14:10,15:7}]

func solid_bounds(tile:Image) -> Rect2i:
	# Almost transparent resampling residue must not define the feet or body size.
	var low:=Vector2i(TILE,TILE)
	var high:=Vector2i(-1,-1)
	for y in tile.get_height():
		for x in tile.get_width():
			if tile.get_pixel(x,y).a<=.2:continue
			low=low.min(Vector2i(x,y))
			high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()

func lamp_center(tile:Image) -> Vector2:
	var total:=0.0;var center:=Vector2.ZERO
	for y in int(tile.get_height()*.72):
		for x in tile.get_width():
			var c:=tile.get_pixel(x,y)
			var weight:=maxf(0,c.r-.65)*maxf(0,c.r-c.g-.25)*c.a
			center+=Vector2(x,y)*weight;total+=weight
	return center/total if total>.001 else Vector2(tile.get_used_rect().get_center())
const HELI_HUBS:=[Vector2(146,84),Vector2(367,80),Vector2(581,77),Vector2(792,73),Vector2(1014,69),Vector2(1236,57),Vector2(1452,44),Vector2(1672,69),Vector2(118,308),Vector2(338,301),Vector2(557,291),Vector2(768,283),Vector2(981,296),Vector2(1205,298),Vector2(1426,295),Vector2(1648,300),Vector2(118,512),Vector2(343,513),Vector2(562,513),Vector2(782,510),Vector2(1004,512),Vector2(1215,514),Vector2(1450,506),Vector2(1671,504),Vector2(112,721),Vector2(332,719),Vector2(557,719),Vector2(783,723),Vector2(1007,728),Vector2(1231,736),Vector2(1461,734),Vector2(1677,736)]

func _initialize() -> void:
	var source:=OS.get_environment("IRON_SKIN_SOURCE")
	var output:=OS.get_environment("IRON_SKIN_OUTPUT")
	if source.is_empty() or output.is_empty():quit(2);return
	for id:String in ["night_owl","rift_hunter"]:
		var poses:=["flight","mid","down"] if id=="night_owl" else ["idle","walk","walk_b"]
		var atlas:=Image.create(TILE*8,TILE*(13 if id=="night_owl" else 12),false,Image.FORMAT_RGBA8)
		var bounds:Array=[];var anchors:Array=[];var hubs:Array=[];var hashes:Array=[];var pose_anchors:Array=[];var lamps:Array=[]
		for pose in poses.size():
			var path:=source.path_join(id+"_"+poses[pose]+".png")
			var image:=Image.load_from_file(path)
			if image==null:quit(3);return
			hashes.append(FileAccess.get_sha256(path))
			var cell:=Vector2(image.get_size())/Vector2(8,4)
			for frame in 32:
				var origin:=Vector2(frame%8,frame/8)*cell
				var next:=origin+cell
				var rect:=Rect2i(Vector2i(origin.round()),Vector2i(next.round()-origin.round()))
				var tile:=image.get_region(rect)
				tile.resize(TILE,TILE,Image.INTERPOLATE_LANCZOS)
				var box:=solid_bounds(tile) if id=="rift_hunter" else tile.get_used_rect()
				if not box.has_area():quit(4);return
				var logical_box:=Rect2(Vector2(box.position)*LOGICAL/TILE,Vector2(box.size)*LOGICAL/TILE)
				bounds.append([logical_box.position.x,logical_box.position.y,logical_box.size.x,logical_box.size.y])
				var inset:int=HELI_LEFT_GUTTERS[pose].get(frame,0) if id=="night_owl" else 0
				var content:=Rect2i(inset,0,TILE-inset,TILE)
				atlas.blit_rect(tile,content,Vector2i(frame%8,pose*4+frame/8)*TILE+Vector2i(inset,0))
				if pose==0:
					var hub:Vector2=(HELI_HUBS[frame]-origin)/cell*LOGICAL if id=="night_owl" else logical_box.get_center()
					var anchor:=hub+Vector2(0,38) if id=="night_owl" else Vector2(logical_box.get_center().x,logical_box.end.y)
					hubs.append([hub.x,hub.y]);anchors.append([anchor.x,anchor.y])
					lamps.append(lamp_center(tile)*LOGICAL/TILE if id=="rift_hunter" else Vector2.ZERO)
				var anchor:=Vector2(anchors[frame][0],anchors[frame][1])
				if id=="rift_hunter":
					if pose>0:anchor.x+=(lamp_center(tile)*LOGICAL/TILE-lamps[frame]).limit_length(20).x
					anchor.y=logical_box.end.y
				pose_anchors.append([anchor.x,anchor.y])
		var stem:=id+"_direct32"
		if id=="night_owl":
			var plume:=Image.load_from_file("res://assets/cosmetics/mounts/future_phase_exhaust.png")
			plume.resize(TILE*3,TILE,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(plume,Rect2i(0,0,TILE*3,TILE),Vector2i(0,TILE*12))
		atlas.save_webp(output.path_join(stem+".webp"),false)
		var encoded:=Image.load_from_file(output.path_join(stem+".webp"))
		if encoded.get_data()!=atlas.get_data():push_error("Lossless atlas roundtrip changed pixels");quit(5);return
		var meta:={"method":"direct AI directional sprites; no frame fusion","tile":int(LOGICAL),"texture_tile":TILE,"facings":32,"poses":poses,"columns":8,"anchors":anchors,"pose_anchors":pose_anchors,"rotor_centers":hubs,"rotor_radius_pixels":58,"bounds":bounds,"source_sha256":hashes}
		if id=="night_owl":meta.exhaust_uv=[0.0,12.0/13.0,3.0/8.0,1.0/13.0]
		FileAccess.open(output.path_join(stem+".json"),FileAccess.WRITE).store_string(JSON.stringify(meta))
		print("DIRECT32_PACK ",stem," ",atlas.get_size()," 96 authored frames")
	quit()
