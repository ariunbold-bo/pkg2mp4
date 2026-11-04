# scene.pkg → mp4

## The short version

A Wallpaper Engine `scene.pkg` is **not a video** — it's a *compiled scene*.
It holds a scene graph (`scene.json`), textures (`.tex`, which are DDS/BCn),
GLSL shaders, models, fonts, and particle presets. Wallpaper Engine renders all
of that **in real time** (parallax, water ripples, snow particles, a live clock,
audio-reactive bars, a rigged character, …). There are no pre-rendered frames to
extract, so there is **no direct/lossless `pkg → mp4` conversion**.

The only faithful way to get an MP4 is:

> **Play the scene in Wallpaper Engine, then record the screen.**

Everything else is an approximation. Since you're on Linux, the recording step
happens in your Windows VM (Wallpaper Engine has no native Linux build).

---

## The move (2 stages)

### Stage 1 — extract & inspect (Linux, no VM)

```bash
# Unpack the compiled PKG into a folder of source files:
python3 pkg2mp4/extract_pkg.py "3719048785_VSTHEMES-ORG/scene.pkg" scene_out

# Quick summary (resolution, layers, effects):
python3 pkg2mp4/inspect_scene.py scene_out
```

For this scene that prints:

```
resolution  : 3840x2160     # 4K
objects     : image layers + particles + text(clock) + a rigged model
effects     : cloud motion, water waves, depth parallax, foliage sway,
              shake, color grading, blur, light shafts, snow
audio-react : true
```

`extract_pkg.py` is a self-contained PKG unpacker (no dependencies). It was
validated byte-for-byte against a reference extraction of `scene.pkg`.

### Stage 2 — render & record (Windows VM)

1. **Install** Steam + Wallpaper Engine (and `ffmpeg` via `winget install Gyan.FFmpeg`).
2. **Get the scene in.** Easiest: subscribe to the Workshop item in WE
   (`workshopid = 3719048785`). Offline alternative: copy the whole
   `3719048785_VSTHEMES-ORG` folder into WE's workshop content dir:
   `%ProgramFiles(x86)%\Steam\steamapps\workshop\content\431960\3719048785\`
   (that folder already has `project.json` + `scene.pkg` + `shaders\` + `preview.gif`).
3. **Set it up clean (so you record only the wallpaper, not the UI):**
   - Apply the wallpaper, display mode **Fill**, single monitor.
   - Hide desktop icons — either manually (right-click desktop → View →
     *Show desktop icons*) or pass `-HideDesktopIcons` to the script.
   - Auto-hide the taskbar (Settings → Personalization → Taskbar).
   - The recorder does **not** draw the mouse cursor.
4. **Record** with PowerShell:

   ```powershell
   cd pkg2mp4
   .\record_scene.ps1 -DurationSeconds 30 -Output holospice.mp4
   # or auto-hide icons for the duration:
   .\record_scene.ps1 -DurationSeconds 30 -HideDesktopIcons -Output holospice.mp4
   ```

   For a true 4K capture, make sure the VM's virtual display is 3840×2160 first,
   then:

   ```powershell
   .\record_scene.ps1 -DurationSeconds 30 -VideoSize 3840x2160 -Output holospice_4k.mp4
   ```

---

## Getting a clean, smooth capture

The two things that matter for a good result:

**1. Only the wallpaper in frame.** The wallpaper *is* the desktop background, so
`record_scene.ps1` captures the monitor. To get a clean frame:
- Hide desktop icons (manual, or `-HideDesktopIcons`).
- Auto-hide the taskbar.
- Cursor is already excluded (`-draw_mouse 0`).
- Multi-monitor trick: put the wallpaper on a second monitor with no icons, then
  capture just that one with `-OutputIdx 1` (ddagrab). Note: some ffmpeg builds
  name this option differently — check `ffmpeg -h demuxer=ddagrab` first.

**2. Smooth fps.** `record_scene.ps1` now uses `ddagrab` (DirectX 11 Desktop
Duplication — hardware-accelerated) by default instead of `gdigrab`, which was
the CPU-bound GDI capture causing the stutter. If `ddagrab` isn't available it
falls back to `gdigrab` automatically and prints a tip.
- Keep it at **30 fps** unless your VM has real GPU acceleration; 60 fps in a
  software-rendered VM will just stutter.
- If fps is still bad, the real fix is enabling **3D acceleration** in the VM
  (VirtualBox: Display → Enable 3D Acceleration) or giving the VM a GPU, then
  using **OBS with Display Capture** — OBS uses DXGI and handles this best.

---

## Files

| File                 | Purpose                                              | Runs on |
| -------------------- | ---------------------------------------------------- | ------- |
| `extract_pkg.py`     | Unpack `scene.pkg` (PKGV container) into source files | Linux   |
| `inspect_scene.py`   | Print resolution / layers / effects from `scene.json` | Linux   |
| `record_scene.ps1`   | Record the wallpaper to MP4 via ffmpeg `ddagrab` (hardware) | Windows |

## Why not a one-shot Linux script?

A faithful `pkg → mp4` would mean re-implementing Wallpaper Engine's renderer
(shader pipeline, blend modes, particle sim, skeletal mesh, timeline) in Python
or ffmpeg — not practical. An *approximate* Linux renderer (decode the `.tex`
layers and slowly pan/parallax them with ffmpeg) is possible but won't match the
real scene's water/foliage/particles/clock, so the VM recording is the reliable
route.

## Notes on your other download

- `3021397595_VSTHEMES-ORG.zip` is **0 bytes** (failed download) — re-download
  that workshop item before trying to process it.
