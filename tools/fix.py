from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FORMAT_DIRECTORIES = [
    "src",
    "include",
    "test",
    "source",
    "benchmark",
    "fuzz",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Apply the project's common local formatting and spelling fixes."
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    return parser.parse_args()


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def emit_command_output(result: subprocess.CompletedProcess[str]) -> None:
    stdout = result.stdout.strip()
    stderr = result.stderr.strip()
    if stdout:
        print(stdout)
    if stderr:
        print(stderr)


def as_cmake_path(path: str | Path) -> str:
    return Path(path).resolve().as_posix()


def run_cmake_script(
    *,
    cmake_path: str,
    script_path: Path,
    definitions: list[str],
) -> subprocess.CompletedProcess[str]:
    command = [
        cmake_path,
        *definitions,
        "-P",
        as_cmake_path(script_path),
    ]
    return run(command)


def main() -> int:
    parse_args()

    cmake = shutil.which("cmake")
    if cmake is None:
        print("[fail] cmake not found; install CMake to use this helper.")
        return 1

    fixers_ran = 0
    warnings = 0
    failures = 0

    formatter = shutil.which("clang-format")
    if formatter is None:
        warnings += 1
        print("[warn] clang-format not found; skipping source formatting fixes")
    else:
        print(
            "[run] Applying clang-format fixes across "
            "src/, include/, test/, source/, benchmark/, and fuzz/"
        )
        format_result = run_cmake_script(
            cmake_path=cmake,
            script_path=ROOT / "cmake" / "lint.cmake",
            definitions=[
                f"-DFORMAT_COMMAND={as_cmake_path(formatter)}",
                f"-DDIRECTORIES={';'.join(FORMAT_DIRECTORIES)}",
                "-DFIX=YES",
            ],
        )
        if format_result.returncode != 0:
            failures += 1
            print("[fail] clang-format fix failed")
            emit_command_output(format_result)
        else:
            fixers_ran += 1
            print("[pass] clang-format fixes applied")
            emit_command_output(format_result)

    spell = shutil.which("codespell")
    if spell is None:
        warnings += 1
        print("[warn] codespell not found; skipping spelling fixes")
    else:
        print("[run] Applying codespell fixes across tracked text files")
        spell_result = run_cmake_script(
            cmake_path=cmake,
            script_path=ROOT / "cmake" / "spell.cmake",
            definitions=[
                f"-DSPELL_COMMAND={as_cmake_path(spell)}",
                "-DFIX=YES",
            ],
        )
        if spell_result.returncode != 0:
            failures += 1
            print("[fail] codespell fix failed")
            emit_command_output(spell_result)
        else:
            fixers_ran += 1
            print("[pass] codespell fixes applied")
            emit_command_output(spell_result)

    print(f"\nSummary: {fixers_ran} fixers ran, {warnings} warnings, {failures} failed")
    if fixers_ran == 0:
        print(
            "No fixes were applied because no optional fixer tools were available."
        )
    elif failures == 0:
        print("Local formatting and spelling fixes completed.")

    if failures > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
