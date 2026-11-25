extends "res://tests/base_recovery_regression.gd"
const Renderer=preload("res://scripts/units/voxel_renderer.gd")

func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	for id in Renderer.TYPES:
		for suffix in ["","_shd"]:
			var art:=RA2Art.art(id+suffix)
			var prepared=Renderer.atlas(art)
			if prepared==null:continue
			check(is_same(prepared,Renderer.atlas(art)),id+suffix+" shares one resource")
			check(prepared.anchor==RA2Art.anchor(art,range(prepared.facings)),"same native anchor")
			check(prepared.texture==art.get("detail_tex",art.tex),"same submitted atlas texture")
			check(prepared.grade==RA2Art.sprite_grade(art),"same native atlas grade")
			for frame in prepared.facings:
				var source:=RA2Art.src_rect(art,frame)
				var density:=float(art.get("detail_scale",1.0))
				var uv:=source if density==1.0 else Rect2(source.position*density,source.size*density)
				check(prepared.sources[frame]==source and prepared.uvs[frame]==uv,"submitted UV and picking frame "+id+suffix+str(frame))
				var dest:=Rect2(Vector2(-17.25,43.5),prepared.scaled_size)
				var crop:Rect2=prepared.crops[frame]
				var ratio:Vector2=prepared.ratios[frame]
				check(Rect2(dest.position+crop.position*ratio,crop.size*ratio)==RA2Art.visible_sprite_rect(art,dest,source),"same visible bounds")
			check(Renderer.atlas(art.duplicate(true))==null,"private editable art uses generic renderer")
	var first:=Unit.new()
	var second:=Unit.new()
	first.setup(GameData.get_unit("MTNK"),"ally",Vector2.ZERO)
	second.setup(GameData.get_unit("MTNK"),"enemy",Vector2.ONE)
	check(first._voxel_hull!=null and is_same(first._voxel_hull,second._voxel_hull),"units bind shared geometry across owners")
	var original:=first._ra2
	first._ra2=original.duplicate(true)
	check(first._voxel_hull==null and second._voxel_hull!=null,"custom replacement changes only owning binding")
	first._ra2=original
	check(is_same(first._voxel_hull,second._voxel_hull),"restored canonical appearance rebinds shared resource")
	var retained=first._voxel_hull
	RA2Art.clear_cache()
	var reloaded:=RA2Art.art("MTNK")
	second._ra2=reloaded
	check(not is_same(retained,second._voxel_hull) and is_same(second._voxel_hull.art,reloaded),"reload uses new atlas identity")
	check(is_same(first._voxel_hull,retained) and is_same(first._voxel_hull.art,original),"existing actor retains its original resource")
	first.free();second.free()
	check(Renderer.resources["MTNK"].get_ref()==null,"pool releases prepared resource after last owning unit exits")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	get_tree().quit(0 if failed==0 else 1)
