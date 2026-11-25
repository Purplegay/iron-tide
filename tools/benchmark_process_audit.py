"""Read-only sampling of other Godot and IronTide processes during a benchmark.

Toolhelp process snapshots and QUERY_LIMITED_INFORMATION only. No command lines,
environment, memory, priority changes, or process control. A sampled process may
be idle; its presence makes the environment require review, not a CPU estimate.
"""
import ctypes as C
from ctypes import wintypes as W
import time


class Entry(C.Structure):
    _fields_ = [('size', W.DWORD), ('usage', W.DWORD), ('pid', W.DWORD),
                ('heap', C.c_size_t), ('module', W.DWORD), ('threads', W.DWORD),
                ('parent', W.DWORD), ('priority', W.LONG), ('flags', W.DWORD),
                ('name', W.WCHAR * 260)]


def engine_image(name):
    """Include exported game names, which do not contain the engine brand."""
    folded = name.lower()
    return 'godot' in folded or folded.startswith(('irontide', 'iron_tide'))


class EngineAudit:
    def __init__(self, owned_pid):
        self.owned_pid = owned_pid
        self.rows = []
        self.last_sample = -float('inf')
        self.api = C.WinDLL('kernel32', use_last_error=True)
        self.api.CreateToolhelp32Snapshot.argtypes = [W.DWORD, W.DWORD]
        self.api.CreateToolhelp32Snapshot.restype = W.HANDLE
        for name in ['Process32FirstW', 'Process32NextW']:
            fn = getattr(self.api, name)
            fn.argtypes = [W.HANDLE, C.POINTER(Entry)]
            fn.restype = W.BOOL
        self.api.OpenProcess.argtypes = [W.DWORD, W.BOOL, W.DWORD]
        self.api.OpenProcess.restype = W.HANDLE
        self.api.QueryFullProcessImageNameW.argtypes = [W.HANDLE, W.DWORD, W.LPWSTR, C.POINTER(W.DWORD)]
        self.api.QueryFullProcessImageNameW.restype = W.BOOL
        self.api.CloseHandle.argtypes = [W.HANDLE]
        self.api.CloseHandle.restype = W.BOOL

    def scan(self):
        handle = self.api.CreateToolhelp32Snapshot(2, 0)
        if handle == C.c_void_p(-1).value:
            raise C.WinError(C.get_last_error())
        found = []
        try:
            entry = Entry()
            entry.size = C.sizeof(entry)
            more = self.api.Process32FirstW(handle, C.byref(entry))
            while more:
                if engine_image(entry.name) and entry.pid != self.owned_pid:
                    row = {'pid': entry.pid, 'parent_pid': entry.parent, 'name': entry.name}
                    process = self.api.OpenProcess(0x1000, False, entry.pid)
                    if process:
                        try:
                            path = C.create_unicode_buffer(32768)
                            length = W.DWORD(len(path))
                            if self.api.QueryFullProcessImageNameW(process, 0, path, C.byref(length)):
                                row['image'] = path.value
                            else:
                                row['image_error'] = C.get_last_error()
                        finally:
                            self.api.CloseHandle(process)
                    else:
                        row['image_error'] = C.get_last_error()
                    found.append(row)
                more = self.api.Process32NextW(handle, C.byref(entry))
            error = C.get_last_error()
            if error != 18:  # ERROR_NO_MORE_FILES is the documented terminal condition.
                raise C.WinError(error)
            return found
        finally:
            self.api.CloseHandle(handle)

    def sample(self):
        started = time.perf_counter()
        if started - self.last_sample < 5.0:
            return
        self.last_sample = started
        row = {'unix_s': time.time()}
        try:
            row['external_engines'] = self.scan()
        except OSError as error:
            row['error'] = str(error)
        row['scan_ms'] = (time.perf_counter() - started) * 1000
        self.rows.append(row)

    def report(self, start=None, end=None):
        measured = [r for r in self.rows if start is not None and end is not None and start <= r['unix_s'] <= end]
        return {'owned_pid': self.owned_pid, 'samples': self.rows,
                'measurement_samples': len(measured),
                'measurement_requires_review': not measured or any(r.get('error') or r.get('external_engines') for r in measured),
                'scope': 'Five-second process presence samples; short-lived or unrecognized export names may be missed. Scan overhead is recorded. No CPU or GPU attribution.'}
