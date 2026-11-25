extends Node
var checks:Array=[]
var failed:=0
func check(ok:bool,label:String) -> void:
	checks.append({"name":label,"passed":ok})
	if not ok:failed+=1;print("FAIL ",label)
func _ready() -> void:
	if not OS.get_user_data_dir().contains("CodexIronTideValidation") or OS.get_environment("IRON_TIDE_REPORT_DIR").is_empty():get_tree().quit(2);return
	var m=MetaProgress
	for slots in [0,1]:
		for points in [0,2]:
			m.reset_save();m.talent_slots={"E1":slots};m.owned_talent_points=points;m.currency={"cores":1000,"credits":123,"diamonds":456}
			var cost:int=(40 if slots==0 else 0)+(40 if points==0 else 0)
			var offer:Dictionary=m.talent_unlock_quote("E1","native_deploy_def")
			check(offer.cost==cost,"quote reuses paid capacity and existing points "+str([slots,points]))
			if cost>0:
				m.currency.cores=cost-1
				check(not m.unlock_unit_talent("E1","native_deploy_def",cost) and m.talent_capacity("E1")==slots and m.owned_talent_points==points,"insufficient total changes nothing")
			m.currency.cores=cost;m.save()
			var old_bytes:=FileAccess.get_file_as_bytes(m.SAVE_PATH)
			DirAccess.make_dir_absolute(m.SAVE_PATH+".tmp")
			check(not m.unlock_unit_talent("E1","native_deploy_def",cost),"failed atomic save rejects unlock")
			check(m.balance("cores")==cost and m.owned_talent_points==points and m.talent_capacity("E1")==slots and not m.unit_talents.has("E1") and FileAccess.get_file_as_bytes(m.SAVE_PATH)==old_bytes,"failed write rolls back every component")
			DirAccess.remove_absolute(m.SAVE_PATH+".tmp")
			check(m.unlock_unit_talent("E1","native_deploy_def",cost),"single direct unlock succeeds")
			check(m.balance("cores")==0 and m.talent_capacity("E1")==1 and m.unit_talents.E1.native_deploy_def==0 and m.unassigned_talent_points()==maxi(0,points-1),"exact debit rank zero and no unused purchased point")
			m.load_save();m.load_save()
			check(m.balance("cores")==0 and m.talent_capacity("E1")==1 and m.unassigned_talent_points()==maxi(0,points-1),"atomic result persists without repeated charge")
			check(m.balance("credits")==123 and m.balance("diamonds")==456,"other currencies preserved")
			check(m.talent_unlock_quote("E1","native_deploy_def").is_empty() and not m.unlock_unit_talent("E1","native_deploy_def",0),"already unlocked never charges again")
	m.reset_save();m.currency.cores=120;m.unit_talents={"CLEG":{"chrono_bookmark":2}};m.talent_slots={"CLEG":1};m.owned_talent_points=1
	check(m.talent_unlock_quote("CLEG","native_chrono_time").cost==120,"second slot includes original eighty plus forty point price")
	check(m.unlock_unit_talent("CLEG","native_chrono_time",120) and m.unit_talents.CLEG.chrono_bookmark==2 and m.talent_capacity("CLEG")==2 and m.unassigned_talent_points()==0,"second unlock preserves existing rank")
	m.reset_save();m.currency.cores=100;m.talent_slots={"E1":1}
	var quote:Dictionary=m.talent_unlock_quote("E1","native_deploy_def")
	m.owned_talent_points=1
	check(not m.unlock_unit_talent("E1","native_deploy_def",int(quote.cost)) and m.balance("cores")==100,"stale price cannot overcharge after point balance changes")
	check(m.unlock_unit_talent("E1","native_deploy_def",0) and m.balance("cores")==100,"requote consumes existing point free")
	check(m.talent_unlock_quote("missing","native_deploy_def").is_empty() and m.talent_unlock_quote("E1","missing").is_empty(),"invalid unit or talent cannot quote")
	FileAccess.open(OS.get_environment("IRON_TIDE_REPORT_DIR").path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failed":failed}))
	print("UNLOCK checks=",checks.size()," failed=",failed)
	get_tree().quit(failed)
