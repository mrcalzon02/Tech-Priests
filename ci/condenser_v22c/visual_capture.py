#!/usr/bin/env python3
"""Capture actual Factorio 2.1 GUI screenshots of source-locked condenser V22C.

Requires a logged-on Windows desktop. Uses an isolated Factorio mod/config/save
profile and the real game's take_screenshot API. Never substitutes Blender or
image generation for in-client screenshots. Refuses success without the native
engine log, 16 real PNGs and independent checksum/image readback.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import traceback
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MOD = ROOT / "tech-priests_src"
APPROVED = ROOT / "art/source-to-3d/condenser-v21/captures/v22c"
DIRECTIONS = ("north", "east", "south", "west")
STATES = ("idle", "working")
ZOOMS = ("normal", "close")
SOURCE_SHA = "1ccd8093e5b153d80b7ac66cb77b364f05e7ee46a5f236efe189498b71dd052b"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require_interactive_desktop() -> int:
    """The Windows Actions service is Session 0: D3D11 GUI output cannot be created there."""
    if os.name != "nt":
        raise RuntimeError("Genuine Factorio GUI capture requires the Windows desktop client")
    import ctypes
    session_id=ctypes.c_ulong(0)
    pid=os.getpid()
    ok=ctypes.windll.kernel32.ProcessIdToSessionId(
        ctypes.c_ulong(pid),ctypes.byref(session_id))
    if not ok:
        raise OSError("Cannot determine Windows desktop session ID")
    if session_id.value == 0:
        raise RuntimeError(
            "INTERACTIVE_DESKTOP_REQUIRED: Windows service Session 0 cannot display "
            "Factorio D3D11: actual engine log showed SDL_DXGIGetOutputInfo failure "
            "and DXGI_ERROR_NOT_CURRENTLY_AVAILABLE (0x887a0022). "
            "Run this exact capture from a logged-on Windows user desktop, not "
            "the GitHub runner service. No in-game screenshot was captured.")
    print("FACTORIO_GRAPHICAL_WINDOWS_SESSION",session_id.value,flush=True)
    return session_id.value

def game_candidates() -> list[Path]:
    """Only known install locations, PATH, and Steam library metadata."""
    found = []
    for name in ("FACTORIO_GUI_EXE", "FACTORIO_CLIENT_PATH", "FACTORIO_EXE"):
        if os.environ.get(name):
            found.append(Path(os.environ[name]).expanduser())
    cmd = shutil.which("factorio.exe") or shutil.which("factorio")
    if cmd:
        found.append(Path(cmd))
    for drive in ("C:", "D:", "E:", "F:"):
        for root in ("Factorio", "Games/Factorio", "SteamLibrary B/steamapps/common/Factorio", "SteamLibrary/steamapps/common/Factorio",
                     "Steam/steamapps/common/Factorio",
                     "Program Files (x86)/Steam/steamapps/common/Factorio",
                     "Program Files/Steam/steamapps/common/Factorio",
                     "Program Files/Factorio"):
            found.append(Path(drive + "/" + root + "/bin/x64/factorio.exe"))
    roots = [Path(os.getenv("PROGRAMFILES(X86)", "C:/Program Files (x86)")) / "Steam",
             Path(os.getenv("PROGRAMFILES", "C:/Program Files")) / "Steam"]
    appdata = os.environ.get("LOCALAPPDATA")
    if appdata:
        roots.append(Path(appdata) / "Steam")
    try:
        import winreg
        for key in (r"Software\Valve\Steam",r"Software\WOW6432Node\Valve\Steam"):
            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key) as reg:
                    path,_ = winreg.QueryValueEx(reg, "SteamPath")
                    roots.append(Path(path))
            except OSError:
                pass
    except ImportError:
        pass
    for steam in roots:
        found.append(steam / "steamapps/common/Factorio/bin/x64/factorio.exe")
        libraries = steam / "steamapps/libraryfolders.vdf"
        if not libraries.is_file():
            continue
        try:
            content = libraries.read_text(encoding="utf-8-sig",errors="replace")
        except OSError:
            continue
        for match in re.findall(r'"path"\s+"([^"]+)"', content):
            library = Path(match.replace("\\\\","\\"))
            found.append(library/"steamapps/common/Factorio/bin/x64/factorio.exe")
    # Deterministic and bounded list; do not scan unrelated user directories.
    return list(dict.fromkeys(p.resolve() for p in found))

def find_client(explicit: str | None) -> tuple[Path,str]:
    candidates=([Path(explicit).expanduser().resolve()] if explicit else game_candidates())
    diagnostics=[]
    for path in candidates:
        if not path.is_file():
            continue
        try:
            info=subprocess.run([str(path),"--version"],capture_output=True,text=True,
                                encoding="utf-8",errors="replace",timeout=20)
            version=(info.stdout+"\n"+info.stderr).strip()
            if info.returncode:
                diagnostics.append(f"{path}: --version exit {info.returncode}")
                continue
            if "headless" in version.lower():
                diagnostics.append(f"{path}: HEADLESS BINARY ONLY, graphical screenshots unavailable")
                continue
            match=re.search(r"Version:\s*(\d+)\.(\d+)\.(\d+)",version)
            if not match or tuple(map(int,match.groups()))[:2] != (2,1):
                diagnostics.append(f"{path}: expected graphical Factorio 2.1, got {version[:150]}")
                continue
            data=path.parents[2]/"data"/"base"/"info.json"
            if not data.is_file():
                diagnostics.append(f"{path}: missing Factorio base data at {data}")
                continue
            return path, version
        except Exception as exc:
            diagnostics.append(f"{path}: {exc}")
    raise RuntimeError(
        "NO VERIFIED GRAPHICAL FACTORIO 2.1 CLIENT on this Windows runner. "
        "Set FACTORIO_GUI_EXE to the installed full Factorio.exe. "
        "Checked standard Steam, standalone, and PATH locations. "
        "Diagnostics: "+ "; ".join(diagnostics[-12:]))

def stage_client_profile(exe: Path, temp: Path) -> tuple[Path, Path, list[str]]:
    if temp.exists() and any(temp.iterdir()):
        raise FileExistsError(f"Refuse to mix GUI evidence with old run: {temp}")
    temp.mkdir(parents=True, exist_ok=True)
    mods=temp/"mods"
    mods.mkdir()
    atlas=MOD/"graphics/entity/atmospheric-water-condenser-v22c"
    manifest_file=atlas/"atlas_manifest.json"
    lua=MOD/"prototypes/generated_graphics/atmospheric-water-condenser-v22c.lua"
    source_proof=APPROVED/"Condenser_V22C_Four_Way_Integration_Proof.png"
    if not (manifest_file.is_file() and lua.is_file() and source_proof.is_file()):
        raise RuntimeError("Checked-out approved V22C native assets/Lua/proof are incomplete")
    manifest=json.loads(manifest_file.read_text(encoding="utf-8"))
    if (manifest.get("source_sha256")!=SOURCE_SHA or
        manifest.get("actual_factorio_animation_frames")!=32 or
        manifest.get("cycle_seconds")!=12 or
        manifest.get("nominal_collision_footprint_tiles")!=[2,2]):
        raise RuntimeError("Incorrect approved V22C source/atlas animation contract")
    expected={}
    for heading in ("north","east_native","south","west_native"):
        for quality in ("hr","sd"):
            part=manifest["files"][heading][quality]
            for item in (*part["activity_slices"],part["idle_repeated_slice"]):
                if item["name"] in expected:
                    raise RuntimeError("Duplicate asset in approved atlas manifest")
                expected[item["name"]]=item
    icon=manifest["icon"]
    expected[icon["name"]]=icon
    if len(expected)!=41:
        raise RuntimeError("Wrong authored V22C PNG count")
    for name,item in expected.items():
        file=atlas/name
        if (not file.is_file() or file.stat().st_size!=item["size_bytes"]
            or digest(file)!=item["sha256"]):
            raise RuntimeError("Missing/mutated genuine Cycles V22C sprite: "+name)
    if not (MOD/"info.json").is_file():
        raise RuntimeError("Missing actual Tech Priests mod metadata")
    mod_info=json.loads((MOD/"info.json").read_text(encoding="utf-8"))
    if mod_info.get("name")!="tech-priests" or mod_info.get("factorio_version")!="2.1":
        raise RuntimeError("Wrong Factorio mod source")
    shutil.copytree(MOD,mods/"tech-priests")
    addon=mods/"tp-condenser-v22c-visual_0.0.1"
    addon.mkdir()
    (addon/"info.json").write_text(json.dumps({
        "name":"tp-condenser-v22c-visual","version":"0.0.1",
        "title":"Condenser V22C genuine GUI capture",
        "author":"Tech Priests CI","factorio_version":"2.1",
        "dependencies":["base >= 2.1.24","tech-priests"]
    },indent=2)+"\n",encoding="utf-8")
    shutil.copy2(HERE/"visual_client_control.lua",addon/"control.lua")
    scenario=addon/"scenarios/condenser-capture"
    scenario.mkdir(parents=True)
    (scenario/"control.lua").write_text(
        "-- Visual fixture is staged by tp-condenser-v22c-visual/control.lua.\n",
        encoding="utf-8")
    (scenario/"description.json").write_text(json.dumps({
        "name":"Tech Priests condenser V22C four-way native in-game render proof"
    })+"\n",encoding="utf-8")
    installed=exe.parents[2]/"data"
    official=("base","elevated-rails","quality","recycler","space-age")
    enabled=[{"name":n,"enabled":(installed/n/"info.json").is_file()} for n in official]
    if not enabled[0]["enabled"]:
        raise RuntimeError("Missing installed Factorio base files")
    enabled += [{"name":"tech-priests","enabled":True},
                {"name":"tp-condenser-v22c-visual","enabled":True}]
    (mods/"mod-list.json").write_text(json.dumps({"mods":enabled},indent=2)+"\n",
                                      encoding="utf-8")
    userdata=temp/"user-data"
    userdata.mkdir()
    config=temp/"config.ini"
    config.write_text("[path]\nread-data="+str(installed)+
                      "\nwrite-data="+str(userdata)+"\n",encoding="utf-8")
    # Isolated Steam development launch prevents an app restart from discarding
    # the unique --config/--load-scenario arguments. Never alter Steam files.
    (temp/"steam_appid.txt").write_text("427520",encoding="ascii")
    command=[str(exe),"--config",str(config),"--mod-directory",str(mods),
             "--disable-migration-window",
             "--load-scenario","tp-condenser-v22c-visual/condenser-capture"]
    return userdata,config,command

def shot_name(direction: str, state: str, zoom: str) -> str:
    return f"{direction}-{state}-{zoom}.png"

def validate_png(path: Path):
    with path.open("rb") as f:
        assert f.read(8)==PNG_SIGNATURE,(path,"bad PNG signature")
    with Image.open(path) as im:
        im.verify()
    with Image.open(path) as im:
        assert im.size == (1152,864), (path,im.size)
        assert im.mode in ("RGB","RGBA"),(path,im.mode)
        small=im.convert("RGB").resize((100,75))
        assert small.getcolors(256) is None,(path,"screenshot almost entirely blank")
    assert path.stat().st_size>15_000,(path,path.stat().st_size)

def crop_capture(path: Path, size=(480,360)) -> Image.Image:
    with Image.open(path) as image:
        pic=image.convert("RGB")
    w,h=pic.size
    # Centered screenshot, no artificial recoloring or geometry generation.
    crop=pic.crop((w//2-430,h//2-320,w//2+430,h//2+320))
    return crop.resize(size,Image.Resampling.LANCZOS)

def make_contact(out: Path, metadata: dict):
    """Compose ONLY received native client PNGs plus labeled Blender proof."""
    bg=(25,29,33)
    font=ImageFont.load_default()
    poster=Image.new("RGB",(2020,1710),bg)
    draw=ImageDraw.Draw(poster)
    draw.text((20,12),"CONDENSER V22C | REAL FACTORIO 2.1 IN-GAME CLIENT | CONNECTED OUTPUT PIPES",
              fill=(240,242,232),font=font)
    draw.text((20,32),"16 genuine PNGs: 4 facings x idle/working x 100%/close zoom",
              fill=(180,193,200),font=font)
    for i,d in enumerate(DIRECTIONS):
        x=18+502*i
        draw.text((x+5,55),d.upper(),fill=(240,242,232),font=font)
        for j,(state,zoom) in enumerate((st,z) for st in STATES for z in ZOOMS):
            y=80+402*j
            img=crop_capture(out/shot_name(d,state,zoom))
            poster.paste(img,(x,y))
            draw.text((x+5,y+367),
                f"{state.upper()} | {zoom.upper()} | native game screenshot",
                fill=(234,233,225),font=font)
    draw.text((20,1684),
        "Source-locked original meshes; review pipe flange alignment and piston/mist visibility at 100% zoom.",
        fill=(190,198,200),font=font)
    poster.save(out/"condenser-v22c-real-game-four-directions.png",optimize=True)
    # This is a source-versus-client illustration with clearly separated
    # authentic images, NOT a pixel-difference overlay or synthetic screenshot.
    comparison=Image.new("RGB",(2020,1220),bg)
    d2=ImageDraw.Draw(comparison)
    d2.text((20,12),"TOP: actual graphical game close captures | BOTTOM: approved real Blender Cycles proof",
            fill=(239,238,228),font=font)
    for i,d in enumerate(DIRECTIONS):
        x=18+502*i
        d2.text((x+5,40),d.upper()+" | GAME WORKING, PIPE ATTACHED",fill=(239,238,228),font=font)
        comparison.paste(crop_capture(out/shot_name(d,"working","close")),(x,62))
    with Image.open(APPROVED/"Condenser_V22C_Four_Way_Integration_Proof.png") as im:
        native=im.convert("RGB")
        if native.width>1930:
            native.thumbnail((1930,720),Image.Resampling.LANCZOS)
        comparison.paste(native,((2020-native.width)//2,495))
    d2.text((20,1190),"Different camera/pixel grids. Images must be reviewed separately; no fake in-game pixels.",
            fill=(190,198,200),font=font)
    comparison.save(out/"client-vs-approved-v22c-blender.png",optimize=True)

def capture(exe: Path,version: str,out: Path,temp: Path,max_seconds: int):
    userdata,config,cmd=stage_client_profile(exe,temp)
    target=userdata/"script-output"/"condenser-v22c"
    names=[shot_name(d,st,z) for st in STATES for d in DIRECTIONS for z in ZOOMS]
    log=temp/"graphical-factorio.log"
    out.mkdir(parents=True,exist_ok=False)
    print("FACTORIO_V22C_GRAPHICAL_BINARY",exe,flush=True)
    print("FACTORIO_V22C_VERSION",version.splitlines()[0],flush=True)
    print("FACTORIO_V22C_SCREENSHOT_SESSION_START",flush=True)
    with log.open("w",encoding="utf-8",errors="replace") as stream:
        proc=subprocess.Popen(cmd,stdout=stream,stderr=subprocess.STDOUT,cwd=str(temp))
        try:
            t0=time.monotonic()
            while time.monotonic()-t0<max_seconds:
                done=all((target/name).is_file()
                         and (target/name).stat().st_size>15_000 for name in names)
                if done:
                    time.sleep(2)
                    break
                stream.flush()
                current=log.read_text(encoding="utf-8",errors="replace")
                if any(marker in current for marker in (
                    "DXGI_ERROR_NOT_CURRENTLY_AVAILABLE",
                    "Failed to enumerate adapter output",
                    "Failed to get SDL_DXGIGetOutputInfo",
                )):
                    raise RuntimeError(
                        "GRAPHICS_SESSION_UNAVAILABLE: genuine Factorio D3D11 output "
                        "cannot initialize here; use interactive desktop, not Session 0.")
                rc=proc.poll()
                if rc is not None:
                    if "Steam requires game restart" in current:
                        raise RuntimeError("Steam redirected the isolated test client.")
                    raise RuntimeError(f"Real GUI client exited before 16 frames: exit={rc}; tail={current[-1700:]}")
                time.sleep(2)
            else:
                raise TimeoutError(f"Only {sum((target/x).is_file() for x in names)}/16 real PNGs after bounded graphical run")
            native_log=log.read_text(encoding="utf-8",errors="replace")
            if "TP_CONDENSER_V22C_GUI NATIVE_WORLD_PASS" not in native_log:
                raise RuntimeError("No genuine placed-machine / pipe success in real game log")
            if "TP_CONDENSER_V22C_GUI SCREENSHOT_QUEUE_COMPLETE count=16" not in native_log:
                raise RuntimeError("Native screenshot sequence did not finish")
            for name in names:
                candidate=target/name
                validate_png(candidate)
                shutil.copy2(candidate,out/name)
                if digest(candidate)!=digest(out/name):
                    raise RuntimeError("Native PNG changed during copy: "+name)
            shutil.copy2(log,out/"factorio-gui-client.log")
        finally:
            if proc.poll() is None:
                proc.terminate()  # ONLY the isolated child launched by this script
                try: proc.wait(timeout=12)
                except subprocess.TimeoutExpired:
                    proc.kill();proc.wait(timeout=5)
    hashes={name:digest(out/name) for name in names}
    if len(hashes)!=16 or len(set(hashes.values()))!=16:
        raise RuntimeError("Insufficient independent native game captures")
    info={"schema":"tech-priests.condenser-v22c.real-factorio-client.v1",
          "passed":True,"factorio_full_client":True,"factorio_headless":False,
          "client_executable":str(exe),"client_version":version.splitlines()[0],
          "target_prototype":"tech-priests-atmospheric-water-condenser",
          "machines_placed":8,"native_connected_pipes":8,"fueled_active_machines":4,
          "directions":list(DIRECTIONS),"states":list(STATES),
          "zooms":{"normal":1.0,"close":2.7},
          "screen_capture_count":len(hashes),"screenshots_sha256":hashes,
          "original_blender_source_sha256":SOURCE_SHA,
          "visual_alignment_human_approved":False}
    make_contact(out,info)
    info["contact_sha256"]=digest(out/"condenser-v22c-real-game-four-directions.png")
    info["blender_comparison_sha256"]=digest(out/"client-vs-approved-v22c-blender.png")
    (out/"client-capture-qa.json").write_text(json.dumps(info,indent=2)+"\n",encoding="utf-8")
    print("TP_CONDENSER_V22C_REAL_GAME_SCREENSHOT_PASS captures=16 machines=8 pipes=8",
          flush=True)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--working",type=Path,required=True)
    parser.add_argument("--client")
    parser.add_argument("--max-seconds",type=int,default=360)
    a=parser.parse_args()
    out=a.output.resolve();temp=a.working.resolve()
    if out.exists():
        raise FileExistsError("Do not overwrite existing in-game screenshots: "+str(out))
    try:
        require_interactive_desktop()
        exe,version=find_client(a.client)
        capture(exe,version,out,temp,a.max_seconds)
    except Exception as err:
        out.mkdir(parents=True,exist_ok=True)
        log=temp/"graphical-factorio.log"
        detail={"passed":False,"reason":str(err),"graphical_client_required":True,
                "no_fake_screenshots":True,"traceback":traceback.format_exc()}
        (out/"client-capture-error.json").write_text(json.dumps(detail,indent=2)+"\n")
        if log.exists():shutil.copy2(log,out/"factorio-gui-client-failure.log")
        print("TP_CONDENSER_V22C_GRAPHICAL_CLIENT_BLOCKED",str(err),flush=True)
        raise

if __name__=="__main__":main()
