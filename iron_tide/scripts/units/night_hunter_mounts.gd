extends RefCounted
## Fixed hull sockets for the 2D directional skins; existing 3D editors stay separate.
static func draw(actor,rig,lift:float) -> void:
	var style:Dictionary=actor.cosmetic_outfit()
	var scale:float=rig.visual_scale(actor)/(.27 if actor.unit_id=="SCHP" else .21)
	var origin:=Vector2(0,-lift-(23 if actor.unit_id=="SCHP" else 17)*scale)
	var alpha:float=Ra3Mirage.CloakVisual.opacity(actor)
	if style.get("top")=="crystal":
		# Keep the helicopter crystal clear of its main rotor.
		var seat:=origin+Iso.dir(Vector2(-24 if actor.unit_id=="SCHP" else -3,0).rotated(actor.hull_angle))*scale
		var peak:=seat+Vector2(0,-11*scale)
		for i in 5:
			var first:=seat+Iso.dir(Vector2.from_angle(TAU*i/5+actor.hull_angle))*4*scale
			var next:=seat+Iso.dir(Vector2.from_angle(TAU*(i+1)/5+actor.hull_angle))*4*scale
			actor.draw_colored_polygon(PackedVector2Array([peak,first,next]),Color(Color("#8af5ff").darkened(i*.09),alpha))
		actor.draw_circle(peak,1.2*scale,Color(.75,1,1,alpha*rig.intensity()),true,-1,true)
	var wing:String=style.get("wing","stock")
	if wing not in ["angel","demon"]:return
	var tint:=Color("#e4eefb") if wing=="angel" else Color("#af354c")
	var flap:=sin(rig.clock*TAU/1.7)*2.5
	for side in [-1,1]:
		var root:=origin+Iso.dir(Vector2(-8,side*8).rotated(actor.hull_angle))*scale
		for feather in 5:
			var reach:=14.0+feather*1.9
			var end:=root+Iso.dir(Vector2(-feather*3.0,side*reach).rotated(actor.hull_angle))*scale-Vector2(0,(8+flap-feather)*scale)
			var a:=root+Vector2(0,feather*.7*scale)
			var b:=end+Vector2(0,(2 if wing=="angel" else -2)*scale)
			actor.draw_colored_polygon(PackedVector2Array([a,end,b,root+Vector2(0,4*scale)]),Color(tint.darkened(feather*.06),alpha*.94))
			actor.draw_line(root,end,Color(tint.lightened(.15),alpha*.8),maxf(.4,scale*.5),true)
