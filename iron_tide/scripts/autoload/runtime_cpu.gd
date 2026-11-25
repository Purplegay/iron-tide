extends Node
## Own-process Windows hybrid-CPU policy. Never modifies power plans or other games.
signal completed
var report: Dictionary = {"status":"pending"}
var helper_pid := -1
var started := 0
var result_path := ""

const HELPER := """
$ErrorActionPreference = 'Stop'
$targetPid = __PID__
$destination = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__OUTPUT__'))
$expectedImage = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('__IMAGE__'))
$deadline = [long]__DEADLINE__
try {
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class IronCpuPlacement {
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetSystemCpuSetInformation(IntPtr buffer, uint size, out uint required, IntPtr process, uint flags);
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool GetProcessAffinityMask(IntPtr process, out UIntPtr mask, out UIntPtr system);
 [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetProcessAffinityMask(IntPtr process, UIntPtr mask);
 public static ulong[] Apply(IntPtr process, long deadline) {
  UIntPtr original, system;
  if (!GetProcessAffinityMask(process, out original, out system)) throw new System.ComponentModel.Win32Exception();
  ulong before=original.ToUInt64(), available=system.ToUInt64();
  if (before!=available) return new ulong[]{before,available,before,1};
  uint size;
  GetSystemCpuSetInformation(IntPtr.Zero,0,out size,process,0);
  if (size==0) throw new System.ComponentModel.Win32Exception();
  IntPtr buffer=Marshal.AllocHGlobal((int)size);
  try {
   if (!GetSystemCpuSetInformation(buffer,size,out size,process,0)) throw new System.ComponentModel.Win32Exception();
   int highest=-1,lowest=256,count=0;
   ulong chosen=0;
   for (int offset=0; offset<(int)size;) {
    IntPtr row=IntPtr.Add(buffer,offset);
    int length=Marshal.ReadInt32(row,0), kind=Marshal.ReadInt32(row,4);
    if (length<8 || offset+length>(int)size) throw new InvalidOperationException("Invalid CPU topology");
    if (kind==0 && length>=24) {
     if (Marshal.ReadInt16(row,12)!=0) return new ulong[]{before,available,before,2};
     int logical=Marshal.ReadByte(row,14), efficiency=Marshal.ReadByte(row,18), flags=Marshal.ReadByte(row,19);
     if (logical<64 && (before & (1UL<<logical))!=0 && ((flags & 2)==0 || (flags & 4)!=0)) {
      lowest=Math.Min(lowest,efficiency);
      if (efficiency>highest) {highest=efficiency;chosen=0;count=0;}
      if (efficiency==highest) {chosen |= 1UL<<logical;count++;}
     }
    }
    offset+=length;
   }
   if (highest==lowest || highest<0 || count<2 || chosen==0 || chosen==before) return new ulong[]{before,available,before,3};
   if (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()>=deadline) throw new TimeoutException("CPU placement deadline elapsed");
   if (!SetProcessAffinityMask(process,new UIntPtr(chosen))) throw new System.ComponentModel.Win32Exception();
   UIntPtr actual, actualSystem;
   if (!GetProcessAffinityMask(process,out actual,out actualSystem) || actual.ToUInt64()!=chosen) {
    SetProcessAffinityMask(process,original);
    throw new InvalidOperationException("CPU affinity verification failed");
   }
   return new ulong[]{before,available,chosen,0};
  } finally {Marshal.FreeHGlobal(buffer);}
 }
}
'@
 $target = Get-Process -Id $targetPid
 if ([IO.Path]::GetFullPath($target.Path) -ne [IO.Path]::GetFullPath($expectedImage) -or $target.StartTime.ToUniversalTime() -gt [DateTimeOffset]::FromUnixTimeMilliseconds($deadline-10000).UtcDateTime) {throw 'Target process identity changed'}
 $values = [IronCpuPlacement]::Apply($target.Handle,$deadline)
 $states = @('applied','existing_affinity_preserved','multiple_processor_groups','homogeneous_or_insufficient_cores')
 $result = @{status=$states[[int]$values[3]];pid=$targetPid;before_mask=$values[0];system_mask=$values[1];after_mask=$values[2];finished_unix_ms=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()}
} catch {$result = @{status='unavailable';pid=$targetPid;reason=$_.Exception.Message}}
[IO.File]::WriteAllText($destination,($result | ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
"""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var policy := OS.get_environment("IRON_TIDE_CPU_POLICY")
	if OS.get_name() != "Windows" or policy == "all" or (OS.has_feature("editor") and policy.is_empty()):
		_finish({"status":"unchanged","policy":policy,"platform":OS.get_name()})
		return
	if not policy.is_empty() and policy != "auto":
		_finish({"status":"unknown_policy","policy":policy})
		return
	var executable := OS.get_environment("SystemRoot").path_join("System32/WindowsPowerShell/v1.0/powershell.exe")
	if not FileAccess.file_exists(executable):
		_finish({"status":"helper_unavailable"})
		return
	if DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir()) != OK:
		_finish({"status":"profile_unavailable"})
		return
	result_path = OS.get_user_data_dir().path_join("cpu-placement-%s-%s.json" % [OS.get_process_id(),Time.get_ticks_usec()])
	var command := HELPER.replace("__PID__",str(OS.get_process_id())).replace("__OUTPUT__",Marshalls.utf8_to_base64(result_path)).replace("__IMAGE__",Marshalls.utf8_to_base64(OS.get_executable_path())).replace("__DEADLINE__",str(int(Time.get_unix_time_from_system()*1000)+10000))
	started = Time.get_ticks_msec()
	helper_pid = OS.create_process(executable,["-NoProfile","-NonInteractive","-WindowStyle","Hidden","-EncodedCommand",Marshalls.raw_to_base64(command.to_utf16_buffer())],false)
	if helper_pid < 0: _finish({"status":"helper_start_failed"})

func _process(_delta: float) -> void:
	if helper_pid < 0: return
	if not OS.is_process_running(helper_pid):
		var value = JSON.parse_string(FileAccess.get_file_as_string(result_path)) if FileAccess.file_exists(result_path) else null
		_finish(value if value is Dictionary else {"status":"helper_failed"})
	elif Time.get_ticks_msec()-started > 12000:
		_finish({"status":"helper_timeout"})

func _exit_tree() -> void:
	if not result_path.is_empty() and FileAccess.file_exists(result_path): DirAccess.remove_absolute(result_path)

func _finish(value: Dictionary) -> void:
	report = value
	report.scope = "this game process only"
	report.elapsed_ms = Time.get_ticks_msec()-started if started > 0 else 0
	helper_pid = -1
	if not result_path.is_empty() and FileAccess.file_exists(result_path): DirAccess.remove_absolute(result_path)
	var file := FileAccess.open("user://runtime_cpu_policy.json",FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify(report))
	print("IronTide CPU placement: ",JSON.stringify(report))
	set_process(false)
	completed.emit()
