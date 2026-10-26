"""Check pinned-source preparation using local Git fixtures, without networking.

Only the fetch transport is substituted: checkout verification uses real Git
objects and real working-tree bytes, including failure/recovery sequences.
"""

import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts/prepare_xpact_core.py"
SPEC = importlib.util.spec_from_file_location("prepare_xpact_core", SCRIPT)
dependency = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = dependency
SPEC.loader.exec_module(dependency)
BUILD_SPEC = importlib.util.spec_from_file_location(
    "build_implementations", REPO / "scripts/build_implementations.py")
builds = importlib.util.module_from_spec(BUILD_SPEC)
sys.modules[BUILD_SPEC.name] = builds
BUILD_SPEC.loader.exec_module(builds)
GIT = shutil.which("git")


def remove_fixture(path):
    def writable_retry(function, name, error):
        os.chmod(name, stat.S_IREAD | stat.S_IWRITE)
        function(name)
    shutil.rmtree(path, onerror=writable_retry)


@unittest.skipUnless(GIT, "Local Git is required for pinned-checkout tests")
class PinnedDependencyTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/implementation-build-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.directory = Path(tempfile.mkdtemp(prefix="run-", dir=scratch))
        self.addCleanup(remove_fixture, self.directory)
        self.repository = self.directory / "local upstream with spaces"
        self.repository.mkdir()
        self.git("init", "--quiet", cwd=self.repository)
        self.library = "library/xpact-core.ecf"
        source = self.repository / self.library
        source.parent.mkdir()
        source.write_bytes(b"<system name='fixture'/>\n")
        (self.repository / ".gitignore").write_text("*.ignored\n", encoding="utf-8")
        self.git("add", ".", cwd=self.repository)
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "--quiet", "-m", "Pinned fixture", cwd=self.repository)
        self.revision = self.git("rev-parse", "HEAD", cwd=self.repository)
        self.project = self.directory / "consumer with spaces and 'quotes'"
        (self.project / "dependencies").mkdir(parents=True)
        self.lock_path = self.project / "dependencies/xpact-core.json"
        self.lock = {
            "schema_version": 1,
            "repository": "https://github.com/fixture/xpact-core.git",
            "revision": self.revision,
            "library": self.library,
            "required_paths": [self.library],
            "dependencies": ["Git; local fixture, no network"],
        }
        self.write_lock()
        self.cache_root = self.project / "build/dependencies/xpact-core"
        self.destination = self.cache_root / self.revision
        self.commands = []
        self.original_run_git = dependency.run_git

    @staticmethod
    def git(*arguments, cwd):
        result = subprocess.run([GIT, "-c", "core.longpaths=true", "-c", "core.autocrlf=false",
                                 "-c", "commit.gpgsign=false", *arguments], cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, encoding="utf-8", errors="replace")
        if result.returncode:
            raise AssertionError("Fixture Git failed: {}\n{}".format(arguments, result.stderr))
        return result.stdout.strip()

    def write_lock(self):
        self.lock_path.write_text(json.dumps(self.lock), encoding="utf-8")

    def local_transport(self, arguments, cwd):
        arguments = [str(value) for value in arguments]
        self.commands.append((arguments[:], Path(cwd)))
        if arguments[0] == "fetch":
            # Copy real Git objects as the local transport. Git's file transport
            # invokes sh on Windows, which is unavailable in some sandboxes.
            self.assertEqual(arguments[-2:], ["origin", self.revision])
            shutil.copytree(self.repository / ".git/objects", Path(cwd) / ".git/objects",
                            dirs_exist_ok=True)
            (Path(cwd) / ".git/FETCH_HEAD").write_text(self.revision + "\n", encoding="ascii")
            return ""
        return self.original_run_git(arguments, cwd)

    def prepare(self, offline=False):
        with mock.patch.object(dependency, "run_git", side_effect=self.local_transport), \
                contextlib.redirect_stdout(io.StringIO()):
            return dependency.prepare_dependency(self.project, offline=offline)

    def assert_no_owned_staging(self):
        self.assertEqual(list(self.cache_root.glob(".prepare-*")), [])

    def test_preparation_then_offline_reuse_verifies_original_identity_without_fetching(self):
        first = self.prepare()
        self.assertEqual(Path(first["source_dir"]), self.destination)
        self.assertEqual(first["revision"], self.revision)
        self.assertEqual(first["repository"], self.lock["repository"])
        self.assertRegex(first["source_sha256"], r"^[0-9a-f]{64}$")
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.destination), self.revision)
        self.commands.clear()
        second = self.prepare(offline=True)
        self.assertEqual(first["source_sha256"], second["source_sha256"])
        self.assertFalse(any(arguments[0] == "fetch" for arguments, _ in self.commands))
        self.assert_no_owned_staging()

    @unittest.skipUnless(os.name == "nt", "Windows Git path-length regression")
    def test_long_checkout_path_preserves_verification_and_dirty_recovery(self):
        relative_object = (Path("build/dependencies/xpact-core") / self.revision
                           / ".git/objects" / self.revision[:2] / self.revision[2:])
        base = self.directory / "jenkins workspace"
        padding = max(0, 270 - len(str(base / relative_object)))
        self.project = self.directory / ("jenkins workspace" + "x" * padding)
        (self.project / "dependencies").mkdir(parents=True)
        self.lock_path = self.project / "dependencies/xpact-core.json"
        self.write_lock()
        self.cache_root = self.project / "build/dependencies/xpact-core"
        self.destination = self.cache_root / self.revision
        loose_object = self.project / relative_object
        self.assertGreater(len(str(loose_object)), 260)

        def transport(arguments, cwd):
            result = self.local_transport(arguments, cwd)
            if arguments[0] == "init":
                # Force the Windows default locally, independent of the user's
                # configuration. Production Git must opt in per invocation.
                self.git("config", "core.longpaths", "false", cwd=cwd)
            return result

        with mock.patch.object(dependency, "run_git", side_effect=transport):
            first = dependency.prepare_dependency(self.project)
        self.assertTrue(loose_object.is_file())
        self.assertEqual(self.git("config", "--local", "--get", "core.longpaths", cwd=self.destination), "false")
        self.assertEqual(self.prepare(offline=True)["source_sha256"], first["source_sha256"])
        source = self.destination / self.library
        original = source.read_bytes()
        source.write_bytes(b"modified long-path source must remain\n")
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(source.read_bytes(), b"modified long-path source must remain\n")
        source.write_bytes(original)
        self.assertEqual(self.prepare(offline=True)["source_sha256"], first["source_sha256"])
        self.assert_no_owned_staging()

    def test_offline_missing_checkout_never_fetches_or_creates_source(self):
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertFalse(self.destination.exists())
        self.assertFalse(any(arguments[0] == "fetch" for arguments, _ in self.commands))

    def test_fetch_failure_cleans_only_own_stage_then_retry_publishes_verified_source(self):
        self.cache_root.mkdir(parents=True)
        other_work = self.cache_root / "foreign-run"
        other_work.mkdir()
        sentinel = other_work / "keep.txt"
        sentinel.write_bytes(b"another run owns this")

        def fail_fetch(arguments, cwd):
            if arguments[0] == "fetch":
                raise dependency.DependencyError("deliberate transport failure")
            return self.local_transport(arguments, cwd)

        with mock.patch.object(dependency, "run_git", side_effect=fail_fetch):
            with self.assertRaises(dependency.DependencyError):
                dependency.prepare_dependency(self.project)
        self.assertFalse(self.destination.exists())
        self.assert_no_owned_staging()
        self.assertEqual(sentinel.read_bytes(), b"another run owns this")
        self.assertEqual(self.prepare()["revision"], self.revision)
        self.assert_no_owned_staging()

    def test_dirty_checkout_is_rejected_without_repair_and_clean_reuse_recovers(self):
        clean = self.prepare()
        source = self.destination / self.library
        original = source.read_bytes()
        source.write_bytes(b"caller modification must remain\n")
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(source.read_bytes(), b"caller modification must remain\n")
        source.write_bytes(original)
        recovered = self.prepare(offline=True)
        self.assertEqual(recovered["source_sha256"], clean["source_sha256"])

    def test_assume_unchanged_cannot_hide_modified_working_tree_bytes(self):
        self.prepare()
        self.git("update-index", "--assume-unchanged", self.library, cwd=self.destination)
        source = self.destination / self.library
        source.write_bytes(b"modified despite index flag\n")
        self.assertEqual(self.git("status", "--porcelain", cwd=self.destination), "")
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(source.read_bytes(), b"modified despite index flag\n")

    def test_untracked_and_ignored_files_are_each_rejected_and_preserved(self):
        self.prepare()
        for name in ("extra.e", "extra.ignored"):
            with self.subTest(name=name):
                extra = self.destination / name
                extra.write_bytes(b"unapproved source")
                with self.assertRaises(dependency.DependencyError):
                    self.prepare(offline=True)
                self.assertEqual(extra.read_bytes(), b"unapproved source")
                extra.unlink()
        self.prepare(offline=True)

    def test_wrong_origin_is_rejected_without_overwriting_it(self):
        self.prepare()
        wrong_origin = "https://github.com/fixture/different.git"
        self.git("remote", "set-url", "origin", wrong_origin, cwd=self.destination)
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(self.git("remote", "get-url", "origin", cwd=self.destination), wrong_origin)

    def test_wrong_head_is_rejected_without_resetting_new_commit(self):
        self.prepare()
        source = self.destination / self.library
        source.write_bytes(b"<system name='different revision'/>\n")
        self.git("add", self.library, cwd=self.destination)
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "--quiet", "-m", "Caller commit", cwd=self.destination)
        caller_revision = self.git("rev-parse", "HEAD", cwd=self.destination)
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.destination), caller_revision)

    def test_git_replace_cannot_make_alternative_source_look_like_the_pinned_commit(self):
        self.prepare()
        source = self.destination / self.library
        source.write_bytes(b"<system name='replacement tree'/>\n")
        self.git("add", self.library, cwd=self.destination)
        self.git("-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
                 "commit", "--quiet", "-m", "Replacement fixture", cwd=self.destination)
        replacement = self.git("rev-parse", "HEAD", cwd=self.destination)
        self.git("update-ref", "refs/replace/" + self.revision, replacement, cwd=self.destination)
        self.git("update-ref", "HEAD", self.revision, cwd=self.destination)
        self.assertEqual(self.git("status", "--porcelain", cwd=self.destination), "")
        with self.assertRaises(dependency.DependencyError):
            self.prepare(offline=True)
        self.assertEqual(source.read_bytes(), b"<system name='replacement tree'/>\n")

    def test_inherited_git_path_overrides_cannot_redirect_checkout_verification(self):
        original = self.prepare()
        with mock.patch.dict(os.environ, {
            "GIT_DIR": str(self.repository / ".git"),
            "GIT_WORK_TREE": str(self.repository),
            "GIT_INDEX_FILE": str(self.directory / "wrong-index"),
        }):
            verified = self.prepare(offline=True)
        self.assertEqual(original, verified)
        self.assertFalse((self.directory / "wrong-index").exists())

    def test_malformed_lock_is_rejected_before_any_git_or_cache_mutation(self):
        for key, value in (("revision", "main"), ("library", "../outside.ecf"),
                           ("repository", "file:///caller/repository"),
                           ("required_paths", self.library), ("required_paths", None)):
            with self.subTest(field=key):
                original = self.lock[key]
                self.lock[key] = value
                self.write_lock()
                with mock.patch.object(dependency, "run_git") as git:
                    with self.assertRaises(dependency.DependencyError):
                        dependency.prepare_dependency(self.project)
                git.assert_not_called()
                self.assertFalse(self.cache_root.exists())
                self.lock[key] = original
        self.write_lock()

    def test_publication_failure_releases_own_staging_and_allows_retry(self):
        with mock.patch.object(Path, "rename", side_effect=OSError("deliberate publish failure")):
            with self.assertRaises((dependency.DependencyError, OSError)):
                self.prepare()
        self.assertFalse(self.destination.exists())
        self.assert_no_owned_staging()
        self.assertEqual(self.prepare()["revision"], self.revision)

    def test_concurrent_valid_winner_is_verified_and_loser_stage_is_released(self):
        def another_run_publishes(path, target):
            shutil.copytree(path, target)
            raise FileExistsError("another run published first")

        with mock.patch.object(Path, "rename", another_run_publishes):
            result = self.prepare()
        self.assertEqual(Path(result["source_dir"]), self.destination)
        self.assertEqual(self.git("rev-parse", "HEAD", cwd=self.destination), self.revision)
        self.assert_no_owned_staging()
        self.prepare(offline=True)

    def test_concurrent_invalid_winner_is_rejected_and_remains_owned_by_winner(self):
        def another_run_publishes(path, target):
            target.mkdir()
            (target / "keep.txt").write_bytes(b"winner owns this incomplete source")
            raise FileExistsError("another run published first")

        with mock.patch.object(Path, "rename", another_run_publishes):
            with self.assertRaises(dependency.DependencyError):
                self.prepare()
        self.assertEqual((self.destination / "keep.txt").read_bytes(),
                         b"winner owns this incomplete source")
        self.assert_no_owned_staging()


class IsolatedBuildTests(unittest.TestCase):
    def setUp(self):
        scratch = REPO / "build/implementation-build-tests"
        scratch.mkdir(parents=True, exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(prefix="build-", dir=scratch)
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.root = self.directory / "repository with spaces"
        for relative in ("scripts", "dependencies", "src",
                         "tools/implementation_probe/xpact", "tools/implementation_probe/xpact_core",
                         "benchmarks/dual_catalog/shared", "benchmarks/dual_catalog/xpact",
                         "benchmarks/dual_catalog/xpact_core", "benchmarks/dual_w3c/shared",
                         "benchmarks/dual_w3c/xpact", "benchmarks/dual_w3c/xpact_core"):
            (self.root / relative).mkdir(parents=True, exist_ok=True)
        for relative in ("scripts/build_implementations.py", "scripts/prepare_xpact_core.py",
                         "dependencies/xpact-core.json", "src/parser.e",
                         "tools/implementation_probe/xpact/probe.e",
                         "tools/implementation_probe/xpact/probe.ecf",
                         "tools/implementation_probe/xpact_core/probe.e",
                         "tools/implementation_probe/xpact_core/probe.ecf",
                         "benchmarks/dual_catalog/shared/dc_fixture.e",
                         "benchmarks/dual_catalog/xpact/backend.e",
                         "benchmarks/dual_catalog/xpact/catalog.ecf",
                         "benchmarks/dual_catalog/xpact_core/backend.e",
                         "benchmarks/dual_catalog/xpact_core/catalog.ecf",
                         "benchmarks/dual_w3c/shared/dw_root.e",
                         "benchmarks/dual_w3c/xpact/backend.e",
                         "benchmarks/dual_w3c/xpact/conformance.ecf",
                         "benchmarks/dual_w3c/xpact_core/backend.e",
                         "benchmarks/dual_w3c/xpact_core/conformance.ecf"):
            (self.root / relative).write_bytes(b"fixture build input\n")
        self.revision = "a" * 40
        self.configuration = "finalized/assertions-on/msvc-x64"
        self.tools = {"ec": "fixture-ec", "finish_freezing": "fixture-finish", "cl": "fixture-cl"}
        self.environment = {}
        self.commands = []
        self.fail_tool = None
        self.omit_binary = False
        self.generated_cc = "cl"
        self.probe_output = None
        self.mutate_source = False
        self.core_source = {"repository": "https://github.com/fixture/xpact-core.git",
                            "revision": self.revision, "source_dir": str(self.directory / "core"),
                            "source_sha256": "b" * 64}
        self.helper_source = Path(self.core_source["source_dir"]) / "C-tools/shift_jis_subset/src/shift_jis_subset.c"
        self.helper_source.parent.mkdir(parents=True)
        self.helper_source.write_bytes(b"int fixture_codec(void) { return 0; }\n")

    def marker(self, implementation="xpact"):
        return "\t".join(("XPACT_BUILD_PROBE", implementation, self.revision,
                          self.configuration, "OK"))

    def fake_command(self, command, *, cwd=None, env=None, log_path=None, timeout=1200):
        command = [str(value) for value in command]
        self.commands.append(command)
        if log_path:
            Path(log_path).write_text("fixture command log\n", encoding="utf-8")
        if command[0] == self.fail_tool:
            raise builds.BuildError("deliberate tool failure")
        if command[:2] == ["git", "status"]:
            return ""
        if command[:2] == ["git", "rev-parse"]:
            return self.revision
        if command[:2] == ["git", "remote"]:
            return "https://github.com/fixture/xpact.git"
        if command[0] == "fixture-cl":
            output = Path(next(value[4:] for value in command if value.startswith("/Fo:")))
            output.write_bytes(b"isolated codec object fixture")
            return "compiled pinned codec helper"
        if command[0] == "fixture-ec":
            project = Path(command[command.index("-project_path") + 1])
            target = command[command.index("-target") + 1]
            code = project / "EIFGENs" / target / "F_code"
            code.mkdir(parents=True)
            (code / "Makefile").write_text("CC = {}\nCFLAGS = -O2\n".format(self.generated_cc),
                                            encoding="utf-8")
            return "compiled fixture"
        if command[0] == "fixture-finish":
            code = Path(cwd)
            implementation = code.parents[3].name
            if not self.omit_binary:
                if code.parent.name == "probe":
                    suffix = "_build_probe.exe"
                elif code.parent.name.startswith("conformance"):
                    suffix = "_w3c_conformance.exe"
                else:
                    suffix = "_catalog_benchmark.exe"
                (code / (implementation.replace("-", "_") + suffix)).write_bytes(
                    b"MZ isolated executable fixture")
            if self.mutate_source:
                (self.root / "src/parser.e").write_bytes(b"source changed during compilation\n")
            return "linked fixture"
        if command[0].endswith(("_build_probe.exe", "_catalog_benchmark.exe", "_w3c_conformance.exe")):
            implementation = Path(command[0]).parents[4].name
            if command[0].endswith(("_catalog_benchmark.exe", "_w3c_conformance.exe")) and self.probe_output is None:
                self.assertEqual(command[1:], ["--identity"])
                metadata = Path(command[0]).parents[4] / "metadata/xp_build_identity.e"
                configuration = re.search(r'build_configuration: STRING = "([^"]+)"',
                                          metadata.read_text(encoding="utf-8"))[1]
                marker = "XPACT_W3C_IDENTITY" if command[0].endswith("_w3c_conformance.exe") else "XPACT_CATALOG_IDENTITY"
                return "\t".join((marker, implementation, self.revision,
                                  configuration, builds.GC_POLICIES[implementation]))
            return self.marker(implementation) if self.probe_output is None else self.probe_output
        raise AssertionError("Unexpected command: " + repr(command))

    def build(self, run_name, implementation="xpact", **kwargs):
        run = self.directory / run_name
        run.mkdir(exist_ok=True)
        with mock.patch.object(builds, "run_checked", side_effect=self.fake_command), \
                mock.patch.object(builds, "run_git", side_effect=lambda args, cwd: self.fake_command(
                    ["git", *args], cwd=cwd)), \
                mock.patch.object(builds, "prepare_dependency", return_value=self.core_source), \
                contextlib.redirect_stdout(io.StringIO()):
            return builds.build_one(self.root, run, implementation, self.tools,
                                    self.environment, {"fixture": "compiler metadata"}, offline=True,
                                    **kwargs)

    def manifest(self, run_name, implementation="xpact"):
        return self.directory / run_name / implementation / "build.json"

    def test_probe_requires_one_exact_backend_revision_configuration_and_success(self):
        good = self.marker()
        bad_outputs = ("", good + "\n" + good, self.marker("xpact-core"),
                       good.replace(self.revision, "c" * 40),
                       good.replace(self.configuration, "workbench/assertions-on/msvc-x64"),
                       good.replace("\tOK", "\tFAIL"))
        for output in bad_outputs:
            with self.subTest(output=output):
                with self.assertRaises(builds.BuildError):
                    builds.validate_probe(output, "xpact", self.revision, self.configuration)
        builds.validate_probe(good, "xpact", self.revision, self.configuration)

    def test_compile_failure_after_success_preserves_old_evidence_and_retry_is_independent(self):
        first = self.build("first")
        previous = self.manifest("first").read_bytes()
        self.assertEqual(first["status"], "verified")
        self.fail_tool = "fixture-ec"
        with self.assertRaises(builds.BuildError):
            self.build("second")
        self.assertFalse(self.manifest("second").exists())
        self.assertTrue((self.manifest("second").parent / "eiffel.log").exists())
        self.assertEqual(self.manifest("first").read_bytes(), previous)
        self.fail_tool = None
        recovered = self.build("third")
        self.assertEqual(recovered["status"], "verified")
        old = json.loads(previous)
        new = json.loads(self.manifest("third").read_text(encoding="utf-8"))
        self.assertNotEqual(old["executable"], new["executable"])
        self.assertEqual(old["executable_sha256"], new["executable_sha256"])

    def test_missing_executable_wrong_compiler_or_wrong_backend_never_publish_manifest(self):
        self.omit_binary = True
        with self.assertRaises(builds.BuildError):
            self.build("missing")
        self.assertFalse(self.manifest("missing").exists())
        self.omit_binary = False
        self.generated_cc = "gcc"
        with self.assertRaises(builds.BuildError):
            self.build("wrong-compiler")
        self.assertFalse(self.manifest("wrong-compiler").exists())
        self.generated_cc = "cl"
        self.probe_output = self.marker("xpact-core")
        with self.assertRaises(builds.BuildError):
            self.build("wrong-backend")
        self.assertFalse(self.manifest("wrong-backend").exists())

    def test_source_mutation_during_compile_prevents_verified_manifest(self):
        self.mutate_source = True
        with self.assertRaisesRegex(builds.BuildError, "inputs changed"):
            self.build("mutated")
        self.assertFalse(self.manifest("mutated").exists())

    def test_manifest_publication_failure_releases_temporary_file_and_leaves_no_success(self):
        with mock.patch.object(Path, "replace", side_effect=OSError("deliberate persistence failure")):
            with self.assertRaises(OSError):
                self.build("unpublished")
        self.assertFalse(self.manifest("unpublished").exists())
        self.assertEqual(list(self.manifest("unpublished").parent.glob("*.tmp")), [])
        self.assertEqual(self.build("recovered")["status"], "verified")

    def test_atomic_json_failure_preserves_previous_file_and_removes_staging(self):
        path = self.directory / "previous.json"
        path.write_bytes(b'{"status": "verified previous run"}\n')
        previous = path.read_bytes()
        with mock.patch.object(Path, "replace", side_effect=OSError("deliberate replace failure")):
            with self.assertRaises(OSError):
                builds.write_json_atomic(path, {"status": "new"})
        self.assertEqual(path.read_bytes(), previous)
        self.assertEqual(list(self.directory.glob("previous.json.*.tmp")), [])

    def test_reusing_build_destination_cannot_overwrite_previous_artifact(self):
        self.build("run")
        previous = self.manifest("run").read_bytes()
        self.commands.clear()
        with self.assertRaises(FileExistsError):
            self.build("run")
        self.assertEqual(self.commands, [])
        self.assertEqual(self.manifest("run").read_bytes(), previous)

    def test_both_implementations_have_separate_project_and_binary_paths(self):
        self.build("both", "xpact")
        self.build("both", "xpact-core")
        own = json.loads(self.manifest("both", "xpact").read_text(encoding="utf-8"))
        core = json.loads(self.manifest("both", "xpact-core").read_text(encoding="utf-8"))
        self.assertEqual(core["source"]["revision"], self.revision)
        self.assertNotEqual(own["executable"], core["executable"])
        self.assertIn("xpact_core_build_probe.exe", core["executable"])
        self.assertTrue(own["build"]["assertions"])
        self.assertTrue(core["build"]["assertions"])
        self.assertEqual(own["build"]["native_helpers"], [])
        helper = core["build"]["native_helpers"][0]
        self.assertEqual(Path(helper["source"]), self.helper_source)
        self.assertEqual(Path(helper["object"]).parent, self.manifest("both", "xpact-core").parent)
        self.assertEqual(helper["source_sha256"], builds.file_sha256(self.helper_source))
        self.assertEqual(helper["object_sha256"], builds.file_sha256(helper["object"]))

    def test_codec_helper_failure_has_no_manifest_preserves_source_and_can_retry(self):
        original_source = self.helper_source.read_bytes()
        self.fail_tool = "fixture-cl"
        with self.assertRaises(builds.BuildError):
            self.build("codec-failed", "xpact-core")
        self.assertFalse(self.manifest("codec-failed", "xpact-core").exists())
        self.assertTrue((self.manifest("codec-failed", "xpact-core").parent / "shift-jis.log").exists())
        self.assertEqual(self.helper_source.read_bytes(), original_source)
        self.assertFalse(any(command[0] == "fixture-ec" for command in self.commands))
        self.fail_tool = None
        self.assertEqual(self.build("codec-recovered", "xpact-core")["status"], "verified")
        self.assertEqual(self.helper_source.read_bytes(), original_source)

    def test_catalog_discards_assertions_and_uses_own_project_identity_and_gc_policy(self):
        self.build("catalog-off", profile="catalog", assertions=False)
        own = json.loads(self.manifest("catalog-off").read_text(encoding="utf-8"))
        command = own["build"]["command"]
        self.assertIn("-finalize", command)
        self.assertNotIn("-keep", command)
        self.assertEqual(command[command.index("-target") + 1], "catalog")
        self.assertIn("benchmarks/dual_catalog/xpact/catalog.ecf",
                      Path(command[command.index("-config") + 1]).as_posix())
        self.assertEqual(own["profile"], "catalog")
        self.assertFalse(own["build"]["assertions"])
        self.assertEqual(own["gc_policy"], "normal")
        self.assertEqual(own["build"]["configuration"], "finalized/assertions-off/msvc-x64")
        self.assertIn("xpact_catalog_benchmark.exe", own["executable"])
        self.assertTrue((self.manifest("catalog-off").parent / "identity.log").is_file())
        self.build("catalog-core-off", "xpact-core", profile="catalog", assertions=False)
        core = json.loads(self.manifest("catalog-core-off", "xpact-core").read_text(encoding="utf-8"))
        self.assertEqual(core["gc_policy"], "core-managed-off-full-collect")
        self.assertNotIn("-keep", core["build"]["command"])

    def test_catalog_audit_cannot_replace_assertions_discarded_artifact(self):
        self.build("measurement", profile="catalog", assertions=False)
        previous = self.manifest("measurement").read_bytes()
        self.build("audit", profile="catalog", assertions=True)
        audit = json.loads(self.manifest("audit").read_text(encoding="utf-8"))
        self.assertIn("-keep", audit["build"]["command"])
        command = audit["build"]["command"]
        self.assertEqual(command[command.index("-target") + 1], "catalog_assertions")
        self.assertTrue(audit["build"]["assertions"])
        self.assertEqual(audit["build"]["configuration"], "finalized/assertions-on/msvc-x64")
        self.assertNotEqual(audit["executable"], json.loads(previous)["executable"])
        self.assertEqual(self.manifest("measurement").read_bytes(), previous)

    def test_catalog_shared_source_and_runner_changes_invalidate_fingerprint(self):
        original = builds.source_fingerprint(self.root, "xpact", "catalog")
        (self.root / "benchmarks/dual_catalog/shared/dc_fixture.e").write_bytes(b"different XML fixture\n")
        changed = builds.source_fingerprint(self.root, "xpact", "catalog")
        self.assertNotEqual(original, changed)
        (self.root / "scripts/run_dual_catalog.py").write_bytes(b"new orchestration\n")
        self.assertNotEqual(changed, builds.source_fingerprint(self.root, "xpact", "catalog"))

    def test_catalog_wrong_identity_or_gc_policy_never_publishes_manifest(self):
        for index, output in enumerate((self.marker(),
                "XPACT_CATALOG_IDENTITY\txpact\t{}\tfinalized/assertions-off/msvc-x64\tcore-managed-off-full-collect".format(self.revision))):
            self.probe_output = output
            with self.assertRaises(builds.BuildError):
                self.build("bad-catalog-" + str(index), profile="catalog", assertions=False)
            self.assertFalse(self.manifest("bad-catalog-" + str(index)).exists())

    def test_w3c_profile_routes_both_backends_to_assertion_discarded_conformance_targets(self):
        for implementation in ("xpact", "xpact-core"):
            with self.subTest(implementation=implementation):
                run = "w3c-off-" + implementation
                self.build(run, implementation, profile="w3c", assertions=False)
                artifact = json.loads(self.manifest(run, implementation).read_text(encoding="utf-8"))
                command = artifact["build"]["command"]
                self.assertEqual(command[command.index("-target") + 1], "conformance")
                config = Path(command[command.index("-config") + 1]).as_posix()
                self.assertIn("benchmarks/dual_w3c/" + implementation.replace("-", "_") + "/conformance.ecf", config)
                self.assertIn("-finalize", command)
                self.assertNotIn("-keep", command)
                self.assertEqual(artifact["profile"], "w3c")
                self.assertFalse(artifact["build"]["assertions"])
                self.assertEqual(artifact["gc_policy"], builds.GC_POLICIES[implementation])
                self.assertTrue(artifact["executable"].endswith(
                    implementation.replace("-", "_") + "_w3c_conformance.exe"))
                self.assertTrue((self.manifest(run, implementation).parent / "identity.log").is_file())

    def test_w3c_audit_and_measurement_are_isolated_with_matching_source_fingerprints(self):
        self.build("w3c-measurement", "xpact-core", profile="w3c", assertions=False)
        previous = self.manifest("w3c-measurement", "xpact-core").read_bytes()
        self.build("w3c-audit", "xpact-core", profile="w3c", assertions=True)
        audit = json.loads(self.manifest("w3c-audit", "xpact-core").read_text(encoding="utf-8"))
        measured = json.loads(previous)
        command = audit["build"]["command"]
        self.assertEqual(command[command.index("-target") + 1], "conformance_assertions")
        self.assertIn("-keep", command)
        self.assertTrue(audit["build"]["assertions"])
        self.assertEqual(audit["build_inputs_sha256"], measured["build_inputs_sha256"])
        self.assertNotEqual(audit["executable"], measured["executable"])
        self.assertEqual(self.manifest("w3c-measurement", "xpact-core").read_bytes(), previous)

    def test_w3c_identity_failure_cannot_reuse_catalog_or_other_backend_success(self):
        self.build("w3c-previous", profile="w3c", assertions=False)
        previous = self.manifest("w3c-previous").read_bytes()
        config = "finalized/assertions-off/msvc-x64"
        bad = (
            "\t".join(("XPACT_CATALOG_IDENTITY", "xpact", self.revision, config, "normal")),
            "\t".join(("XPACT_W3C_IDENTITY", "xpact-core", self.revision, config, "normal")),
            "\t".join(("XPACT_W3C_IDENTITY", "xpact", self.revision, config, "core-managed-off-full-collect")),
        )
        for index, output in enumerate(bad):
            with self.subTest(output=output):
                self.probe_output = output
                run = "wrong-w3c-identity-" + str(index)
                with self.assertRaises(builds.BuildError):
                    self.build(run, profile="w3c", assertions=False)
                self.assertFalse(self.manifest(run).exists())
                self.assertEqual(self.manifest("w3c-previous").read_bytes(), previous)
        self.probe_output = None
        self.assertEqual(self.build("w3c-recovered", profile="w3c", assertions=False)["status"], "verified")

    def test_w3c_source_fingerprint_covers_its_harness_and_canonical_runner_only(self):
        initial = builds.source_fingerprint(self.root, "xpact", profile="w3c")
        (self.root / "benchmarks/dual_catalog/shared/dc_fixture.e").write_bytes(b"unrelated catalog change\n")
        self.assertEqual(initial, builds.source_fingerprint(self.root, "xpact", profile="w3c"))
        (self.root / "benchmarks/dual_w3c/shared/dw_root.e").write_bytes(b"changed raw-file handling\n")
        changed = builds.source_fingerprint(self.root, "xpact", profile="w3c")
        self.assertNotEqual(initial, changed)
        (self.root / "scripts/run_w3c_conformance.py").write_bytes(b"changed canonical verdict importer\n")
        canonical = builds.source_fingerprint(self.root, "xpact", profile="w3c")
        self.assertNotEqual(changed, canonical)
        (self.root / "scripts/run_dual_w3c.py").write_bytes(b"changed W3C orchestration\n")
        self.assertNotEqual(canonical, builds.source_fingerprint(self.root, "xpact", profile="w3c"))

    def test_main_keeps_other_backend_result_after_failure_and_next_run_preserves_evidence(self):
        original_build = builds.build_one

        def first_backend_fails(root, run_root, implementation, *args, **kwargs):
            if implementation == "xpact":
                raise builds.BuildError("deliberate first backend failure")
            return original_build(root, run_root, implementation, *args, **kwargs)

        def invoke(build_function):
            with mock.patch.object(builds, "__file__", str(self.root / "scripts/build_implementations.py")), \
                    mock.patch.object(builds, "toolchain", return_value=(self.tools, {}, {})), \
                    mock.patch.object(builds, "run_checked", side_effect=self.fake_command), \
                    mock.patch.object(builds, "run_git", side_effect=lambda args, cwd: self.fake_command(
                        ["git", *args], cwd=cwd)), \
                    mock.patch.object(builds, "prepare_dependency", return_value=self.core_source), \
                    mock.patch.object(builds, "build_one", side_effect=build_function), \
                    contextlib.redirect_stdout(io.StringIO()), \
                    contextlib.redirect_stderr(io.StringIO()):
                return builds.main(["--offline"])

        self.assertEqual(invoke(first_backend_fails), 1)
        reports = list((self.root / "build/implementations").glob("*/run.json"))
        self.assertEqual(len(reports), 1)
        previous_path = reports[0]
        previous = previous_path.read_bytes()
        failed = json.loads(previous)
        self.assertEqual(failed["status"], "failed")
        self.assertEqual([row["status"] for row in failed["results"]], ["failed", "verified"])
        self.assertEqual(invoke(original_build), 0)
        reports = list((self.root / "build/implementations").glob("*/run.json"))
        self.assertEqual(len(reports), 2)
        self.assertEqual(previous_path.read_bytes(), previous)
        latest = next(path for path in reports if path != previous_path)
        self.assertEqual(json.loads(latest.read_text(encoding="utf-8"))["status"], "verified")


if __name__ == "__main__":
    unittest.main()
