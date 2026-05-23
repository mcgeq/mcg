from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HOOKS_DIR = ROOT / ".githooks"
PRE_COMMIT_HOOK = HOOKS_DIR / "pre-commit"


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def main() -> int:
    top_level = run(["git", "rev-parse", "--show-toplevel"])
    if top_level.returncode != 0:
        print("error: not inside a git repository.")
        if top_level.stderr.strip():
            print(top_level.stderr.strip())
        return 1

    repo_root = Path(top_level.stdout.strip()).resolve()
    if repo_root != ROOT.resolve():
        print(f"error: expected git root {ROOT}, got {repo_root}.")
        return 1

    config_result = run(["git", "config", "--local", "core.hooksPath", ".githooks"])
    if config_result.returncode != 0:
        print("error: failed to configure core.hooksPath.")
        if config_result.stderr.strip():
            print(config_result.stderr.strip())
        return 1

    PRE_COMMIT_HOOK.chmod(0o755)

    print("Installed local git hooks.")
    print("Git will now use .githooks/pre-commit for this repository.")
    print("Next step: make a small test commit or run `.githooks/pre-commit` manually.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
