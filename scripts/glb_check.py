#!/usr/bin/env python3
"""Quick check of an owner GLB (A-001): size, meshes, triangles, rig, materials, textures.
Usage: python3 scripts/glb_check.py assets/source/<file>.glb   (stdlib only)"""
import json, struct, sys


def img_dims(b):
    if b[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", b[16:24])
    if b[:2] == b"\xff\xd8":
        i = 2
        while i + 9 < len(b) and b[i] == 0xFF:
            m, n = b[i + 1], struct.unpack(">H", b[i + 2:i + 4])[0]
            if m in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", b[i + 5:i + 9])
                return w, h
            i += 2 + n
    return None


def main(path):
    d = open(path, "rb").read()
    if d[:4] != b"glTF":
        sys.exit(f"not a GLB (Git LFS pointer?): {d[:60]!r}")
    jl = struct.unpack("<I", d[12:16])[0]
    g = json.loads(d[20:20 + jl])
    bin0 = 20 + jl + 8
    acc = g.get("accessors", [])
    tris, lo, hi = 0, [1e9] * 3, [-1e9] * 3
    for m in g.get("meshes", []):
        for p in m["primitives"]:
            if p.get("mode", 4) != 4:
                continue
            pos = acc[p["attributes"]["POSITION"]]
            tris += (acc[p["indices"]]["count"] if "indices" in p else pos["count"]) // 3
            lo = [min(a, b) for a, b in zip(lo, pos.get("min", lo))]
            hi = [max(a, b) for a, b in zip(hi, pos.get("max", hi))]
    verdict = "OK" if tris <= 10000 else ("over 10k target" if tris <= 20000 else "OVER Roblox 20k limit")
    print(f"{path}: {len(d) / 1e6:.2f} MB, meshes {len(g.get('meshes', []))}, tris {tris} ({verdict})")
    print(f"mesh bounds (m): {[round(h - l, 2) for l, h in zip(lo, hi)]}, skins {len(g.get('skins', []))}, animations {len(g.get('animations', []))}")
    for mt in g.get("materials", []):
        pbr = mt.get("pbrMetallicRoughness", {})
        print(f"material {mt.get('name')}: alpha {mt.get('alphaMode', 'OPAQUE')}, maps {[k for k in pbr if k.endswith('Texture')] + [k for k in mt if k.endswith('Texture')]}")
    bvs = g.get("bufferViews", [])
    for i, im in enumerate(g.get("images", [])):
        if "bufferView" in im:
            bv = bvs[im["bufferView"]]
            s = bin0 + bv.get("byteOffset", 0)
            print(f"image {i}: {im.get('mimeType')} {img_dims(d[s:s + bv['byteLength']])}")


if __name__ == "__main__":
    main(sys.argv[1])
