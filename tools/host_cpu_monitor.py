"""Read-only Windows CPU telemetry for an owned benchmark subprocess.

GetSystemTimes includes idle in kernel time. GetProcessTimes sums all threads.
https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getsystemtimes
https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getprocesstimes
Other Godot process presence is sampled separately with read-only Toolhelp APIs.
No WMI, priority changes, or external-process control.
"""
import ctypes
from ctypes import wintypes
import json
import os
import subprocess
import time
from benchmark_process_audit import EngineAudit


def ticks(value):
    return (value.dwHighDateTime << 32) | value.dwLowDateTime


def interval(before, after):
    total = after['total'] - before['total']
    elapsed = after['mono'] - before['mono']
    if total <= 0 or elapsed <= 0:
        raise RuntimeError('Non-increasing host CPU counters')
    idle = after['idle'] - before['idle']
    own = after['process'] - before['process']
    busy = 100.0 * (total - idle) / total
    own_percent = 100.0 * own / total
    return {'start_unix_s': before['unix'], 'end_unix_s': after['unix'],
            'seconds': elapsed, 'system_busy_percent': busy,
            'benchmark_percent_of_host': own_percent,
            'other_busy_percent_estimate': max(0.0, busy - own_percent),
            'benchmark_cpu_seconds': own / 10_000_000,
            'benchmark_cpu_cores': own / 10_000_000 / elapsed}


def summarize(rows):
    seconds = sum(row['seconds'] for row in rows)
    result = {'samples': len(rows), 'sampled_seconds': seconds}
    if seconds:
        for key in ['system_busy_percent', 'benchmark_percent_of_host', 'other_busy_percent_estimate']:
            result[key + '_weighted_mean'] = sum(row[key] * row['seconds'] for row in rows) / seconds
        result['system_busy_percent_max'] = max(row['system_busy_percent'] for row in rows)
        result['seconds_at_least_90_percent_busy'] = sum(row['seconds'] for row in rows if row['system_busy_percent'] >= 90)
    return result


class Monitor:
    def __init__(self, pid):
        if os.name != 'nt' or (os.cpu_count() or 0) > 64:
            raise RuntimeError('Host CPU monitor requires Windows with at most 64 logical processors')
        self.api = ctypes.WinDLL('kernel32', use_last_error=True)
        pointer = ctypes.POINTER(wintypes.FILETIME)
        self.api.GetSystemTimes.argtypes = [pointer, pointer, pointer]
        self.api.GetSystemTimes.restype = wintypes.BOOL
        self.api.GetProcessTimes.argtypes = [wintypes.HANDLE, pointer, pointer, pointer, pointer]
        self.api.GetProcessTimes.restype = wintypes.BOOL
        self.api.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        self.api.OpenProcess.restype = wintypes.HANDLE
        self.api.CloseHandle.argtypes = [wintypes.HANDLE]
        self.api.CloseHandle.restype = wintypes.BOOL
        self.handle = self.api.OpenProcess(0x1000, False, pid)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        self.rows = []
        self.deferred_samples = []
        self.previous = None
        self.engine_audit = EngineAudit(pid)
        try:
            self.sample()
        except BaseException:
            self.close()
            raise

    def sample(self):
        idle, kernel, user = (wintypes.FILETIME() for _ in range(3))
        if not self.api.GetSystemTimes(ctypes.byref(idle), ctypes.byref(kernel), ctypes.byref(user)):
            raise ctypes.WinError(ctypes.get_last_error())
        created, exited, own_kernel, own_user = (wintypes.FILETIME() for _ in range(4))
        if not self.api.GetProcessTimes(self.handle, ctypes.byref(created), ctypes.byref(exited), ctypes.byref(own_kernel), ctypes.byref(own_user)):
            raise ctypes.WinError(ctypes.get_last_error())
        current = {'idle': ticks(idle), 'total': ticks(kernel) + ticks(user),
                   'process': ticks(own_kernel) + ticks(own_user),
                   'mono': time.monotonic(), 'unix': time.time()}
        self.record(current)
        self.engine_audit.sample()

    def record(self, current):
        if self.previous is not None:
            # The exit sample can share a clock/counter tick with the last poll.
            # Keep the earlier baseline so the next advancing sample includes
            # all elapsed work. Never manufacture a zero-duration CPU ratio.
            elapsed = current['mono'] - self.previous['mono']
            total = current['total'] - self.previous['total']
            if elapsed >= 0 and total >= 0 and (elapsed == 0 or total == 0):
                self.deferred_samples.append({'reason': 'clock_or_cpu_tick_not_advanced',
                                              'before': self.previous, 'after': current})
                return
            self.rows.append(interval(self.previous, current))
        self.previous = current

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None


def run(command, output, timeout, **kwargs):
    with subprocess.Popen(command, **kwargs) as process:
        monitor = None
        try:
            monitor = Monitor(process.pid)
            deadline = time.monotonic() + timeout
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise subprocess.TimeoutExpired(command, timeout)
                try:
                    process.wait(timeout=min(1.0, remaining))
                    monitor.sample()
                    break
                except subprocess.TimeoutExpired:
                    monitor.sample()
        except BaseException:
            if process.poll() is None:
                process.kill()  # Only the child created immediately above.
                process.wait()
            raise
        finally:
            if monitor is not None:
                monitor.close()
                report = {'pid': process.pid, 'logical_processors': os.cpu_count(),
                          'source': 'GetSystemTimes and GetProcessTimes, one-second polling',
                          'scope': 'Host aggregate includes benchmark; other estimate subtracts its CPU time. No per-core saturation, clock or GPU claim.',
                          'all_phases': summarize(monitor.rows), 'intervals': monitor.rows}
                report['deferred_samples'] = monitor.deferred_samples
                result_path = output / 'result.json'
                start, end = None, None
                if result_path.exists():
                    result = json.loads(result_path.read_text('utf8'))
                    start, end = result.get('measurement_unix_start_s'), result.get('measurement_unix_end_s')
                    if start is not None and end is not None:
                        measured = [row for row in monitor.rows if row['start_unix_s'] >= start and row['end_unix_s'] <= end]
                        report['measurement_only'] = summarize(measured)
                        report['measurement_scope'] = 'Whole polling intervals inside the measured window; boundary intervals omitted.'
                report['engine_process_audit'] = monitor.engine_audit.report(start, end)
                (output / 'host-cpu.json').write_text(json.dumps(report, indent=2), 'utf8')
        return subprocess.CompletedProcess(command, process.returncode)
