"""Create the current portable source, preview and bitstream archive.

This script copies files only. It never programs any hardware.
"""
from pathlib import Path
import hashlib
import html
import json
import re
import shutil
import zipfile

project = Path(__file__).resolve().parents[1]
workspace = project.parents[1]
output = workspace / "outputs" / "弦光_HDMI显示动画工程_v1.3.1"
archive = workspace / "outputs" / "弦光_HDMI显示动画工程_v1.3.1.zip"
accepted = workspace / "outputs" / "tang_studio_v09" / "firmware" / "control.fs"

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()

def main():
    firmware = project / "firmware" / "control.fs"
    manifest = json.loads((project / "firmware" / "manifest.json").read_text(encoding="utf-8-sig"))
    if digest(firmware) != manifest["sha256"].upper():
        raise RuntimeError("Build manifest and bitstream differ")
    if digest(accepted) != "899FCABFC60509C7301BD020F808EAACDE8E1C174938481A036FD4810EC199D8":
        raise RuntimeError("Accepted v0.9 image differs")
    if output.exists() or archive.exists():
        raise RuntimeError("A share package already exists; use a new version instead of overwriting it")
    output.mkdir(parents=True)
    chosen = []
    for part in ("rtl", "constraints", "assets", "controller", "scripts", "sim", "docs", "preview", "firmware", "verification"):
        source = project / part
        if not source.exists():
            continue
        for path in sorted(source.rglob("*")):
            if path.is_file() and path.suffix.lower() not in {".vvp", ".log"}:
                relative = path.relative_to(project)
                dest = output / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dest)
                chosen.append(dest)
    for filename in ("README.md", "control.gprj", "启动演奏窗口.cmd"):
        shutil.copy2(project / filename, output / filename)
        chosen.append(output / filename)
    backup_dest = output / "recovery" / "v09_control.fs"
    backup_dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(accepted, backup_dest)
    chosen.append(backup_dest)
    text = html.unescape(re.sub(r"<[^>]*>", " ", (project / "impl/pnr/control_tr_content.html").read_text(encoding="utf-8")))
    text = " ".join(text.split())
    sys_match = re.search(r"sys_clk\s+27\.000\(MHz\)\s+([\d.]+)\(MHz\)", text)
    pix_match = re.search(r"pixel_clk\s+25\.200\(MHz\)\s+([\d.]+)\(MHz\)", text)
    if not sys_match or not pix_match or "pixel_clk Setup 0.000 0" not in text:
        raise RuntimeError("Timing report is incomplete or pixel timing did not meet its gate")
    timing = {
        "source": "Gowin Education 1.9.11.03 post-route timing report",
        "system_clock_target_mhz": 27.0,
        "system_clock_actual_fmax_mhz": float(sys_match.group(1)),
        "pixel_clock_target_mhz": 25.2,
        "pixel_clock_actual_fmax_mhz": float(pix_match.group(1)),
        "system_and_pixel_negative_setup_slack": False,
        "screen_picture_reported_by_user": True,
        "screen_content_and_animation_confirmed": False,
        "programmed_to_board": True,
    }
    timing_dest = output / "verification" / "timing_summary.json"
    timing_dest.write_text(json.dumps(timing, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    chosen.append(timing_dest)
    release = {
        "name": "弦光 HDMI 显示动画工程 v1.3.1",
        "fpga": "Tang Nano 20K, PCB 3923",
        "description": "v0.9 audio plus HDMI piano display and live PCM waveform",
        "bitstream_sha256": digest(output / "firmware/control.fs"),
        "accepted_v09_sha256": digest(backup_dest),
        "programmed_to_board": True,
        "screen_picture_reported_by_user": True,
        "screen_content_and_animation_confirmed": False,
        "contains_browser_preview": True,
        "files": len(chosen),
    }
    release_dest = output / "release_manifest.json"
    release_dest.write_text(json.dumps(release, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    chosen.append(release_dest)
    sha_dest = output / "SHA256SUMS.txt"
    sha_dest.write_text("".join(f"{digest(p)}  {p.relative_to(output).as_posix()}\n" for p in sorted(chosen)), encoding="utf-8")
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=7) as zf:
        for path in sorted(output.rglob("*")):
            if path.is_file():
                zf.write(path, path.relative_to(output).as_posix())
    print(json.dumps({"folder": str(output), "archive": str(archive), "files": len(chosen) + 1,
                      "archive_bytes": archive.stat().st_size, "archive_sha256": digest(archive),
                      "timing": timing}, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
