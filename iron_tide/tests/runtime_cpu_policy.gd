extends Node
func _ready() -> void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 if RuntimeCPU.report.status=="pending":await RuntimeCPU.completed
 var expected:=OS.get_environment("IRON_EXPECT_CPU_POLICY")
 var report:Dictionary=RuntimeCPU.report
 var checks:Array=[{"passed":report.status==expected,"name":"startup status "+expected},
  {"passed":not RuntimeCPU.is_processing(),"name":"startup polling ends"},
  {"passed":RuntimeCPU.helper_pid==-1,"name":"helper handle cleared"},
  {"passed":RuntimeCPU.result_path.is_empty() or not FileAccess.file_exists(RuntimeCPU.result_path),"name":"completed temporary result removed"}]
 if report.status=="applied" or report.status=="existing_affinity_preserved":
  checks.append({"passed":int(report.pid)==OS.get_process_id(),"name":"only own process selected"})
  checks.append({"passed":int(report.after_mask)>0 and (int(report.after_mask)&int(report.before_mask))==int(report.after_mask),"name":"mask stays within caller allowance"})
 var failed:=checks.filter(func(row):return not row.passed).size()
 var output:=OS.get_environment("IRON_TIDE_REPORT_DIR")
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"failed":failed,"checks":checks,"cpu_policy":report},"  "))
 get_tree().quit(0 if failed==0 else 1)
