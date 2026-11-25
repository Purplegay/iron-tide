import unittest
from benchmark_process_audit import engine_image

class ExportedEngineNames(unittest.TestCase):
    def test_actual_export_missed_during_slot3_run(self):
        self.assertTrue(engine_image("IronTideRuntime.exe"))

    def test_editor_and_versioned_exports(self):
        for name in ["GodotRelease.exe", "Godot_v4.7.2-stable_win64.exe", "IronTide.exe", "iron_tide-0.30.exe"]:
            with self.subTest(name=name): self.assertTrue(engine_image(name))

    def test_unrelated_host_processes(self):
        for name in ["python.exe", "powershell.exe", "Code.exe", "explorer.exe"]:
            with self.subTest(name=name): self.assertFalse(engine_image(name))

if __name__ == "__main__": unittest.main()
