extends SceneTree
## Converts the two approved-layout AI source sheets into compact game tiles.
## No pose synthesis, mirroring, angle blending, or changes to the source files.
const TILE=192

func _initialize() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:push_error("Expected base-sheet offset-sheet output-directory");quit(2);return
	var sheets:Array[Image]=[]
	for path in [args[0],args[1]]:
		var sheet:=Image.load_from_file(path)
		if sheet==null or sheet.is_empty():push_error("Cannot load "+path);quit(2);return
		sheet.convert(Image.FORMAT_RGBA8);sheets.append(sheet)
	var atlas:=Image.create(TILE*8,TILE*4,false,Image.FORMAT_RGBA8)
	var data:Dictionary={"tile":TILE,"facings":32,"bounds":[],"anchors":[],"reactors":[],"coils":[],"source_sizes":[],"source_sha256":[]}
	for i in 2:
		data.source_sizes.append([sheets[i].get_width(),sheets[i].get_height()])
		data.source_sha256.append(FileAccess.get_sha256(args[i]))
	for frame in 32:
		var sheet:Image=sheets[frame%2]
		var cell:=frame/2
		var left:=int(cell%4*sheet.get_width()/4.0)
		var top:=int(cell/4*sheet.get_height()/4.0)
		var right:=int((cell%4+1)*sheet.get_width()/4.0)
		var bottom:=int((cell/4+1)*sheet.get_height()/4.0)
		var tile:=sheet.get_region(Rect2i(left,top,right-left,bottom-top))
		var bounds:=visible_bounds(tile)
		if not bounds.has_area() or bounds.position.x<4 or bounds.position.y<4 or bounds.end.x>tile.get_width()-4 or bounds.end.y>tile.get_height()-4:
			push_error("Unsafe cell boundary at frame "+str(frame));quit(2);return
		# Orange glass in the upper half identifies the reactor, excluding rear grille lamps.
		var center:=Vector2.ZERO;var weight:=0.0
		for y in range(bounds.position.y,int(bounds.position.y+bounds.size.y*.48)):
			for x in range(bounds.position.x,bounds.end.x):
				var color:=tile.get_pixel(x,y)
				if color.a>.8 and color.r>.75 and color.g>.22 and color.g<.83 and color.b<.3:
					center+=Vector2(x,y);weight+=1
		if weight<8:push_error("Reactor not found at frame "+str(frame));quit(2);return
		center/=weight
		var ratio:=Vector2(TILE/float(tile.get_width()),TILE/float(tile.get_height()))
		var pivot:=center+Vector2(0,280*.28)
		var coil:=center-Vector2(0,bounds.size.y*.075)
		data.anchors.append(pair(pivot*ratio));data.reactors.append(pair(center*ratio));data.coils.append(pair(coil*ratio))
		# Normal asset conversion; preserve authored alpha and use mipmaps on import.
		tile.fix_alpha_edges();tile.resize(TILE,TILE,Image.INTERPOLATE_LANCZOS)
		var visible:=visible_bounds(tile)
		data.bounds.append([visible.position.x,visible.position.y,visible.size.x,visible.size.y])
		atlas.blit_rect(tile,Rect2i(0,0,TILE,TILE),Vector2i(frame%8,frame/8)*TILE)
	DirAccess.make_dir_recursive_absolute(args[2])
	var image_path:=args[2].path_join("leizhu_copper_32.webp")
	if atlas.save_webp(image_path,true,.95)!=OK:push_error("Cannot save atlas");quit(2);return
	FileAccess.open(args[2].path_join("leizhu_copper_32.json"),FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print("Packed 32 authored directions: ",image_path," bytes=",FileAccess.get_file_as_bytes(image_path).size())
	quit()

func pair(value:Vector2) -> Array:
	return [snappedf(value.x,.001),snappedf(value.y,.001)]

func visible_bounds(image:Image) -> Rect2i:
	var low:=Vector2i(image.get_width(),image.get_height());var high:=Vector2i(-1,-1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a<20.0/255:continue
			low=low.min(Vector2i(x,y));high=high.max(Vector2i(x,y))
	return Rect2i(low,high-low+Vector2i.ONE) if high.x>=0 else Rect2i()
