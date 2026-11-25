extends RefCounted

const IDS := ["fleet_cannon", "fleet_rockets", "fv_intercept", "v3_cluster"]

static func value(preview) -> int:
	var row: Dictionary = MetaProgress.talent_options(preview.unit_id)[preview.demo]
	return int(row.base if preview.rank == 0 else row.ranks[preview.rank - 1].value)

static func paint(p, t:float) -> void:
	var n := value(p)
	var origin: Vector2 = p.viewport.canvas_transform * p.actor.position
	var target := Vector2(309,62)
	var text := ""
	match p.demo:
		"fleet_cannon", "fleet_rockets":
			var rockets:bool = p.demo == "fleet_rockets"
			var start := 2.0*n if rockets else 2.0
			var fired := clampi(1+floori((t-start)/0.3),0,n)
			p._marker(target,"敌舰",Color.CORAL)
			for i in n:
				var progress := (t-start-0.3*i)/0.45
				if progress >= 0 and progress <= 1:
					var tip:=origin.lerp(target,progress)
					p.draw_line(tip,tip-origin.direction_to(target)*(13 if rockets else 7),Color.GOLD,3)
				elif progress>1 and progress<1.5:
					p.draw_arc(target,3+12*(progress-1),0,TAU,18,Color.ORANGE,2)
			if rockets and t<start:
				text="航行储弹　%d / %d 枚" % [int(t/2),n]
			else:
				text="%s　已发射 %d / %d 发" % ["火箭齐射" if rockets else "船首机炮扫射",fired,n]
		"fv_intercept":
			var friend:=Vector2(215,84)
			var hit:=Vector2(233,77)
			p._marker(friend,"友军",Color.SKY_BLUE)
			if t<2:
				var incoming:=target.lerp(hit,t/2)
				p.draw_circle(incoming,4,Color.CORAL)
				if t>1.45:p.draw_line(origin,origin.lerp(hit,(t-1.45)/0.55),Color.AQUAMARINE,2)
				text="敌方追踪弹接近友军"
			else:
				if t<2.6:p.draw_arc(hit,3+25*(t-2),0,TAU,24,Color.GOLD,2)
				text="追踪弹已拦截　装填还剩 %.1f 秒" % maxf(0,n-(t-2))
		"v3_cluster":
			var group:=t>=4
			var age:=fmod(t,4.0)
			p._marker(target,"主目标",Color.CORAL)
			if age<1.8:p.draw_circle(origin.lerp(target,age/1.8)-Vector2(0,20*sin(PI*age/1.8)),4,Color.GOLD)
			elif age<2.4:p.draw_arc(target,4+25*(age-1.8),0,TAU,24,Color.ORANGE,2)
			if group:
				for nearby in [target+Vector2(-50,34),target+Vector2(50,30)]:
					p._marker(nearby,"敌军",Color.CORAL)
					if age>=1.8 and age<2.5:p.draw_line(target,target.lerp(nearby,(age-1.8)/0.7),Color.GOLD,2)
			text="敌群　子弹对邻近敌人造成 %d%% 弹头基础伤害"%n if group else "单个目标　整弹直击"
	p.draw_string(ThemeDB.fallback_font,Vector2(5,155),text,HORIZONTAL_ALIGNMENT_CENTER,420,14,Color.WHITE)
