#!/usr/bin/env python3
"""Every sound listed in AudioData.lua must have its wav in audio/ (run tools/make_audio.py), and every wav must be listed (no orphans).
Also checks AudioIds.lua only names sounds that exist."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data = open(os.path.join(ROOT, "src/Shared/Data/AudioData.lua"), encoding="utf8").read()
sounds = {}
for m in re.finditer(r"^\s{4}([A-Za-z0-9_]+)\s*=\s*\{([^}]*)\}", data, re.M):
    f = re.search(r'file\s*=\s*"([^"]+)"', m.group(2))
    sounds[m.group(1)] = f.group(1) if f else m.group(1)
files = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(ROOT, "audio")) if f.endswith(".wav")}
errors = []
for name, f in sorted(sounds.items()):
    if f not in files:
        errors.append("AudioData.%s has no audio/%s.wav" % (name, f))
for f in sorted(files - set(sounds.values())):
    errors.append("audio/%s.wav is not used by AudioData" % f)
ids_path = os.path.join(ROOT, "src/Shared/Data/AudioIds.lua")
for n in re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*\d+\s*,", open(ids_path, encoding="utf8").read(), re.M):
    if n not in files:
        errors.append("AudioIds names %s but audio/%s.wav does not exist" % (n, n))
print("%d sounds in AudioData, %d wav files" % (len(sounds), len(files)))
if errors:
    print("\n".join("  FAIL " + e for e in errors))
    sys.exit(1)
print("  ok   every sound has its file and every file is used")
