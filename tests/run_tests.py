#!/usr/bin/env python3
"""Run a Luau test file against the real src/ modules inside a mock Roblox environment.

Usage:  python3 tests/run_tests.py tests/test_trading.lua      (or: python3 tests/run_tests.py  to run all)
Needs the `luau` command-line runtime (https://github.com/luau-lang/luau/releases) on PATH,
or set LUAU=/path/to/luau.
"""
import os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
LUAU = os.environ.get("LUAU", "luau")


def long_string(s):
    n = 0
    while "]" + "=" * n + "]" in s:
        n += 1
    return "[" + "=" * n + "[" + s + "]" + "=" * n + "]"


def bundle(test_file):
    out = ["local SOURCES = {"]
    for dirpath, _, names in os.walk(os.path.join(ROOT, "src")):
        for name in names:
            if name.endswith(".lua"):
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
                out.append("  [%r] = %s," % (rel, long_string(open(path, encoding="utf8").read())))
    out.append("}")
    out.append(open(os.path.join(HERE, "mock_env.lua"), encoding="utf8").read())
    out.append(open(test_file, encoding="utf8").read())
    return "\n".join(out)


def run(test_file):
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False, encoding="utf8") as f:
        f.write(bundle(test_file))
        path = f.name
    try:
        r = subprocess.run([LUAU, path], capture_output=True, text=True)
    finally:
        os.unlink(path)
    text = r.stdout + r.stderr
    print("=== " + os.path.basename(test_file))
    print("\n".join(l for l in text.splitlines() if "[SafeDataStore]" not in l))
    return r.returncode == 0 and "FAIL" not in text


if __name__ == "__main__":
    targets = sys.argv[1:] or sorted(
        os.path.join(HERE, n) for n in os.listdir(HERE) if n.startswith("test_") and n.endswith(".lua"))
    results = [run(t) for t in targets]
    sys.exit(0 if all(results) else 1)
