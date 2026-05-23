from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SUFFIXES = {
    ".c",
    ".cc",
    ".cpp",
    ".cxx",
    ".h",
    ".hh",
    ".hpp",
    ".hxx",
    ".ixx",
    ".cppm",
    ".inl",
}
TEXT_SUFFIXES = SOURCE_SUFFIXES | {
    ".cmake",
    ".md",
    ".txt",
    ".json",
    ".yml",
    ".yaml",
    ".py",
    ".sh",
    ".bat",
    ".cmd",
    ".ps1",
}
TEXT_NAMES = {
    "CMakeLists.txt",
    ".clangd",
    ".clang-format",
    ".clang-tidy",
    ".clang-tidy-strict",
    ".editorconfig",
    ".gitattributes",
    ".gitignore",
    ".codespellrc",
    "CMakePresets.json",
}


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def staged_files() -> list[Path]:
    result = run(["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR"])
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "failed to read staged files")
    files: list[Path] = []
    for line in result.stdout.splitlines():
        stripped = line.strip()
        if stripped:
            files.append(Path(stripped))
    return files


def chunked(items: list[Path], size: int) -> list[list[Path]]:
    return [items[index : index + size] for index in range(0, len(items), size)]


def is_text_candidate(path: Path) -> bool:
    return path.name in TEXT_NAMES or path.suffix.lower() in TEXT_SUFFIXES


def check_presets(staged: list[Path]) -> None:
    if Path("CMakePresets.json") not in staged:
        return

    print("[check] Validating CMake presets")
    result = run(["cmake", "--list-presets"])
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "cmake --list-presets failed")


def check_clang_format(staged: list[Path]) -> None:
    formatter = shutil.which("clang-format")
    source_files = [path for path in staged if path.suffix.lower() in SOURCE_SUFFIXES]
    if not source_files:
        return

    if formatter is None:
        print("[warn] clang-format not found; skipping source formatting check")
        return

    print("[check] Verifying clang-format on staged source files")
    for group in chunked(source_files, 32):
        result = run(
            [
                formatter,
                "--dry-run",
                "--Werror",
                "--style=file",
                *[str(path) for path in group],
            ]
        )
        if result.returncode != 0:
            raise RuntimeError(result.stdout.strip() or result.stderr.strip())


def check_codespell(staged: list[Path]) -> None:
    spell = shutil.which("codespell")
    text_files = [path for path in staged if is_text_candidate(path)]
    if not text_files:
        return

    if spell is None:
        print("[warn] codespell not found; skipping spelling check")
        return

    print("[check] Verifying codespell on staged text files")
    for group in chunked(text_files, 64):
        result = run([spell, *[str(path) for path in group]])
        if result.returncode != 0:
            raise RuntimeError(result.stdout.strip() or result.stderr.strip())


def main() -> int:
    try:
        staged = staged_files()
        if not staged:
            print("[skip] No staged files to validate")
            return 0

        check_presets(staged)
        check_clang_format(staged)
        check_codespell(staged)
    except RuntimeError as exc:
        print(f"[fail] {exc}", file=sys.stderr)
        return 1

    print("[pass] pre-commit checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
