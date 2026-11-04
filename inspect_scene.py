#!/usr/bin/env python3
"""
Summarize a Wallpaper Engine scene (scene.json) so you know what you're
rendering: resolution, layer types, and effects.

Usage:
    python3 inspect_scene.py [scene_dir_or_scene.json]
"""
import json
import os
import sys


def main(argv):
    path = argv[1] if len(argv) > 1 else "scene.json"
    if os.path.isdir(path):
        path = os.path.join(path, "scene.json")
    if not os.path.isfile(path):
        print(f"error: not a file: {path}")
        return 1

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    g = data.get("general", {})
    ortho = g.get("orthogonalprojection", {})
    w = int(ortho.get("width", 0) or 0)
    h = int(ortho.get("height", 0) or 0)

    objs = data.get("objects", [])

    # Fallback: largest image layer size if orthographic projection is unset.
    if not w or not h:
        w = h = 0
        for o in objs:
            parts = str(o.get("size", "0 0")).split()
            try:
                w = max(w, int(float(parts[0])))
                h = max(h, int(float(parts[1])))
            except (IndexError, ValueError):
                pass

    kinds = {}
    effects = {}
    for o in objs:
        if o.get("particle"):
            k = "particle"
        elif o.get("text"):
            k = "text"
        elif o.get("model"):
            k = "model"
        elif o.get("image"):
            k = "image"
        else:
            k = "other"
        kinds[k] = kinds.get(k, 0) + 1
        for e in o.get("effects", []):
            name = os.path.basename(os.path.dirname(str(e.get("file", ""))))
            if name:
                effects[name] = effects.get(name, 0) + 1

    audio_react = any("audio" in k.lower() for k in effects)

    print("type        : scene")
    print(f"resolution  : {w}x{h}")
    print(f"fov         : {g.get('fov')}")
    print(f"zoom        : {g.get('zoom')}")
    print(f"objects     : {len(objs)}  ({', '.join(f'{v}x {k}' for k, v in sorted(kinds.items()))})")
    if effects:
        print("effects     : " + ", ".join(f"{v}x {k}" for k, v in sorted(effects.items())))
    print(f"audio-react : {audio_react}")
    print(f"version     : {data.get('version')}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
