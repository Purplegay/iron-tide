extends SceneTree
## Offline compilation of AI-authored 4-direction / 3-pose groups.
## Alpha component isolation is import cleanup, never angle synthesis or frame fusion.
const TILE:=288
const CONTENT:=280
const PAD:=4
const LOGICAL:=128.0

func solid_bounds(tile:Image) -> Rect2i:
	var low:=tile.get_size();var high:=Vector2i(-1,-1)
	for y in tile.get_height():
		for x in tile.get_width():
			if tile.get_pixel(x,y).a<=.2:continue
			low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()

func isolate(tile:Image) -> Image:
	var size:=tile.get_size();var visited:=PackedByteArray();visited.resize(size.x*size.y)
	var largest:=PackedInt32Array()
	for index in visited.size():
		if visited[index] or tile.get_pixel(index%size.x,index/size.x).a<=.08:continue
		var component:=PackedInt32Array([index]);visited[index]=1;var cursor:=0
		while cursor<component.size():
			var item:=component[cursor];cursor+=1
			var p:=Vector2i(item%size.x,item/size.x)
			for dy in range(-1,2):
				for dx in range(-1,2):
					var next:=p+Vector2i(dx,dy)
					if next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y:continue
					var offset:=next.y*size.x+next.x
					if visited[offset] or tile.get_pixelv(next).a<=.08:continue
					visited[offset]=1;component.append(offset)
		if component.size()>largest.size():largest=component
	var clean:=Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	# Preserve original antialiasing immediately adjacent to the solid component.
	for index in largest:
		var p:=Vector2i(index%size.x,index/size.x)
		for dy in range(-1,2):
			for dx in range(-1,2):
				var next:=p+Vector2i(dx,dy)
				if next.x>=0 and next.y>=0 and next.x<size.x and next.y<size.y:clean.set_pixelv(next,tile.get_pixelv(next))
	return clean

func lamp_center(tile:Image) -> Vector2:
	var total:=0.0;var center:=Vector2.ZERO
	for y in int(tile.get_height()*.72):
		for x in tile.get_width():
			var c:=tile.get_pixel(x,y)
			var weight:=maxf(0,c.r-.65)*maxf(0,c.r-c.g-.25)*c.a
			center+=Vector2(x,y)*weight;total+=weight
	return center/total if total>.001 else Vector2(solid_bounds(tile).get_center())

func _initialize() -> void:
	var source:=OS.get_environment("IRON_SKIN_SOURCE");var output:=OS.get_environment("IRON_SKIN_OUTPUT")
	if source.is_empty() or output.is_empty():quit(2);return
	DirAccess.make_dir_recursive_absolute(output)
	var registration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source.path_join("rotor-registration.json")))
	for id:String in ["night_owl","rift_hunter"]:
		var heli:=id=="night_owl"
		var poses:=["flight","mid","down"] if heli else ["idle","walk","walk_b"]
		var atlas:=Image.create(TILE*8,TILE*(13 if heli else 12),false,Image.FORMAT_RGBA8)
		var bounds:Array=[];var anchors:Array=[];var hubs:Array=[];var hashes:Array=[]
		var pose_anchors:Array=[];var pose_hubs:Array=[];var lamps:Array=[];var sheets:Array[Image]=[]
		for group in 8:
			var path:=source.path_join(id+"_%02d.png"%group)
			var sheet:=Image.load_from_file(path)
			if sheet==null or sheet.get_size()!=Vector2i(1448,1086):push_error("Unexpected source size: "+path);quit(3);return
			sheets.append(sheet);hashes.append(FileAccess.get_sha256(path))
		for pose in 3:
			for frame in 32:
				var group:=frame/4;var column:=frame%4;var origin:=Vector2i(column*362,pose*362)
				var sheet:Image=sheets[group]
				var clean:=isolate(sheet.get_region(Rect2i(origin,Vector2i(362,362))))
				clean.resize(CONTENT,CONTENT,Image.INTERPOLATE_LANCZOS)
				var tile:=Image.create(TILE,TILE,false,Image.FORMAT_RGBA8)
				tile.blit_rect(clean,Rect2i(0,0,CONTENT,CONTENT),Vector2i(PAD,PAD))
				var box:=solid_bounds(tile)
				if not box.has_area():push_error("Empty frame");quit(4);return
				var logical_box:=Rect2(Vector2(box.position)*LOGICAL/TILE,Vector2(box.size)*LOGICAL/TILE)
				bounds.append([logical_box.position.x,logical_box.position.y,logical_box.size.x,logical_box.size.y])
				atlas.blit_rect(tile,Rect2i(0,0,TILE,TILE),Vector2i(frame%8,pose*4+frame/8)*TILE)
				var hub:=logical_box.get_center()
				if heli:
					var point:Array=registration.hubs[group][pose*4+column]
					hub=((Vector2(point[0],point[1])-Vector2(origin))*CONTENT/362.0+Vector2.ONE*PAD)*LOGICAL/TILE
				pose_hubs.append([hub.x,hub.y])
				var anchor:=hub+Vector2(0,38) if heli else Vector2(logical_box.get_center().x,logical_box.end.y)
				if pose==0:
					hubs.append([hub.x,hub.y]);anchors.append([anchor.x,anchor.y])
					lamps.append(lamp_center(tile)*LOGICAL/TILE if not heli else Vector2.ZERO)
				elif not heli:
					anchor.x=float(anchors[frame][0])+(lamp_center(tile)*LOGICAL/TILE-lamps[frame]).limit_length(20).x
				pose_anchors.append([anchor.x,anchor.y])
		var stem:=id+"_direct32"
		if heli:
			var plume:=Image.load_from_file("res://assets/cosmetics/mounts/future_phase_exhaust.png")
			plume.resize(TILE*3,TILE,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(plume,Rect2i(0,0,TILE*3,TILE),Vector2i(0,TILE*12))
		if atlas.save_webp(output.path_join(stem+".webp"),false)!=OK:quit(5);return
		if Image.load_from_file(output.path_join(stem+".webp")).get_data()!=atlas.get_data():push_error("Lossless roundtrip changed pixels");quit(6);return
		var meta:={"method":"direct AI directional sprites; no frame fusion","tile":int(LOGICAL),"texture_tile":TILE,"facings":32,"poses":poses,"columns":8,"anchors":anchors,"pose_anchors":pose_anchors,"rotor_centers":hubs,"pose_rotor_centers":pose_hubs,"rotor_radius_pixels":58,"bounds":bounds,"source_sha256":hashes,"source_layout":"eight groups of 4 facings x 3 poses; 362 px per source cell","revision":"detail-20261117","clear_border":PAD}
		if heli:meta.exhaust_uv=[0.0,12.0/13.0,3.0/8.0,1.0/13.0]
		FileAccess.open(output.path_join(stem+".json"),FileAccess.WRITE).store_string(JSON.stringify(meta))
		print("DETAIL32_PACK ",stem," ",atlas.get_size()," 96 authored frames")
	quit()
