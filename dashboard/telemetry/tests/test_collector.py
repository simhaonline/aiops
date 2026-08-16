import importlib.util, pathlib, unittest
path=pathlib.Path(__file__).parents[1]/"collector.py";spec=importlib.util.spec_from_file_location("collector",path);collector=importlib.util.module_from_spec(spec);spec.loader.exec_module(collector)
class CollectorTest(unittest.TestCase):
    def test_memory(self): self.assertEqual(collector.memory_percent("MemTotal: 1000 kB\nMemAvailable: 250 kB\n"),75)
    def test_uptime(self): self.assertEqual(collector.uptime_text(90000),"1d 1h")
    def test_prometheus(self): self.assertIn("aiops_memory_used_percent 42",collector.prometheus({"load":.2,"memory":42}))
if __name__=="__main__": unittest.main()
