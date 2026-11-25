extends RefCounted
const MIN_OPACITY:=0.20
const FADE_MSEC:=1000.0
var rows:Dictionary={}
var last_cleanup:int=0

func opacity(subject:Object,selected:bool,now:int) -> float:
	if now-last_cleanup>=2000:
		for key in rows.keys():
			if rows[key].subject.get_ref()==null:rows.erase(key)
		last_cleanup=now
	var id:=subject.get_instance_id()
	if not rows.has(id) or rows[id].subject.get_ref()!=subject:
		rows[id]={"subject":weakref(subject),"selected":selected,"start":now}
	var row:Dictionary=rows[id]
	if selected:
		row.selected=true
		row.start=now
		return 1.0
	if row.selected:
		row.selected=false
		row.start=now
	var elapsed:=clampf(float(now-int(row.start))/FADE_MSEC,0.0,1.0)
	return lerpf(1.0,MIN_OPACITY,elapsed)
