"""Windows graphics validation on a private, never activated desktop.

No SwitchDesktop, input injection, minimization or off-screen window workaround.
CreateProcess binds the child to this desktop; EnumDesktopWindows verifies its
window belongs there. Only our child is terminated on timeout/error. The caller
must set --log-file, isolated APPDATA/LOCALAPPDATA and IRON_OUT before launching.
References: https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-createdesktopw
https://learn.microsoft.com/windows/win32/api/processthreadsapi/ns-processthreadsapi-startupinfow
"""
import ctypes as C
from ctypes import wintypes as W
import os, subprocess, time, uuid, sys, json
from pathlib import Path
from host_cpu_monitor import Monitor,summarize

class Startup(C.Structure):
    _fields_=[('cb',W.DWORD),('lpReserved',W.LPWSTR),('lpDesktop',W.LPWSTR),('lpTitle',W.LPWSTR),('dwX',W.DWORD),('dwY',W.DWORD),('dwXSize',W.DWORD),('dwYSize',W.DWORD),('dwXCountChars',W.DWORD),('dwYCountChars',W.DWORD),('dwFillAttribute',W.DWORD),('dwFlags',W.DWORD),('wShowWindow',W.WORD),('cbReserved2',W.WORD),('lpReserved2',C.POINTER(C.c_byte)),('hStdInput',W.HANDLE),('hStdOutput',W.HANDLE),('hStdError',W.HANDLE)]
class Process(C.Structure):
    _fields_=[('process',W.HANDLE),('thread',W.HANDLE),('pid',W.DWORD),('tid',W.DWORD)]

def run(command,cwd,env,timeout=150):
    user=C.WinDLL('user32',use_last_error=True);kernel=C.WinDLL('kernel32',use_last_error=True)
    user.CreateDesktopW.argtypes=[W.LPCWSTR,W.LPCWSTR,C.c_void_p,W.DWORD,W.DWORD,C.c_void_p];user.CreateDesktopW.restype=W.HANDLE
    user.OpenInputDesktop.argtypes=[W.DWORD,W.BOOL,W.DWORD];user.OpenInputDesktop.restype=W.HANDLE
    user.GetUserObjectInformationW.argtypes=[W.HANDLE,C.c_int,C.c_void_p,W.DWORD,C.POINTER(W.DWORD)]
    user.GetThreadDesktop.argtypes=[W.DWORD];user.GetThreadDesktop.restype=W.HANDLE
    user.CloseDesktop.argtypes=[W.HANDLE]
    kernel.CreateProcessW.argtypes=[W.LPCWSTR,W.LPWSTR,C.c_void_p,C.c_void_p,W.BOOL,W.DWORD,C.c_void_p,W.LPCWSTR,C.POINTER(Startup),C.POINTER(Process)];kernel.CreateProcessW.restype=W.BOOL
    kernel.WaitForSingleObject.argtypes=[W.HANDLE,W.DWORD];kernel.WaitForSingleObject.restype=W.DWORD
    kernel.GetExitCodeProcess.argtypes=[W.HANDLE,C.POINTER(W.DWORD)]
    kernel.TerminateProcess.argtypes=[W.HANDLE,W.UINT];kernel.CloseHandle.argtypes=[W.HANDLE]
    def name(handle):
        buf=C.create_unicode_buffer(256);length=W.DWORD()
        if not user.GetUserObjectInformationW(handle,2,buf,C.sizeof(buf),C.byref(length)):raise C.WinError(C.get_last_error())
        return buf.value
    def input_name():
        h=user.OpenInputDesktop(0,False,1)
        if not h:raise C.WinError(C.get_last_error())
        try:return name(h)
        finally:user.CloseDesktop(h)
    before=input_name();desktop_name='IronTideValidation_'+uuid.uuid4().hex
    desktop=user.CreateDesktopW(desktop_name,None,None,0,0x01ff,None)
    if not desktop:raise C.WinError(C.get_last_error())
    pi=Process();si=Startup();si.cb=C.sizeof(si);si.lpDesktop=desktop_name
    block=C.create_unicode_buffer('\0'.join(k+'='+v for k,v in sorted(env.items(),key=lambda x:x[0].upper()))+'\0\0')
    cmd=C.create_unicode_buffer(subprocess.list2cmdline(command))
    started=time.monotonic();created=False;monitor=None
    try:
        if not kernel.CreateProcessW(command[0],cmd,None,None,False,0x08000400,block,str(cwd),C.byref(si),C.byref(pi)):raise C.WinError(C.get_last_error())
        created=True
        monitor=Monitor(pi.pid)
        callback_type=C.WINFUNCTYPE(W.BOOL,W.HWND,W.LPARAM)
        user.EnumDesktopWindows.argtypes=[W.HANDLE,callback_type,W.LPARAM]
        user.GetWindowThreadProcessId.argtypes=[W.HWND,C.POINTER(W.DWORD)]
        found=[]
        @callback_type
        def capture(hwnd,param):
            owner=W.DWORD();user.GetWindowThreadProcessId(hwnd,C.byref(owner))
            if owner.value==pi.pid:found.append(int(hwnd))
            return True
        deadline=time.monotonic()+25
        while not found and time.monotonic()<deadline and kernel.WaitForSingleObject(pi.process,100)==258:
            user.EnumDesktopWindows(desktop,capture,0)
        if not found:raise RuntimeError('No child window verified on private desktop')
        actual=name(desktop)
        while kernel.WaitForSingleObject(pi.process,1000)==258:
            monitor.sample()
            if time.monotonic()-started>timeout:raise TimeoutError('Isolated child exceeded deadline')
        code=W.DWORD();kernel.GetExitCodeProcess(pi.process,C.byref(code))
        return {'returncode':code.value,'pid':pi.pid,'desktop':actual,'input_before':before,'input_after':input_name(),'activated':False,'wall':time.monotonic()-started}
    finally:
        try:
            if monitor is not None:
                monitor.sample();monitor.close()
                output=Path(env['IRON_OUT']);report={'intervals':monitor.rows,'all_phases':summarize(monitor.rows)}
                rp=output/'result.json'
                start,end=None,None
                if rp.exists():
                    result=json.loads(rp.read_text('utf8'));start=result['measurement_unix_start_s'];end=result['measurement_unix_end_s']
                    report['measurement_only']=summarize([r for r in monitor.rows if r['start_unix_s']>=start and r['end_unix_s']<=end])
                report['engine_process_audit']=monitor.engine_audit.report(start,end)
                (output/'host-cpu.json').write_text(json.dumps(report,indent=2),'utf8')
        finally:
            if created:
                if kernel.WaitForSingleObject(pi.process,0)==258:
                    kernel.TerminateProcess(pi.process,2);kernel.WaitForSingleObject(pi.process,5000)
                kernel.CloseHandle(pi.thread);kernel.CloseHandle(pi.process)
            user.CloseDesktop(desktop)
