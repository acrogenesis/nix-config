import importlib.util
import os
from pathlib import Path
import shutil
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "mover", Path(__file__).with_name("mergerfs-uncache.py")
)
mover = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mover)


class MoverExclusionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.cache = self.root / "cache pool"
        self.slow = self.root / "slow pool"
        self.relative = Path("Backups/TimeMachine/archy")
        self.commands = []
        self.run = subprocess.run
        for pool in (self.cache, self.slow):
            protected = pool / self.relative
            protected.mkdir(parents=True)
            (protected / "state").write_text("keep me")
            (protected / "state").chmod(0o400)
            protected.chmod(0o700)
            sibling = protected.with_name("archy-old")
            sibling.mkdir()
            (sibling / "file").write_text("normal pool policy")
            (sibling / "file").chmod(0o600)
        outside = self.root / "outside"
        outside.mkdir()
        (outside / "state").write_text("outside the pools")
        (outside / "state").chmod(0o400)
        (self.cache / "Backups/TimeMachine/link").symlink_to(outside, target_is_directory=True)

    def run_permissions_command(self, args):
        self.commands.append(args)
        if args[1].endswith("/chmod"):
            self.run([shutil.which("chmod"), *args[2:]], check=True)
        return subprocess.CompletedProcess(args, 0)

    def fix(self, exclusions):
        with patch.object(mover.subprocess, "run", self.run_permissions_command):
            mover.fix_permissions("1234", "5678", self.cache, self.slow, exclusions)

    def test_both_permission_passes_preserve_excluded_ownership_and_modes(self):
        # Ownership calls are recorded; chmod really runs on the disposable tree.
        for _ in range(2):
            self.fix([self.cache / self.relative])
        for pool in (self.cache, self.slow):
            protected = pool / self.relative
            self.assertEqual(stat.S_IMODE(protected.stat().st_mode), 0o700)
            self.assertEqual(stat.S_IMODE((protected / "state").stat().st_mode), 0o400)
            self.assertEqual(
                stat.S_IMODE((protected.with_name("archy-old") / "file").stat().st_mode),
                0o664,
            )
            for command in self.commands:
                target = Path(command[-1])
                self.assertFalse(target.is_relative_to(protected))
                if "-R" in command:
                    self.assertFalse(protected.is_relative_to(target))

    def test_exclusion_matches_components_not_neighboring_names(self):
        exclusions = mover.normalize_exclusions(self.cache, [str(self.relative)])
        self.assertTrue(mover.is_excluded(self.cache / self.relative / "file", exclusions))
        self.assertFalse(mover.is_excluded(self.cache / "Backups/TimeMachine/archy-old/file", exclusions))

    def test_candidate_scan_prunes_excluded_private_directory(self):
        protected = self.cache / self.relative
        protected.chmod(0)
        self.addCleanup(protected.chmod, 0o700)
        exclusions = mover.normalize_exclusions(self.cache, [str(self.relative)])
        candidates = dict(mover.iter_candidates(self.cache, exclusions))
        self.assertNotIn(protected / "state", candidates)
        self.assertIn(protected.with_name("archy-old") / "file", candidates)

    def test_permission_partition_does_not_follow_symlink_arguments(self):
        self.fix([self.cache / self.relative])
        self.assertEqual(stat.S_IMODE((self.root / "outside/state").stat().st_mode), 0o400)
        link = self.cache / "Backups/TimeMachine/link"
        link_commands = [args for args in self.commands if args[-1] == str(link)]
        self.assertEqual(len(link_commands), 1)
        self.assertTrue(link_commands[0][1].endswith("/chown"))
        self.assertIn("-h", link_commands[0])

    def test_no_exclusions_keeps_original_recursive_pool_policy(self):
        self.fix([])
        self.assertEqual(len(self.commands), 4)
        self.assertTrue(all("-R" in args for args in self.commands))
        self.assertEqual(stat.S_IMODE((self.cache / self.relative / "state").stat().st_mode), 0o664)

    def test_absolute_and_relative_paths_normalize_identically(self):
        self.assertEqual(
            mover.normalize_exclusions(self.cache, [str(self.relative)]),
            mover.normalize_exclusions(self.cache, [str(self.cache / self.relative)]),
        )

    def test_exclusions_cannot_escape_source_pool(self):
        with self.assertRaises(ValueError):
            mover.normalize_exclusions(self.cache, ["../outside"])


if __name__ == "__main__":
    unittest.main()
