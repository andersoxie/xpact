#!/usr/bin/env python3
"""Prepare and verify the immutable Xpact-core source pinned by this repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


REPO_ROOT = Path(__file__).resolve().parents[1]


class DependencyError(RuntimeError):
    """A pinned dependency could not be prepared or verified."""


def load_lock(repo_root: Path) -> dict:
    path = Path(repo_root) / "dependencies" / "xpact-core.json"
    try:
        lock = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(lock, dict):
            raise ValueError("dependency lock must be an object")
        if lock["schema_version"] != 1:
            raise ValueError("unsupported schema_version")
        if not re.fullmatch(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\.git", lock["repository"]):
            raise ValueError("repository must be an HTTPS GitHub Git URL")
        if not re.fullmatch(r"[0-9a-f]{40}", lock["revision"]):
            raise ValueError("revision must be a full lowercase commit SHA")
        if (not isinstance(lock["library"], str) or not lock["library"]
                or not isinstance(lock["required_paths"], list)
                or not all(isinstance(name, str) and name for name in lock["required_paths"])):
            raise ValueError("library and required_paths must contain relative path strings")
        for name in [lock["library"], *lock["required_paths"]]:
            relative = Path(name)
            if relative == Path(".") or relative.is_absolute() or ".." in relative.parts or "\\" in name or ":" in name:
                raise ValueError("dependency paths must be relative paths within the checkout")
        if not isinstance(lock["dependencies"], list) or not all(isinstance(item, str) for item in lock["dependencies"]):
            raise ValueError("dependencies must be a list of descriptions")
    except (OSError, ValueError, TypeError, KeyError) as exc:
        raise DependencyError(f"Cannot read dependency lock {path}: {exc}") from exc
    return lock


def run_git(arguments: list[str], cwd: Path) -> str:
    """Run Git without prompting or changing the user's global configuration."""
    environment = os.environ.copy()
    # Parent-shell repository overrides and replacement refs must never change
    # which source bytes are authenticated by the locked commit.
    for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
                 "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE"):
        environment.pop(name, None)
    environment["GIT_NO_REPLACE_OBJECTS"] = "1"
    environment["GIT_TERMINAL_PROMPT"] = "0"
    environment["GCM_INTERACTIVE"] = "never"
    # Jenkins workspaces can put loose Git objects beyond Windows MAX_PATH,
    # especially after publishing staging under the full revision directory.
    command = ["git", "-c", "core.longpaths=true", "-c", "core.autocrlf=false",
               "-c", "core.fsmonitor=false", "-c", "core.hooksPath=", *map(str, arguments)]
    try:
        result = subprocess.run(command, cwd=cwd, env=environment, capture_output=True,
                                encoding="utf-8", errors="surrogateescape", check=False,
                                timeout=180)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise DependencyError(f"Git {' '.join(arguments)} failed: {exc}") from exc
    if result.returncode:
        diagnostic = (result.stderr or result.stdout).strip()
        raise DependencyError(f"Git {' '.join(arguments)} failed ({result.returncode}): {diagnostic}")
    return result.stdout


def _reject_links(path: Path, root: Path) -> None:
    """Do not read or mutate dependency paths redirected outside the cache."""
    for candidate in [path, *path.parents]:
        if candidate.is_symlink() or (hasattr(candidate, "is_junction") and candidate.is_junction()):
            raise DependencyError(f"Dependency path is a symbolic link or junction: {candidate}")
        if candidate == root:
            return
    raise DependencyError(f"Dependency path is outside its expected root: {path}")


def verify_checkout(source_dir: Path, lock: dict) -> dict:
    """Verify HEAD, origin, all tracked bytes, and absence of generated/extra files."""
    source_dir = Path(source_dir).absolute()
    _reject_links(source_dir, source_dir.parent)
    _reject_links(source_dir / ".git", source_dir)
    if not (source_dir / ".git").is_dir():
        raise DependencyError(f"Expected a dedicated Git checkout at {source_dir}")
    actual = run_git(["rev-parse", "HEAD"], source_dir).strip()
    if actual != lock["revision"]:
        raise DependencyError(f"Xpact-core revision mismatch at {source_dir}: expected {lock['revision']}, found {actual}")
    origin = run_git(["config", "--get", "remote.origin.url"], source_dir).strip()
    if origin != lock["repository"]:
        raise DependencyError(f"Xpact-core origin mismatch at {source_dir}: {origin}")
    dirty = run_git(["status", "--porcelain=v1", "--untracked-files=all", "--ignored"], source_dir)
    if dirty.strip():
        raise DependencyError(f"Xpact-core checkout is modified or contains extra files: {source_dir}\n{dirty.strip()}")
    digest = hashlib.sha256()
    entries = run_git(["ls-tree", "-r", "-z", "--full-tree", "HEAD"], source_dir).split("\0")
    for entry in entries:
        if not entry:
            continue
        descriptor, name = entry.split("\t", 1)
        mode, kind, object_id = descriptor.split(" ")
        if kind != "blob" or mode not in ("100644", "100755"):
            raise DependencyError(f"Unsupported dependency tree entry {mode} {kind}: {name}")
        relative = Path(name)
        if relative.is_absolute() or ".." in relative.parts:
            raise DependencyError(f"Invalid dependency tree path: {name}")
        path = source_dir / relative
        _reject_links(path, source_dir)
        try:
            content = path.read_bytes()
        except OSError as exc:
            raise DependencyError(f"Cannot verify dependency source {path}: {exc}") from exc
        actual_blob = hashlib.sha1(b"blob " + str(len(content)).encode("ascii") + b"\0" + content).hexdigest()
        if actual_blob != object_id:
            raise DependencyError(f"Xpact-core tracked file bytes differ from the pinned commit: {name}")
        digest.update(mode.encode("ascii") + b" " + name.encode("utf-8", "surrogateescape") + b"\0")
        digest.update(hashlib.sha256(content).digest())
    for name in [lock["library"], *lock["required_paths"]]:
        path = source_dir / name
        _reject_links(path, source_dir)
        if not path.exists():
            raise DependencyError(f"Pinned checkout lacks required dependency path: {name}")
    return {
        "repository": lock["repository"],
        "revision": actual,
        "source_dir": str(source_dir),
        "source_sha256": digest.hexdigest(),
        "library": str(source_dir / lock["library"]),
        "dependencies": lock["dependencies"],
        "environment": {
            "XPACT_CORE": str(source_dir),
            "XPACT_INCLUDE": str(source_dir / "contrib" / "xpact" / "include"),
            "C_SHIFT_JIS_SUBSET": str(source_dir / "C-tools" / "shift_jis_subset"),
        },
    }


def _remove_staging(staging: Path, cache_root: Path) -> None:
    # Only this invocation's generated staging directory may be removed.
    _reject_links(staging, cache_root)
    if staging.parent.resolve() != cache_root.resolve() or not staging.name.startswith(".prepare-"):
        raise DependencyError(f"Refusing to remove an unexpected preparation path: {staging}")

    def retry_readonly(function, path, exception_info):
        os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
        function(path)

    shutil.rmtree(staging, onerror=retry_readonly)


def prepare_dependency(repo_root: Path, offline: bool = False) -> dict:
    """Reuse only a verified source tree, or atomically publish a fresh pinned one."""
    repo_root = Path(repo_root).resolve()
    lock = load_lock(repo_root)
    cache_root = repo_root / "build" / "dependencies" / "xpact-core"
    destination = cache_root / lock["revision"]
    _reject_links(destination, repo_root)
    if destination.exists():
        return verify_checkout(destination, lock)
    if offline:
        raise DependencyError(f"Pinned Xpact-core is not cached at {destination}; run without --offline once")
    cache_root.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".prepare-", dir=cache_root))
    try:
        run_git(["init", "--quiet"], staging)
        run_git(["remote", "add", "origin", lock["repository"]], staging)
        run_git(["fetch", "--no-tags", "--depth=1", "origin", lock["revision"]], staging)
        run_git(["checkout", "--detach", "--quiet", "FETCH_HEAD"], staging)
        verify_checkout(staging, lock)
        # Another invocation may have prepared the same immutable revision.
        # Its verified destination wins; no established checkout is overwritten.
        if destination.exists():
            return verify_checkout(destination, lock)
        try:
            staging.rename(destination)
        except OSError:
            if destination.exists():
                return verify_checkout(destination, lock)
            raise
        return verify_checkout(destination, lock)
    except OSError as exc:
        raise DependencyError(f"Cannot prepare pinned Xpact-core: {exc}") from exc
    finally:
        if staging.exists():
            _remove_staging(staging, cache_root)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--offline", action="store_true", help="verify an existing checkout without any network access")
    args = parser.parse_args(argv)
    try:
        metadata = prepare_dependency(REPO_ROOT, offline=args.offline)
        print(json.dumps(metadata, indent=2))
        return 0
    except (DependencyError, OSError) as exc:
        print(f"Xpact-core preparation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
