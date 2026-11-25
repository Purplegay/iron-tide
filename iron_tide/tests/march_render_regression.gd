extends "res://tests/base_recovery_regression.gd"
class Shadows extends Node2D:
	var use_mesh := false
	func _draw() -> void:
		for row in 4:
			for col in 4:
				var center := Vector2(col*72+40,row*64+40)
				var radius := 8.0 + col*6
				var alpha := 0.15 + row*0.2
				if use_mesh: Iso.shadow(self,center,radius,alpha)
				else:
					for layer in range(3,0,-1):
						var t := float(layer)/3.0
						var r := radius*(0.70+0.30*t)
						draw_colored_polygon(Iso.ell(center,r,r),Color(0,0,0,alpha*(0.26+0.24*t)))

func _ready() -> void:
	output_dir = OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty():get_tree().quit(2);return
	check(is_same(Iso.shadow_mesh(),Iso.shadow_mesh()),"stationary shadow geometry shares one mesh")
	var arrays := Iso.shadow_mesh().surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_VERTEX].size()==72 and arrays[Mesh.ARRAY_INDEX].size()==198,"all three 24-vertex layers retained")
	if DisplayServer.get_name() != "headless":
		var views:Array=[]
		for method in 2:
			var view:=SubViewport.new()
			view.size=Vector2i(320,300)
			view.transparent_bg=true
			view.world_2d=World2D.new()
			view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			add_child(view)
			var drawing:=Shadows.new()
			drawing.use_mesh=method==1
			view.add_child(drawing)
			views.append(view)
		for tilt in [0.5,0.3571,0.7143]:
			for mirrored in [false,true]:
				Iso.K=tilt
				Iso.MIRROR=mirrored
				for view in views:view.get_child(0).queue_redraw()
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var reference:Image=views[0].get_texture().get_image()
				var actual:Image=views[1].get_texture().get_image()
				var changed:=0
				var largest:=0.0
				for y in reference.get_height():
					for x in reference.get_width():
						var error:=absf(reference.get_pixel(x,y).a-actual.get_pixel(x,y).a)
						if error>1.1/255.0:changed+=1
						largest=maxf(largest,error)
				check(changed<32,"shadow reference pixels tilt/mirror "+str(tilt)+str(mirrored),[changed,largest])
		for view in views:view.free()
	var f:=FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
