extends Node

func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation"):
		get_tree().quit(2)
		return
	var screen:=MetaScreen.new()
	add_child(screen)
	var rate:=MetaProgress.hourly_rate()
	MetaProgress.idle={"last_tick_unix":Time.get_unix_time_from_system(),"pending":{"credits":rate.credits/60.0,"cores":rate.cores/60.0}}
	MetaProgress.accrue_idle()
	MetaProgress.idle.last_tick_unix-=5
	screen._process(1.1)
	var text:=screen.rate_label.text
	var ok:=text.contains("00:01:05") and screen.cap_bar.value>0
	MetaProgress.claim_idle()
	screen._update_idle_labels()
	ok=ok and screen.rate_label.text.contains("00:00:00")
	print("IDLE UI before: ",text," after: ",screen.rate_label.text," passed=",ok)
	get_tree().quit(0 if ok else 1)
