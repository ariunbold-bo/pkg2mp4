#!/usr/bin/env python3
"""
Extract a Wallpaper Engine "scene.pkg" (PKGV container) into its source files.

Wallpaper Engine compiles scene wallpapers into a single `.pkg` blob. This
script unpacks that blob back into the individual files a scene is made of
(scene.json, .tex textures, .frag/.vert shaders, models, fonts, ...).

The PKGV format used here (version "0023") is:

    u32  header_size        (always 8 -> length of the magic string)
    char[8] magic           ("PKGV0023")
    u32  file_count
    # then file_count entries:
    u32  name_length
    char[name_length] name
    u32  data_offset       (byte offset into the data section)
    u32  data_size         (uncompressed byte size)
    # then the raw (uncompressed) data section follows immediately.

Usage:
    python3 extract_pkg.py <scene.pkg> [output_dir]

The default output directory is named after the .pkg file.
"""
import os
import struct
import sys


def read_u32(f):
    b = f.read(4)
    if len(b) != 4:
        raise EOFError("truncated u32")
    return struct.unpack("<I", b)[0]


def extract(pkg_path, out_dir):
    with open(pkg_path, "rb") as f:
        header_size = read_u32(f)
        magic = f.read(8)
        if magic[:4] != b"PKGV":
            raise SystemExit(f"error: {pkg_path} is not a Wallpaper Engine PKG (bad magic {magic!r})")
        file_count = read_u32(f)

        print(f"magic      = {magic.decode('ascii', 'replace')}")
        print(f"header size= {header_size}")
        print(f"files      = {file_count}")

        entries = []
        for _ in range(file_count):
            name_len = read_u32(f)
            name = f.read(name_len)
            if len(name) != name_len:
                raise EOFError("truncated filename")
            offset = read_u32(f)
            size = read_u32(f)
            entries.append((name.decode("utf-8", "replace"), offset, size))

        data_start = f.tell()
        f.seek(0, os.SEEK_END)
        pkg_size = f.tell()
        data_len = pkg_size - data_start

        print(f"data starts at byte {data_start} (data section = {data_len} bytes)")

        total = 0
        for name, offset, size in entries:
            total += size
            out_path = os.path.join(out_dir, name)
            os.makedirs(os.path.dirname(out_path), exist_ok=True)

            f.seek(data_start + offset)
            data = f.read(size)
            if len(data) != size:
                print(f"  !! short read for {name}: got {len(data)} of {size}")
            with open(out_path, "wb") as of:
                of.write(data)
            print(f"  {name}  ({size} bytes)")

        print(f"\nDone. Wrote {len(entries)} files, {total} bytes total, to {out_dir}")


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 1
    pkg_path = argv[1]
    if not os.path.isfile(pkg_path):
        print(f"error: not a file: {pkg_path}")
        return 1
    if len(argv) >= 3:
        out_dir = argv[2]
    else:
        base = os.path.splitext(os.path.basename(pkg_path))[0]
        out_dir = os.path.join(os.path.dirname(pkg_path) or ".", base)
    os.makedirs(out_dir, exist_ok=True)
    extract(pkg_path, out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
