extends SceneTree
## Offline costume bake. Keep every source pose, face, water ripple and native shadow.
const ROOT="res://assets/ra2/shp/"
const DEST="res://assets/cosmetics/skins/"
const TILE=Vector2i(100,80)
const COLS=16

func _initialize() -> void:
	for id in ["TANY","BORIS"]:
		var path:String=ROOT+id
		var atlas:=Image.load_from_file(path+".png")
		var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+".json"))
		var pins:Array=JSON.parse_string(FileAccess.get_file_as_string(DEST+id.to_lower()+"_rig_sockets.json"))
		var sheet:=Image.create_empty(TILE.x*COLS,TILE.y*ceili(float(pins.size())/COLS),false,Image.FORMAT_RGBA8)
		for i in pins.size():
			if pins[i].is_empty():continue
			var r:Dictionary=data.rects[i]
			var frame:=atlas.get_region(Rect2i(r.x,r.y,r.w,r.h))
			var box:=frame.get_used_rect()
			for y in range(box.position.y,box.end.y):
				for x in range(box.position.x,box.end.x):
					var color:=frame.get_pixel(x,y)
					if color.a<=0:continue
					sheet.set_pixel((i%COLS)*TILE.x+x,(i/COLS)*TILE.y+y,costume(id,color,x,y,pins[i],i))
		if sheet.save_png(DEST+id.to_lower()+"_outfit.png")!=OK:
			quit(1)
			return
	quit()

func costume(id:String, c:Color, x:int, y:int, p:Array, frame:int) -> Color:
	var dx:=x-int(p[0])
	var dy:=y-int(p[1])
	var tone:=clampf(c.v*1.55,0,1)
	var skin:=absi(c.r8-c.g8-48)<=2 and absi(c.g8-c.b8-16)<=2
	# The native rifle points across or below the hands in idle frames. Remove its
	# projecting barrel before mounting the soda blaster on the same figure.
	if id=="BORIS" and (frame<86 or (frame>=169 and frame<217) or frame>=401):
		if not skin and absi(dx)>=7 and dy>=-7 and dy<=14:return Color.TRANSPARENT
	if c.v<0.04:return c
	var face:=absi(x-int(p[2]))<=4 and y<=int(p[3])+3
	var tanya:=id=="TANY"
	if tanya and frame>=292 and frame<602 and c.b>c.r and absf(c.r-c.g)<0.025:return c
	if face and skin:return c
	var team:=c.b>c.g and c.g>c.r and absf(c.g*1.516-c.b)<0.018
	if tanya:
		if face:return Color("#522959").lerp(Color("#e58adc"),tone)
		if skin and abs(dx)>3:return Color("#2c2547").lerp(Color("#917bb9"),tone)
		if team and absi(dx)<=1:return c
		if team:return Color("#4c185a").lerp(Color("#ff44b6"),0.38+tone*0.6)
		if absi(dx)>6 and dy<5:return Color("#333750").lerp(Color("#74fff2"),tone)
		if dy>6 and absi(dx)%5==2:return Color("#433559").lerp(Color("#cd40a8"),tone+0.1)
		return Color("#191728").lerp(Color("#70608e"),tone)
	if face:return c
	if skin:return Color("#965943").lerp(Color("#f9c794"),tone)
	# Rifle metal / stock gets the plastic body and chrome highlights of the soda gun.
	if absi(dx)>6 and dy<5:
		return Color("#18596e").lerp(Color("#63efe5"),tone+0.16)
	if dy>=3 and dy<=10:
		if dy==3 or dy==4:return Color("#ffefb2").darkened((1.0-tone)*0.25)
		if posmod(dx+dy,8)<=1:return Color("#ffd181").darkened((1.0-tone)*0.27)
		return Color("#bd4252").lerp(Color("#ff8261"),tone+0.1)
	if team and dy<=1 and absi(dx)>3:return c
	if dy>12 and tone<0.16:return Color("#17777a")
	var sun:=clampf(0.18+tone*0.83+(0.12 if dx<0 else 0.0),0,1)
	return Color("#a35c46").lerp(Color("#ffce9a"),sun)
