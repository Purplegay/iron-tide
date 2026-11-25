extends "res://tests/core_draw_reference.gd"
func _draw() -> void:
	if completed:return
	for deployed in [false,true]:
		_deployed=deployed
		for moving in [false,true]:
			velocity=Vector2(10,0) if moving else Vector2.ZERO
			for bearing in [0.0,1.7,4.1]:
				hull_angle=bearing;turret_angle=bearing+0.3
				for firing in [-1.0,0.15]:
					_fire_anim_time=firing
					captured=[]
					_draw_ra2_sprite_uncached(radius)
					var expected:=snapshot()
					captured=[]
					_draw_ra2_sprite(radius)
					comparisons+=1
					if snapshot()!=expected:mismatches.append([deployed,moving,bearing,firing])
	if not _ra2.is_empty():
		_deployed=false;velocity=Vector2.ZERO;_fire_anim_time=-1
		for sample in 20:
			captured=[]
			var begun:=Time.get_ticks_usec()
			for i in 200:
				if (sample%4==0 or sample%4==3):_draw_ra2_sprite_uncached(radius)
				else:_draw_ra2_sprite(radius)
			micro.append({"id":unit_id,"variant":"before" if (sample%4==0 or sample%4==3) else "after","us":Time.get_ticks_usec()-begun,"calls":200,"sprites":captured.size()})
	completed=true

