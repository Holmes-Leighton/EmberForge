#!/usr/bin/env python3
"""Static cross-reference check: every `Module.func(` call must exist in the required module.
Catches typos and functions that were renamed/removed. Usage: python3 tests/check_calls.py"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

files = {}
for dp, _, fs in os.walk(SRC):
    for f in fs:
        if f.endswith(".lua"):
            files[os.path.join(dp, f)] = open(os.path.join(dp, f), encoding="utf8").read()

def module_name(path):
    n = os.path.basename(path)
    for suf in (".server.lua", ".client.lua", ".lua"):
        if n.endswith(suf):
            return n[: -len(suf)]
    return n

by_name = {}
for p in files:
    by_name.setdefault(module_name(p), []).append(p)

def defined_members(src, var):
    names = set()
    for m in re.finditer(r"function\s+%s[.:](\w+)" % re.escape(var), src): names.add(m.group(1))
    for m in re.finditer(r"^\s*%s\.(\w+)\s*=" % re.escape(var), src, re.M): names.add(m.group(1))
    for m in re.finditer(r"^\s*%s\[\"?(\w+)\"?\]\s*=" % re.escape(var), src, re.M): names.add(m.group(1))
    return names

problems = 0
for path, src in files.items():
    for m in re.finditer(r"local\s+(\w+)\s*=\s*require\(([^)]*)\)", src):
        var, target = m.group(1), m.group(2)
        last = re.findall(r"(\w+)\s*\)?$", target.strip())
        if not last: continue
        cand = by_name.get(last[0])
        if not cand or len(cand) != 1: continue
        tsrc = files[cand[0]]
        # the variable the target module returns
        rv = re.search(r"^return\s+(\w+)\s*$", tsrc, re.M)
        if not rv: continue
        members = defined_members(tsrc, rv.group(1))
        # tables built as literals: `local X = { a = ..., }` fields
        lit = re.search(r"local\s+%s\s*=\s*\{(.*?)\n\}" % re.escape(rv.group(1)), tsrc, re.S)
        if lit:
            members |= set(re.findall(r"^\s{0,8}(\w+)\s*=", lit.group(1), re.M))
        if not members: continue
        used = set(re.findall(r"\b%s[.:](\w+)\s*\(" % re.escape(var), src))
        for name in sorted(used):
            if name not in members:
                # skip Instance-y / generic names
                print("%s: %s.%s is not defined in %s" % (os.path.relpath(path, ROOT), var, name, os.path.relpath(cand[0], ROOT)))
                problems += 1
# Every RemoteEvents.<Name> used anywhere must be declared in RemoteEvents.lua
re_src = files[[p for p in files if p.endswith("Modules/RemoteEvents.lua")][0]]
declared = set(re.findall(r"^\s+(\w+)\s*=\s*\"(?:event|function)\"", re_src, re.M)) | {"Load", "CreateOnServer"}
for path, src in files.items():
    for name in sorted(set(re.findall(r"\bRemoteEvents\.(\w+)", src))):
        if name not in declared:
            print("%s: RemoteEvents.%s is not declared in RemoteEvents.lua" % (os.path.relpath(path, ROOT), name))
            problems += 1
    for name in sorted(set(re.findall(r"RemoteEvents\[\s*\"(\w+)\"\s*\]", src))):
        if name not in declared:
            print("%s: RemoteEvents[%r] is not declared" % (os.path.relpath(path, ROOT), name))
            problems += 1

print("cross-reference check:", "OK" if problems == 0 else "%d problem(s)" % problems)
sys.exit(1 if problems else 0)
