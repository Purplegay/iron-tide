extends "res://tests/base_recovery_regression.gd"
var micro:Array=[]
func _ready() -> void:
	output_dir=OS.get_environment("IRON_TIDE_REPORT_DIR")
	if output_dir.is_empty() or not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2);return
	var arts:Array=[]
	for id in ["E1","GGI","MTNK","APOC","ORCA","DESO","SCHP","GACNST"]:
		var art:Dictionary=RA2Art.art(id)
		check(not art.is_empty(),id+" real art present")
		arts.append(art)
		for span in [Vector4i(0,8,0,0),Vector4i(0,32,0,0),Vector4i(64,8,128,48),Vector4i(2,4,3,5)]:
			var frames:Array=range(span.x,span.x+span.y)
			if span.w>0:frames.append_array(range(span.z,span.z+span.w))
			var expected:Dictionary=art.duplicate();expected.erase("pose_anchors")
			var actual:Dictionary=art.duplicate();actual.erase("pose_anchors")
			for i in 3:
				if i==2:expected.pose_anchors.clear();actual.pose_anchors.clear()
				check(RA2Art.span_anchor(actual,span)==RA2Art.anchor(expected,frames),id+" cold/warm/cleared pose cache equivalent")
			actual.fixed_anchor=[33,42]
			check(RA2Art.span_anchor(actual,span)==Vector2(33,42),"live fixed anchor takes precedence over warm cache")
	for art in [{},{"tex":null},{"fixed_anchor":[11,23]},{"fixed_anchor":[]}]:
		check(RA2Art.span_anchor(art,Vector4i(0,1,0,0))==RA2Art.anchor(art,[0]),"empty/missing art fallback")
	for count in [8,32,256]:
		var span:=Vector4i(0,count,0,0)
		var frames:Array=range(count)
		var sums:Array=[]
		for art in arts:RA2Art.span_anchor(art,span)
		for sample in 14:
			var sum:=Vector2.ZERO
			var begun:=Time.get_ticks_usec()
			for i in 2000:
				for art in arts:sum+=RA2Art.anchor(art,frames) if sample%2==0 else RA2Art.span_anchor(art,span)
			micro.append({"count":count,"variant":"before" if sample%2==0 else "after","us":Time.get_ticks_usec()-begun,"calls":16000})
			sums.append(sum)
		for value in sums:check(value==sums[0] and value.length()>0,"benchmark consumes matching nonzero anchors")
	FileAccess.open(output_dir.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed,"micro":micro}))
	get_tree().quit(0 if failed==0 else 1)
