# record_scene.ps1
#
# Record a Wallpaper Engine scene to MP4.
#
# Default capture method is `ddagrab` (DirectX 11 Desktop Duplication) which is
# GPU-accelerated and far smoother than `gdigrab`. It does NOT draw the mouse
# cursor. If ddagrab isn't available (VM without a WDDM/3D driver), the script
# falls back to `gdigrab` automatically.
#
# TO RECORD *ONLY* THE WALLPAPER (not icons/taskbar):
#   - Easiest: right-click desktop -> View -> uncheck "Show desktop icons",
#     and Settings -> Personalization -> Taskbar -> auto-hide. Or:
#   - Run with -HideDesktopIcons to do the icon part automatically (restores
#     them after recording).
#   - Or: put the wallpaper on a secondary monitor and pass -OutputIdx 1.
#
# REQUIREMENTS: ffmpeg on PATH.  winget install Gyan.FFmpeg
#
# EXAMPLES:
#   .\record_scene.ps1 -DurationSeconds 30 -Output holospice.mp4
#   .\record_scene.ps1 -DurationSeconds 30 -HideDesktopIcons
#   .\record_scene.ps1 -DurationSeconds 60 -Fps 60 -VideoSize 3840x2160 -Output h4k.mp4

param(
    [int]    $DurationSeconds  = 30,
    [int]    $Fps              = 30,        # 30 is smooth for scenes; try 60 only if HW capture is fast
    [string] $Method           = "auto",    # auto | ddagrab | gdigrab
    [int]    $OutputIdx        = 0,         # non-primary monitor index (only passed when != 0; check `ffmpeg -h demuxer=ddagrab` for the exact option name in your build)
    [int]    $OffsetX          = 0,         # gdigrab region offset
    [int]    $OffsetY          = 0,
    [string] $VideoSize        = "",        # e.g. "3840x2160"; empty = full monitor
    [string] $Output           = "scene.mp4",
    [string] $Crf              = "18",      # lower = better quality / bigger file
    [string] $Preset           = "veryfast",
    [switch] $HideDesktopIcons              # temporarily hide desktop icons during recording
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Error "ffmpeg not found. Install it with: winget install Gyan.FFmpeg"
    exit 1
}

$iconKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

function Build-Args([string]$method) {
    $a = @("-y", "-f", $method)

    if ($method -eq "ddagrab") {
        $a += @("-framerate", "$Fps", "-draw_mouse", "0")
        # Not all ffmpeg builds accept -output_idx; only pass it for a non-primary monitor.
        if ($OutputIdx -ne 0) { $a += @("-output_idx", "$OutputIdx") }
        if ($VideoSize -ne "") { $a += @("-video_size", $VideoSize) }
        if ($OffsetX -ne 0)   { $a += @("-offset_x", "$OffsetX") }
        if ($OffsetY -ne 0)   { $a += @("-offset_y", "$OffsetY") }
    } else { # gdigrab
        $a += @("-framerate", "$Fps", "-draw_mouse", "0")
        if ($VideoSize -ne "") { $a += @("-video_size", $VideoSize) }
        if ($OffsetX -ne 0)   { $a += @("-offset_x", "$OffsetX") }
        if ($OffsetY -ne 0)   { $a += @("-offset_y", "$OffsetY") }
    }

    $a += @(
        "-i", "desktop",
        "-t", "$DurationSeconds",
        "-c:v", "libx264",
        "-preset", $Preset,
        "-crf", $Crf,
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        $Output
    )
    return $a
}

function Run-Capture([string]$method) {
    $ffArgs = Build-Args $method
    $ErrorActionPreference = "Continue"   # ffmpeg writes its banner to stderr; don't treat that as fatal
    $log = & ffmpeg @ffArgs 2>&1
    $code = $LASTEXITCODE
    $log | ForEach-Object { Write-Host $_ }
    return @{ Code = $code; Log = ($log -join "`n") }
}

$hidIcons = $false
$prevHideIcons = 0
if ($HideDesktopIcons) {
    $prevHideIcons = (Get-ItemProperty -Path $iconKey -Name HideIcons -ErrorAction SilentlyContinue).HideIcons
    if ($null -eq $prevHideIcons) { $prevHideIcons = 0 }
    Set-ItemProperty -Path $iconKey -Name HideIcons -Value 1
    Stop-Process -ProcessName explorer -Force -ErrorAction SilentlyContinue   # restarts itself
    $hidIcons = $true
    Start-Sleep -Seconds 2
}

try {
    Write-Host "Recording $DurationSeconds s @ ${Fps}fps -> $Output"
    Write-Host "Starting in 3 seconds (get the wallpaper front-and-center, hide taskbar if needed)..."
    Start-Sleep -Seconds 3

    $res = $null
    if ($Method -eq "auto") {
        $res = Run-Capture "ddagrab"
        if ($res.Code -ne 0 -and $res.Log -match "ddagrab|Desktop Duplication|Failed to open|No such") {
            Write-Host "`nddagrab unavailable (no WDDM/3D driver in this VM?) -> falling back to gdigrab."
            Write-Host "Tip: enable 3D acceleration in the VM, or use OBS Display Capture, for better fps."
            $res = Run-Capture "gdigrab"
        }
    } else {
        $res = Run-Capture $Method
    }

    if ($res.Code -eq 0) {
        Write-Host "Done: $Output"
    } else {
        Write-Error "ffmpeg failed with exit code $($res.Code)"
        exit $res.Code
    }
}
finally {
    if ($hidIcons) {
        Set-ItemProperty -Path $iconKey -Name HideIcons -Value $prevHideIcons
        Stop-Process -ProcessName explorer -Force -ErrorAction SilentlyContinue
    }
}
