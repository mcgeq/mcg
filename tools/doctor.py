from __future__ import annotations

import argparse
import os
import platform
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MIN_CMAKE_VERSION = (3, 25, 0)
MIN_MODULES_CMAKE_VERSION = (3, 28, 0)


@dataclass(frozen=True)
class Finding:
    level: str
    subject: str
    detail: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check whether the local environment is ready for this project."
    )
    parser.add_argument(
        "--doctor",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Treat warnings as failures for CI-style gating.",
    )
    return parser.parse_args()


def run_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def parse_version(text: str) -> tuple[int, int, int] | None:
    match = re.search(r"(\d+)\.(\d+)\.(\d+)", text)
    if match is None:
        return None
    return tuple(int(part) for part in match.groups())


def format_version(version: tuple[int, int, int] | None) -> str:
    if version is None:
        return "unknown"
    return ".".join(str(part) for part in version)


def detect_tool(name: str) -> tuple[str | None, tuple[int, int, int] | None]:
    path = shutil.which(name)
    if path is None:
        return None, None

    result = run_command([path, "--version"])
    output = f"{result.stdout}\n{result.stderr}"
    return path, parse_version(output)


def detect_cmake() -> tuple[str | None, tuple[int, int, int] | None]:
    path = shutil.which("cmake")
    if path is None:
        return None, None

    result = run_command([path, "--version"])
    output = f"{result.stdout}\n{result.stderr}"
    return path, parse_version(output)


def emit(finding: Finding) -> None:
    print(f"[{finding.level}] {finding.subject}: {finding.detail}")


def readiness(condition: bool, subject: str, ok_detail: str, warn_detail: str) -> Finding:
    if condition:
        return Finding("PASS", subject, ok_detail)
    return Finding("WARN", subject, warn_detail)


def recommendation_lines(
    *,
    gxx_ready: bool,
    clangxx_ready: bool,
    ninja_ready: bool,
    vcpkg_ready: bool,
    modules_cmake_ready: bool,
) -> list[str]:
    lines: list[str] = []

    if modules_cmake_ready and clangxx_ready and ninja_ready and vcpkg_ready:
        lines.append(
            "Recommended next step: `cmake --workflow --preset modules-dev-debug`"
        )
        lines.append(
            "Why: this machine is ready for the modern C++ path with modules, tests, and package smoke coverage."
        )
        return lines

    if gxx_ready and vcpkg_ready:
        lines.append(
            "Recommended next step: `cmake --workflow --preset dev-debug`"
        )
        lines.append(
            "Why: this machine is ready for the normal developer workflow with tests."
        )
        if modules_cmake_ready and clangxx_ready and not ninja_ready:
            lines.append(
                "To unlock modules next: install Ninja, then try `cmake --workflow --preset modules-dev-debug`."
            )
        elif modules_cmake_ready and not clangxx_ready:
            lines.append(
                "To unlock modules next: install clang++, then try `cmake --workflow --preset modules-dev-debug`."
            )
        elif modules_cmake_ready and clangxx_ready and ninja_ready and not vcpkg_ready:
            lines.append(
                "To unlock modules tests next: set `VCPKG_ROOT`, then try `cmake --workflow --preset modules-dev-debug`."
            )
        return lines

    if gxx_ready:
        lines.append(
            "Recommended next step: `cmake --workflow --preset default-debug`"
        )
        lines.append(
            "Why: the basic GNU build path is ready, but developer-mode dependencies are incomplete."
        )
        if not vcpkg_ready:
            lines.append(
                "To unlock tests and richer presets: set `VCPKG_ROOT`, then try `cmake --workflow --preset dev-debug`."
            )
        return lines

    if clangxx_ready and ninja_ready and modules_cmake_ready:
        lines.append(
            "Recommended next step: `cmake --workflow --preset modules-debug`"
        )
        lines.append(
            "Why: the optional modules compile path is ready, even though the GNU presets are not."
        )
        if not vcpkg_ready:
            lines.append(
                "To unlock modules tests: set `VCPKG_ROOT`, then try `cmake --workflow --preset modules-dev-debug`."
            )
        return lines

    lines.append("Recommended next step: fix the failing environment checks above first.")
    missing: list[str] = []
    if not gxx_ready:
        missing.append("g++")
    if not clangxx_ready:
        missing.append("clang++")
    if not ninja_ready:
        missing.append("ninja")
    if not vcpkg_ready:
        missing.append("VCPKG_ROOT")
    if missing:
        lines.append("Most useful missing pieces: " + ", ".join(missing))
    return lines


def main() -> int:
    args = parse_args()
    findings: list[Finding] = []

    findings.append(
        Finding(
            "PASS",
            "Workspace",
            f"{ROOT} on {platform.system()} {platform.release()}",
        )
    )
    findings.append(
        Finding(
            "PASS",
            "Python",
            f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        )
    )

    cmake_path, cmake_version = detect_cmake()
    if cmake_path is None:
        findings.append(
            Finding(
                "FAIL",
                "CMake",
                "Not found on PATH. Install CMake 3.25 or newer.",
            )
        )
        for finding in findings:
            emit(finding)
        print("\nSummary: 2 passed, 0 warnings, 1 failed")
        return 1

    if cmake_version is None or cmake_version < MIN_CMAKE_VERSION:
        findings.append(
            Finding(
                "FAIL",
                "CMake",
                "Found "
                f"{format_version(cmake_version)} at {cmake_path}, "
                "but this project requires 3.25 or newer.",
            )
        )
    else:
        findings.append(
            Finding(
                "PASS",
                "CMake",
                f"{format_version(cmake_version)} at {cmake_path}",
            )
        )

    preset_result = run_command(["cmake", "--list-presets"])
    if preset_result.returncode == 0:
        findings.append(
            Finding("PASS", "Preset schema", "CMakePresets.json is readable.")
        )
    else:
        findings.append(
            Finding(
                "FAIL",
                "Preset schema",
                "CMake could not read CMakePresets.json.\n"
                f"{preset_result.stderr.strip()}".strip(),
            )
        )

    gxx_path, gxx_version = detect_tool("g++")
    clangxx_path, clangxx_version = detect_tool("clang++")
    ninja_path, ninja_version = detect_tool("ninja")
    clangd_path, clangd_version = detect_tool("clangd")

    if gxx_path is not None:
        findings.append(
            Finding(
                "PASS",
                "g++",
                f"{format_version(gxx_version)} at {gxx_path}",
            )
        )
    else:
        findings.append(
            Finding(
                "WARN",
                "g++",
                "Not found on PATH. GNU presets such as default-debug are unavailable.",
            )
        )

    if clangxx_path is not None:
        findings.append(
            Finding(
                "PASS",
                "clang++",
                f"{format_version(clangxx_version)} at {clangxx_path}",
            )
        )
    else:
        findings.append(
            Finding(
                "WARN",
                "clang++",
                "Not found on PATH. Modules and fuzz presets are unavailable.",
            )
        )

    if ninja_path is not None:
        findings.append(
            Finding(
                "PASS",
                "Ninja",
                f"{format_version(ninja_version)} at {ninja_path}",
            )
        )
    else:
        findings.append(
            Finding(
                "WARN",
                "Ninja",
                "Not found on PATH. modules-debug and modules-dev-debug need Ninja.",
            )
        )

    if clangd_path is not None:
        findings.append(
            Finding(
                "PASS",
                "clangd",
                f"{format_version(clangd_version)} at {clangd_path}",
            )
        )
    else:
        findings.append(
            Finding(
                "WARN",
                "clangd",
                "Not found on PATH. Editor diagnostics will rely on other tooling.",
            )
        )

    vcpkg_root = os.environ.get("VCPKG_ROOT")
    if not vcpkg_root:
        findings.append(
            Finding(
                "WARN",
                "VCPKG_ROOT",
                "Not set. dev-*, coverage, tidy-*, bench-debug, and modules-dev-debug are unavailable.",
            )
        )
        has_vcpkg = False
    else:
        vcpkg_root_path = Path(vcpkg_root)
        toolchain = vcpkg_root_path / "scripts" / "buildsystems" / "vcpkg.cmake"
        has_vcpkg = toolchain.exists()
        findings.append(
            readiness(
                has_vcpkg,
                "VCPKG_ROOT",
                f"{vcpkg_root} (toolchain found)",
                f"{vcpkg_root} is set, but {toolchain} was not found.",
            )
        )

    has_modules_cmake = (
        cmake_version is not None and cmake_version >= MIN_MODULES_CMAKE_VERSION
    )
    gxx_ready = gxx_path is not None
    clangxx_ready = clangxx_path is not None
    ninja_ready = ninja_path is not None

    findings.append(
        readiness(
            gxx_ready,
            "Preset default-debug/default-release",
            "Ready.",
            "Requires g++ on PATH.",
        )
    )
    findings.append(
        readiness(
            gxx_ready and has_vcpkg,
            "Preset dev-debug/dev-release/asan/coverage/tidy-*",
            "Ready.",
            "Requires g++ on PATH plus a valid VCPKG_ROOT.",
        )
    )
    findings.append(
        readiness(
            gxx_ready and has_vcpkg,
            "Preset bench-debug",
            "Ready.",
            "Requires g++ on PATH plus a valid VCPKG_ROOT.",
        )
    )
    findings.append(
        readiness(
            clangxx_ready and has_vcpkg,
            "Preset fuzz-debug",
            "Ready.",
            "Requires clang++ on PATH plus a valid VCPKG_ROOT.",
        )
    )
    findings.append(
        readiness(
            has_modules_cmake and clangxx_ready and ninja_ready,
            "Preset modules-debug",
            "Ready.",
            "Requires CMake 3.28+, clang++, and Ninja.",
        )
    )
    findings.append(
        readiness(
            has_modules_cmake
            and clangxx_ready
            and ninja_ready
            and has_vcpkg,
            "Preset modules-dev-debug",
            "Ready.",
            "Requires CMake 3.28+, clang++, Ninja, and a valid VCPKG_ROOT.",
        )
    )

    if os.name == "nt":
        findings.append(
            Finding(
                "WARN",
                "MSVC presets",
                "Verify Visual Studio 2022 with the C++ workload is installed before using msvc-* presets.",
            )
        )

    for finding in findings:
        emit(finding)

    passed = sum(1 for finding in findings if finding.level == "PASS")
    warned = sum(1 for finding in findings if finding.level == "WARN")
    failed = sum(1 for finding in findings if finding.level == "FAIL")
    print(f"\nSummary: {passed} passed, {warned} warnings, {failed} failed")
    print("")
    for line in recommendation_lines(
        gxx_ready=gxx_ready,
        clangxx_ready=clangxx_ready,
        ninja_ready=ninja_ready,
        vcpkg_ready=has_vcpkg,
        modules_cmake_ready=has_modules_cmake,
    ):
        print(line)

    if failed > 0:
        return 1
    if args.strict and warned > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
