extends RefCounted
## Run only on the logger's writer thread, after its append-only checkpoints drain.
## Stream windows to disk; memory use depends on registered functions, not battle length.

static func write(path: String, reason: String) -> String:
	var source := FileAccess.open(path+".jsonl",FileAccess.READ)
	if source==null: return path+".jsonl: "+error_string(FileAccess.get_open_error())
	var parser := JSON.new()
	var parse_error := parser.parse(source.get_line())
	var header = parser.data
	if parse_error!=OK or not header is Dictionary or header.get("kind")!="start":
		source.close()
		return path+".jsonl: missing session header"
	var temp := path+".json.tmp"
	var output := FileAccess.open(temp,FileAccess.WRITE)
	if output==null:
		source.close()
		return temp+": "+error_string(FileAccess.get_open_error())
	var written := output.store_string('{"schema":1,"header":'+JSON.stringify(header)+',"windows":[')
	var summary := {"export_complete":true,"end_reason":reason,"windows":0,"frames":{"count":0,"mean_ms":0.0,"max_ms":0.0,"percentiles":"See individual windows; window percentiles are not averaged."},
		"paused_or_transition_s":0.0,"path_requests":0,"path_failures":0,"sampled_peak_units":0,"sampled_peak_buildings":0}
	var functions := {}
	var total_frame_ms := 0.0
	var histogram := PackedInt64Array()
	histogram.resize(5001)
	var histogram_complete := true
	var over_60fps := 0
	var over_15fps := 0
	var last: Dictionary = header
	while source.get_position()<source.get_length():
		var line := source.get_line()
		if line.is_empty(): continue
		parse_error=parser.parse(line)
		var record = parser.data
		if parse_error!=OK or not record is Dictionary or not record.get("functions") is Array or not record.get("frames") is Dictionary or record.get("session")!=header.session:
			return fail(source,output,temp,path+".jsonl: invalid or incomplete window")
		written=output.store_string(("," if summary.windows>0 else "")+"\n"+line) and written
		summary.windows+=1
		last=record
		summary.frames.count+=int(record.frames.count)
		total_frame_ms+=float(record.frames.mean_ms)*int(record.frames.count)
		summary.frames.max_ms=maxf(summary.frames.max_ms,record.frames.max_ms)
		if record.frames.has("histogram"):
			var counted := 0
			for bin in record.frames.histogram:
				if not bin is Array or bin.size()!=2 or int(bin[0])<0 or int(bin[0])>=histogram.size() or int(bin[1])<0:
					return fail(source,output,temp,"invalid frame histogram")
				histogram[int(bin[0])]+=int(bin[1])
				counted+=int(bin[1])
			if counted!=int(record.frames.count):return fail(source,output,temp,"frame histogram count mismatch")
			over_60fps+=int(record.frames.over_60fps_budget)
			over_15fps+=int(record.frames.over_15fps_budget)
		else: histogram_complete=false # Historical checkpoints have window percentiles only.
		summary.paused_or_transition_s+=float(record.paused_or_transition_s)
		summary.path_requests+=int(record.path_requests)
		summary.path_failures+=int(record.path_failures)
		summary.sampled_peak_units=maxi(summary.sampled_peak_units,int(record.units.total))
		summary.sampled_peak_buildings=maxi(summary.sampled_peak_buildings,int(record.buildings.total))
		for row: Dictionary in record.functions: accumulate(functions,row)
	summary.frames.mean_ms=total_frame_ms/maxi(1,int(summary.frames.count))
	if histogram_complete:
		summary.frames.percentiles="Whole session histogram; 1ms upper buckets; values at 5000ms are lower bounds."
		summary.frames.p50_ms=percentile(histogram,int(summary.frames.count),0.50)
		summary.frames.p95_ms=percentile(histogram,int(summary.frames.count),0.95)
		summary.frames.p99_ms=percentile(histogram,int(summary.frames.count),0.99)
		summary.frames.over_60fps_budget=over_60fps
		summary.frames.over_15fps_budget=over_15fps
	summary.session_wall_s=float(last.session_wall_s)
	summary.session_sim_s=float(last.get("session_sim_s",0.0))
	summary.effective_speed=summary.session_sim_s/summary.session_wall_s if summary.session_wall_s>0.0 else 0.0
	summary.battle_ended=bool(last.get("battle_ended",false))
	summary.functions=functions.values()
	var by_calls: Array=summary.functions.duplicate()
	by_calls.sort_custom(func(a,b):return a.calls>b.calls)
	var by_time: Array=summary.functions.duplicate()
	by_time.sort_custom(func(a,b):return a.estimated_inclusive_ms>b.estimated_inclusive_ms)
	summary.top_calls=by_calls.slice(0,20).map(func(row):return row.name)
	summary.top_estimated_time=by_time.slice(0,20).map(func(row):return row.name)
	written=output.store_string('],"summary":'+JSON.stringify(summary)+"}\n") and written
	var read_error := source.get_error()
	if read_error!=OK and read_error!=ERR_FILE_EOF: return fail(source,output,temp,error_string(read_error))
	source.close()
	output.flush()
	var error := output.get_error()
	output.close()
	if not written or error!=OK:
		DirAccess.remove_absolute(temp)
		return temp+": write failed ("+error_string(error)+")"
	error=DirAccess.rename_absolute(temp,path+".json")
	if error!=OK:
		DirAccess.remove_absolute(temp)
		return path+".json: "+error_string(error)
	return ""

static func percentile(histogram: PackedInt64Array, count: int, fraction: float) -> int:
	if count<=0:return 0
	var required:=ceili(count*fraction)
	var seen:=0
	for i in histogram.size():
		seen+=histogram[i]
		if seen>=required:return i
	return histogram.size()-1

static func accumulate(totals: Dictionary, row: Dictionary) -> void:
	if not totals.has(row.name):
		totals[row.name]=row.duplicate()
		return
	var total: Dictionary=totals[row.name]
	total.iterations=int(total.get("iterations",0))+int(row.get("iterations",0))
	for key in ["calls","timed_calls","sampled_total_ms","estimated_inclusive_ms"]: total[key]+=row[key]
	total.sampled_max_ms=maxf(total.sampled_max_ms,row.sampled_max_ms)
	total.sampled_mean_us=total.sampled_total_ms*1000.0/total.timed_calls if total.timed_calls>0 else 0.0

static func fail(source: FileAccess, output: FileAccess, temp: String, message: String) -> String:
	source.close()
	output.close()
	DirAccess.remove_absolute(temp)
	return message
