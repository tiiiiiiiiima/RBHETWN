#!/usr/bin/env python3
"""Verify a completed standalone Windows release and its isolated PCK probe.

No builds, downloads, game mutations or Windows execution are performed.
The runtime report must be produced with probe_ds_package.gd from the exported
PCK in an empty workdir. ZIP contents are read in streams to limit memory use.
"""
import argparse
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import zipfile

from build_windows_package import OFFICIAL_EXE_SHA256, OFFICIAL_EXE_SIZE, pe_certificate_table


def sha256(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def forbidden(path: str) -> bool:
    basename = PurePosixPath(path).name.lower()
    return (PurePosixPath(path).suffix.lower() in {".nds", ".srl", ".iso", ".wbfs", ".gcm", ".cia", ".3ds"}
            or basename.startswith(("bios", "firmware")))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", default="0.12")
    parser.add_argument("--archive", required=True, type=Path)
    parser.add_argument("--pck", required=True, type=Path)
    parser.add_argument("--runtime-report", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args()
    failures = []
    prefix = f"Bakugan-{args.version}-Windows/"
    runtime = json.loads(args.runtime_report.read_text(encoding="utf-8"))
    expected_version = args.version if len(args.version.split(".")) == 3 else args.version + ".0"
    if runtime.get("version") != expected_version:
        failures.append(f"Packaged version is not {expected_version}")
    if runtime.get("failures") or not runtime.get("native_ds_resource_count", 0):
        failures.append("Isolated DS resource probe failed or checked no native resources")
    if runtime.get("source_project_required") is not False:
        failures.append("Runtime probe did not declare an isolated source-independent run")
    # Godot consumes --main-pack and --headless before exposing its remaining
    # OS arguments. Preserve that observation, and verify the executor's actual
    # invocation recorded alongside the successful runtime result.
    commandline = runtime.get("executor_commandline", runtime.get("commandline_arguments", []))
    if "--path" in commandline or runtime.get("workdir_has_source_project") is not False:
        failures.append("Packaged runtime probe used a source project workdir or --path")
    try:
        main_pack = commandline[commandline.index("--main-pack") + 1]
        if Path(main_pack).resolve() != args.pck.resolve():
            failures.append("Packaged runtime probe used a different PCK")
    except (ValueError, IndexError, TypeError):
        failures.append("Packaged runtime probe has no explicit --main-pack argument")
    if not runtime.get("rom_bios_name_scan_passed"):
        failures.append("PCK ROM/BIOS name scan failed")
    local_pck_hash = sha256(args.pck)
    if runtime.get("pck_sha256") != local_pck_hash:
        failures.append("Runtime execution record does not identify the tested PCK hash")
    broken_links = []
    with zipfile.ZipFile(args.archive) as archive:
        infos = archive.infolist()
        names = [info.filename for info in infos]
        duplicates = [name for name, count in Counter(names).items() if count != 1]
        if duplicates:
            failures.append("Archive contains duplicate entries")
        unsafe = [name for name in names if not name.startswith(prefix) or ".." in PurePosixPath(name).parts or name.startswith("/")]
        if unsafe:
            failures.append("Archive contains unsafe or unexpected paths")
        raw_game_files = [name for name in names if forbidden(name)]
        if raw_game_files:
            failures.append("Archive contains forbidden ROM/BIOS names")
        launchers = [name for name in names if PurePosixPath(name).suffix.lower() in {".cmd", ".bat", ".ps1"}]
        if launchers:
            failures.append("Standalone release unexpectedly contains launcher scripts")
        bad_crc = archive.testzip()
        if bad_crc:
            failures.append("CRC failed: " + bad_crc)
        exe_name = prefix + "BakuganPrototype-Windows.exe"
        pack_name = prefix + "BakuganPrototype-Windows.pck"
        if exe_name not in names or pack_name not in names:
            failures.append("Standalone EXE/PCK pair missing")
            certificate = None
            packed_exe_sha = None
            packed_pck_sha = None
        else:
            with archive.open(pack_name) as stream:
                packed_pck_sha = hashlib.file_digest(stream, "sha256").hexdigest()
            if packed_pck_sha != local_pck_hash:
                failures.append("ZIP game pack differs from tested PCK")
            # The official EXE is bounded by the pinned size; other ZIP members
            # are never read into a single large memory buffer.
            if archive.getinfo(exe_name).file_size != OFFICIAL_EXE_SIZE:
                failures.append("Packaged Windows EXE size differs from official release")
                certificate = None
                packed_exe_sha = None
            else:
                executable = archive.read(exe_name)
                packed_exe_sha = hashlib.sha256(executable).hexdigest()
                certificate = pe_certificate_table(executable)
                if packed_exe_sha != OFFICIAL_EXE_SHA256 or not certificate.get("present"):
                    failures.append("Packaged EXE differs from unchanged pinned official release")
        for name in names:
            if not name.endswith(".md"):
                continue
            text = archive.read(name).decode("utf-8")
            for target in re.findall(r"\]\(([^)]+)\)", text):
                target = target.split("#", 1)[0]
                if not target or "://" in target or target.startswith(("#", "mailto:")):
                    continue
                relative = PurePosixPath(name).parent / target
                if str(relative) not in names:
                    broken_links.append({"document": name, "target": target})
        if broken_links:
            failures.append("Packaged Markdown has broken local links")
    report = {
        "version": args.version, "date": datetime.now(timezone.utc).isoformat(),
        "archive": str(args.archive), "bytes": args.archive.stat().st_size,
        "sha256": sha256(args.archive), "files": len(names),
        "crc_ok": bad_crc is None, "duplicate_entries": duplicates,
        "unsafe_paths": unsafe, "rom_bios_files": raw_game_files,
        "launcher_scripts": launchers, "broken_md_links": broken_links,
        "pck": {"bytes": args.pck.stat().st_size, "sha256": local_pck_hash,
                "zip_same_as_probed_pack": packed_pck_sha == local_pck_hash},
        "windows_runtime": {"sha256": packed_exe_sha, "bytes": OFFICIAL_EXE_SIZE,
                            "unchanged_official_engine": packed_exe_sha == OFFICIAL_EXE_SHA256,
                            "pe_certificate_table": certificate, "execution_tested": False},
        "packaged_ds_probe": runtime, "failures": failures,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("archive", "bytes", "sha256", "files", "crc_ok", "failures")}, indent=2))
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
