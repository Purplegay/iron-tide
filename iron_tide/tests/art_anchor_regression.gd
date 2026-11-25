extends "res://tests/base_recovery_regression.gd"
const Reference=preload("res://tests/art_anchor_reference.gd")
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var arts:Array=[]
	for id in ["MTNK","E1","GGI","APOC","FV","CMIN","ORCA","GACNST"]:
		var art:Dictionary=RA2Art.art(id)
		check(not art.is_empty(),id+" real art present")
		arts.append(art)
		for frames in [[0],[0,1,2],range(int(art.get("facings",8)))]:
			var old:Dictionary=art.duplicate();old.erase("pose_anchors")
			var fresh:Dictionary=art.duplicate();fresh.erase("pose_anchors")
			check(Reference.anchor(old,frames)==RA2Art.anchor(fresh,frames),id+" cold anchor")
			check(Reference.anchor(old,frames)==RA2Art.anchor(fresh,frames),id+" warm anchor")
			fresh.pose_anchors.clear();old.pose_anchors.clear()
			check(Reference.anchor(old,frames)==RA2Art.anchor(fresh,frames),id+" cleared cache")
	for art in [{},{"tex":null},{"fixed_anchor":[11,23]},{"fixed_anchor":[]}]:
		check(Reference.anchor(art,[0])==RA2Art.anchor(art,[0]),"fallback anchor")
	var checksum:=Vector2.ZERO
	var frames:Array=range(32)
	for art in arts:RA2Art.anchor(art,frames)
	for pass_index in 14:
		var began:=Time.get_ticks_usec()
		for i in 2000:
			for art in arts:
				checksum+=Reference.anchor(art,frames) if pass_index%2==0 else RA2Art.anchor(art,frames)
		micro.append({"variant":"before" if pass_index%2==0 else "after","calls":16000,"us":Time.get_ticks_usec()-began})
	check(checksum.is_finite() and checksum.length()>0,"benchmark consumes anchor results")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
