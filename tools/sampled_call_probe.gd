extends RefCounted
# Diagnostic-only sampled inclusive timings. Parent/child times overlap.
static var costs: Dictionary = {}
static var calls: Dictionary = {}
static var samples: Dictionary = {}
static var rng := 104729
var key: String
var begin: int
func _init(k: String):
	key=k
	begin=Time.get_ticks_usec()
func _notification(what):
	if what==NOTIFICATION_PREDELETE:
		costs[key]=int(costs.get(key,0))+Time.get_ticks_usec()-begin
static func enter(k: String) -> RefCounted:
	calls[k]=int(calls.get(k,0))+1
	rng=(rng*1103515245+12345)&0x7fffffff
	if not k.begins_with("fog_of_war.") and not k.begins_with("ra2_art.") and ((rng >> 16)&31)!=0: return null
	samples[k]=int(samples.get(k,0))+1
	return new(k)
