extends SceneTree
## Offline: run with --path iron_tide --script ../ra2pipe/molten_fracture_bake.gd.
## IRON_BAKE_OUTPUT supplies the destination PNG. Requires a graphics renderer.

class Tile extends Node2D:
	const GLOW := preload("res://assets/cosmetics/weapons/signature_glow.svg")
	const EMBER := Color("#ff662d")
	const GOLD := Color("#ffe28b")
	var t:float
	var golden:bool
	func _draw() -> void:
		var fade:=1-smoothstep(0.38,1,t)
		var front:=smoothstep(0,0.24,t)
		var ink:=GOLD if golden else Color("#b72c21")
		var glow_size:=Vector2(93,52)*(0.65+0.45*front)
		draw_texture_rect(GLOW,Rect2(-glow_size/2,glow_size),false,Color(EMBER if golden else Color("#a82a29"),fade*0.83))
		for i in 7:
			var a:=i*TAU/7+0.18
			var ray:=Vector2.from_angle(a)
			var reach:=(21+(i*11)%17)*front
			var mid:=ray.rotated(0.22*sin(i*2.7))*reach*0.48
			var kink:=ray.rotated(-0.18)*reach*0.72
			var end:=ray*reach
			var plane:=Vector2(1,0.58)
			var path:=PackedVector2Array([Vector2.ZERO,mid*plane,kink*plane,end*plane])
			draw_polyline(path,Color(Color("#481b24"),fade),4.2,true)
			draw_polyline(path,Color(ink,fade),1.9,true)
			draw_line(mid*plane,mid*plane+ray.rotated(0.7)*plane*reach*0.32,Color(ink,fade),1.2,true)
			var flake:=(end*0.78+ray.orthogonal()*3)*plane*front+Vector2.UP*(5+i%4*3)*sin(t*PI)
			var facet:=PackedVector2Array([flake-ray*3,flake+ray.orthogonal()*1.8,flake+ray*4,flake-ray.orthogonal()*2])
			draw_colored_polygon(facet,Color(Color("#8b4b29") if golden else Color("#59322f"),fade))
			draw_line(facet[0],facet[1],Color(ink,fade),1.1,true)
			var spark:=end*plane*t+Vector2.UP*(7+i%4*3)*sin(t*PI)
			draw_line(spark,spark+ray*2.7,Color(ink,fade),1.4,true)
		if golden:
			var flash:=1-smoothstep(0.08,0.55,t)
			draw_circle(Vector2.ZERO,2+3*flash,Color(Color.WHITE,flash))
			draw_line(Vector2.LEFT*18*flash,Vector2.RIGHT*18*flash,Color(GOLD,flash),1.7,true)


func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var output:=OS.get_environment("IRON_BAKE_OUTPUT")
	if output.is_empty() or DisplayServer.get_name()=="headless":
		quit(2)
		return
	var viewport:=SubViewport.new()
	viewport.size=Vector2i(2160,640)
	viewport.world_2d=World2D.new()
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	for i in 50:
		var tile:=Tile.new()
		tile.t=float(i%25)/24.0
		tile.golden=i>=25
		tile.position=Vector2(i%10+0.5,i/10+0.5)*Vector2(216,128)
		tile.scale=Vector2.ONE*2
		viewport.add_child(tile)
	await RenderingServer.frame_post_draw
	var frame:=viewport.get_texture().get_image()
	# Canvas targets are premultiplied. Store straight alpha for a normal sprite.
	for y in frame.get_height():
		for x in frame.get_width():
			var c:=frame.get_pixel(x,y)
			if c.a>0.0 and c.a<1.0:
				frame.set_pixel(x,y,Color(c.r/c.a,c.g/c.a,c.b/c.a,c.a))
	var err:=frame.save_png(output)
	viewport.queue_free()
	quit(0 if err==OK else 1)
