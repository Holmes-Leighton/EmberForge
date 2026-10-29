#!/usr/bin/env python3
"""Uploads audio/*.wav to Roblox (Open Cloud Assets API) and records the asset ids in src/Shared/Data/AudioIds.lua, which AudioData reads.

Setup (once):
  1. Creator Hub > Open Cloud > API Keys > Create: add the "Assets" API system with Read + Write, and your own user (or group) as the owner.
  2. set ROBLOX_API_KEY=<key>   and   set ROBLOX_USER_ID=<your user id>      (or ROBLOX_GROUP_ID=<group id> for a group-owned game)

Usage:  python tools/upload_audio.py              (uploads everything not uploaded yet)
        python tools/upload_audio.py Click Craft  (only these)
        python tools/upload_audio.py --force      (re-upload all)

Roblox moderates uploaded audio, so an id can take a few minutes to start playing. Sounds that fail upload are listed at the end; the game stays silent for
those (or uses the built-in fallback in AudioData) and you can run the script again.
If Roblox refuses .wav, convert the files to .mp3 or .ogg (for example with Audacity) and change MIME below.
"""
import json, os, re, sys, time, urllib.error, urllib.request, uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "audio")
IDS = os.path.join(ROOT, "src", "Shared", "Data", "AudioIds.lua")
API = "https://apis.roblox.com/assets/v1"
MIME = "audio/wav"


def read_ids():
    ids = {}
    if os.path.exists(IDS):
        for name, val in re.findall(r"^\s*([A-Za-z0-9_]+)\s*=\s*(\d+)\s*,", open(IDS, encoding="utf8").read(), re.M):
            ids[name] = int(val)
    return ids


def write_ids(ids):
    lines = ["-- Roblox asset ids of the sounds in audio/, written by tools/upload_audio.py (AudioData reads this). Do not edit by hand; a missing sound is silent.",
             "return {"]
    for name in sorted(ids):
        lines.append("    %s = %d," % (name, ids[name]))
    lines.append("}")
    open(IDS, "w", encoding="utf8").write("\n".join(lines) + "\n")


def multipart(fields, file_field, file_name, file_bytes, file_mime):
    boundary = "----ef" + uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\nContent-Type: application/json\r\n\r\n%s\r\n" % (boundary, k, v)).encode())
    parts.append(("--%s\r\nContent-Disposition: form-data; name=\"%s\"; filename=\"%s\"\r\nContent-Type: %s\r\n\r\n" % (boundary, file_field, file_name, file_mime)).encode())
    parts.append(file_bytes)
    parts.append(("\r\n--%s--\r\n" % boundary).encode())
    return b"".join(parts), "multipart/form-data; boundary=" + boundary


def call(req):
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode() or "{}")
    except urllib.error.HTTPError as e:
        raise RuntimeError("HTTP %d: %s" % (e.code, e.read().decode(errors="replace")[:300]))


def upload(key, creator, name, path):
    request = {"assetType": "Audio", "displayName": "EmberForge " + name, "description": "EmberForge original sound: " + name, "creationContext": {"creator": creator}}
    body, ctype = multipart({"request": json.dumps(request)}, "fileContent", os.path.basename(path), open(path, "rb").read(), MIME)
    op = call(urllib.request.Request(API + "/assets", data=body, method="POST", headers={"x-api-key": key, "Content-Type": ctype}))
    op_path = op.get("path")
    if not op_path:
        raise RuntimeError("no operation returned: %s" % op)
    for _ in range(40):
        time.sleep(1.5)
        st = call(urllib.request.Request(API + "/" + op_path, headers={"x-api-key": key}))
        if st.get("done"):
            if "error" in st:
                raise RuntimeError(str(st["error"]))
            return int(st["response"]["assetId"])
    raise RuntimeError("timed out waiting for the upload to finish")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    key = os.environ.get("ROBLOX_API_KEY")
    user, group = os.environ.get("ROBLOX_USER_ID"), os.environ.get("ROBLOX_GROUP_ID")
    if not key or not (user or group):
        sys.exit("Set ROBLOX_API_KEY and ROBLOX_USER_ID (or ROBLOX_GROUP_ID) first. See the top of this file.")
    creator = {"groupId": group} if group else {"userId": user}
    names = sorted(os.path.splitext(f)[0] for f in os.listdir(AUDIO) if f.endswith(".wav"))
    if args:
        names = [n for n in names if n in args]
    ids = read_ids()
    failed = []
    for name in names:
        if name in ids and not force:
            print("  skip   %-16s (already %d)" % (name, ids[name]))
            continue
        try:
            ids[name] = upload(key, creator, name, os.path.join(AUDIO, name + ".wav"))
            print("  ok     %-16s %d" % (name, ids[name]))
            write_ids(ids)
        except Exception as e:
            failed.append(name)
            print("  FAILED %-16s %s" % (name, e))
    write_ids(ids)
    print("\n%d uploaded or kept, %d failed%s" % (len(ids), len(failed), (": " + ", ".join(failed)) if failed else ""))


if __name__ == "__main__":
    main()
