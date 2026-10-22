#!/usr/bin/python3
"""Build the exact comparison oracle without modifying system libxml2."""

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def run(*args, **kwargs):
    return subprocess.check_output(args, text=True, **kwargs).strip()


def main():
    baseline = json.loads((ROOT / "compat/baseline.json").read_text())
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    source = build / "reference-source"
    prefix = build / "reference"
    if not source.exists():
        subprocess.run(["git", "clone", "--depth", "1", "--branch", baseline["tag"],
                        baseline["repository"], str(source)], check=True)
    if run("git", "-C", str(source), "rev-parse", "HEAD") != baseline["commit"]:
        raise ValueError("Reference commit mismatch; refusing to overwrite the checkout")
    if run("git", "-C", str(source), "status", "--porcelain", "--untracked-files=all"):
        raise ValueError("Reference checkout is dirty; refusing to build an altered oracle")
    output = build / "reference-cmake"
    command = ["cmake", "-S", str(source), "-B", str(output),
               f"-DCMAKE_INSTALL_PREFIX={prefix}"]
    command.extend(f"-D{k}={v}" for k, v in baseline["cmake_options"].items())
    subprocess.run(command, check=True)
    subprocess.run(["cmake", "--build", str(output), "-j4"], check=True)
    subprocess.run(["cmake", "--install", str(output)], check=True)
    subprocess.run(["/usr/bin/python3", str(ROOT / "eng/api_inventory.py"), "--check"], check=True)


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
