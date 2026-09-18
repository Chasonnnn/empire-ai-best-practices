from pathlib import Path
import os, subprocess, sys, tempfile, unittest
ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "assets/poll_jobs.sh"


class PollJobs(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        binary = self.root / "bin"
        binary.mkdir()
        fake_ssh = binary / "ssh"
        fake_ssh.write_text(
            "#!" + sys.executable + "\nimport os,sys\n"
            "open(os.environ['SSH_CALLS'],'a').write(' '.join(sys.argv[1:])+'\\n')\n"
            "sys.stdout.write(os.environ.get('SSH_OUT',''))\nsys.exit(int(os.environ.get('SSH_EXIT','0')))\n"
        )
        fake_ssh.chmod(0o700)
        self.env = {
            **os.environ,
            "PATH": str(binary) + os.pathsep + os.environ["PATH"],
            "POLL_HOST": "empire", "POLL_JOBS": "1,2", "POLL_LOG": str(self.root / "log"),
            "POLL_INTERVAL": "600", "POLL_ALLOW_MULTIPLE": "1", "SSH_CALLS": str(self.root / "calls"),
        }

    def tearDown(self):
        self.temp.cleanup()

    def run_poll(self, timeout=10):
        return subprocess.run(["bash", str(SCRIPT)], env=self.env, capture_output=True, text=True, timeout=timeout)

    def test_terminal_states_exit_after_one_bounded_query(self):
        self.env["SSH_OUT"] = "1|COMPLETED|01:00:00|0:0\n2|FAILED|00:10:00|1:0\n"
        result = self.run_poll()
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = (self.root / "calls").read_text().splitlines()
        self.assertEqual(len(calls), 1)
        self.assertIn("BatchMode=yes", calls[0])
        self.assertIn("sacct -j 1,2", calls[0])
        log = (self.root / "log").read_text()
        self.assertIn("COMPLETED", log)
        self.assertIn("all terminal", log)

    def test_rejects_short_interval_and_bad_job_ids_before_any_query(self):
        self.env["POLL_INTERVAL"] = "60"
        self.assertNotEqual(self.run_poll().returncode, 0)
        self.env["POLL_INTERVAL"] = "600"
        self.env["POLL_JOBS"] = "1;rm"
        self.assertNotEqual(self.run_poll().returncode, 0)
        self.assertFalse((self.root / "calls").exists())

    def test_failed_query_is_logged_not_retried(self):
        self.env["SSH_EXIT"] = "255"
        self.env["POLL_INTERVAL"] = "600"
        with self.assertRaises(subprocess.TimeoutExpired):
            self.run_poll(timeout=3)
        calls = (self.root / "calls").read_text().splitlines()
        self.assertEqual(len(calls), 1)
        self.assertIn("query failed rc=255", (self.root / "log").read_text())


if __name__ == "__main__":
    unittest.main()
