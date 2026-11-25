"""Measure Factorio's native armed-walking atlas selection with encoded pixels.

The diagnostic mod is independent of Tech-Priests. Each atlas frame encodes its
source row and frame number; red/blue corners expose horizontal mirroring.
Only native engine screenshots are decoded. No artwork is inferred or mocked.
"""
from pathlib import Path
import argparse
import json
import os
import struct
import subprocess
import time
import zlib

CELL = 64
FRAMES = 22
MOD_NAME = "tp-engineer-pose-probe"


def png_write(path, width, height, pixels):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xffffffff)
    rows = b"".join(b"\0" + pixels[y * width * 3:(y + 1) * width * 3] for y in range(height))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                     + chunk(b"IDAT", zlib.compress(rows, 9)) + chunk(b"IEND", b""))


def make_atlas(path, directions):
    width, height = CELL * FRAMES, CELL * directions
    pixels = bytearray(width * height * 3)
    def rect(left, top, right, bottom, rgb):
        line = bytes(rgb) * (right - left)
        for y in range(top, bottom):
            begin = (y * width + left) * 3
            pixels[begin:begin + len(line)] = line
    for row in range(directions):
        for frame in range(FRAMES):
            x, y = frame * CELL, row * CELL
            rect(x + 1, y + 1, x + 63, y + 3, (255, 255, 255))
            rect(x + 1, y + 61, x + 63, y + 63, (255, 255, 255))
            rect(x + 4, y + 5, x + 12, y + 13, (255, 0, 0))
            rect(x + 52, y + 5, x + 60, y + 13, (0, 0, 255))
            for bit in range(6):
                if row & (1 << bit): rect(x + 8 + bit * 8, y + 20, x + 16 + bit * 8, y + 28, (255, 255, 255))
                if frame & (1 << bit): rect(x + 8 + bit * 8, y + 36, x + 16 + bit * 8, y + 44, (255, 255, 255))
    png_write(path, width, height, pixels)


def png_read(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n": raise ValueError("Not a PNG: " + str(path))
    offset, compressed = 8, bytearray()
    width = height = channels = None
    while offset < len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        kind, payload = data[offset + 4:offset + 8], data[offset + 8:offset + 8 + size]
        offset += size + 12
        if kind == b"IHDR":
            width, height, depth, colour, _, _, interlace = struct.unpack(">IIBBBBB", payload)
            if depth != 8 or interlace != 0 or colour not in (2, 6): raise ValueError("Expected noninterlaced RGB/RGBA PNG")
            channels = 3 if colour == 2 else 4
        elif kind == b"IDAT": compressed.extend(payload)
        elif kind == b"IEND": break
    raw, result, previous = zlib.decompress(compressed), bytearray(), bytearray(width * channels)
    stride, offset = width * channels, 0
    for _ in range(height):
        filter_type = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride]); offset += stride + 1
        if filter_type == 1:
            for x in range(channels, stride): row[x] = (row[x] + row[x - channels]) & 255
        elif filter_type == 2:
            for x in range(stride): row[x] = (row[x] + previous[x]) & 255
        elif filter_type == 3:
            for x in range(stride): row[x] = (row[x] + ((row[x - channels] if x >= channels else 0) + previous[x]) // 2) & 255
        elif filter_type == 4:
            for x in range(stride):
                left, above = (row[x - channels] if x >= channels else 0), previous[x]
                corner = previous[x - channels] if x >= channels else 0
                estimate = left + above - corner
                a, b, c = abs(estimate - left), abs(estimate - above), abs(estimate - corner)
                predictor = left if a <= b and a <= c else above if b <= c else corner
                row[x] = (row[x] + predictor) & 255
        elif filter_type != 0: raise ValueError("Unsupported PNG filter")
        if channels == 3: result.extend(row)
        else:
            for x in range(0, stride, 4): result.extend(row[x:x + 3])
        previous = row
    return width, height, result


DATA = r'''
local definitions={}
for _,count in ipairs({18,40}) do
 local character=table.deepcopy(data.raw.character.character)
 character.name="tp-engineer-pose-"..count
 character.hidden=true
 character.hidden_in_factoriopedia=true
 character.animations[1].running_with_gun={
  filename="__tp-engineer-pose-probe__/pose-"..count..".png",width=64,height=64,
  frame_count=22,direction_count=count,animation_speed=.6,shift={0,0},scale=1,
  draw_as_glow=true,apply_runtime_tint=false}
 character.animations[1].flipped_shadow_running_with_gun=nil
 definitions[#definitions+1]=character
end
data:extend(definitions)
'''

CONTROL = r'''
local graphical_run=false
local vectors={{0,-1},{1,-1},{1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1}}
local function initialize()
 local surface=game.surfaces[1]
 surface.daytime=0;surface.freeze_daytime=true
 storage.pose_probe={actors={},targets={},snapshots={},done=false}
 for _,count in ipairs({18,40}) do
  local center=count==18 and 0 or 100
  surface.request_to_generate_chunks({center,0},2);surface.force_generate_chunk_requests()
  local tiles={}
  for x=math.floor(center-23),math.ceil(center+23) do
   for y=-23,23 do tiles[#tiles+1]={name="lab-dark-1",position={x,y}} end
  end
  surface.set_tiles(tiles)
  for aim=0,7 do
   for walk=0,7 do
    local origin={x=center-17.5+walk*5,y=-17.5+aim*5}
    local vector=vectors[aim+1]
    local target_position={x=origin.x+vector[1]*2,y=origin.y+vector[2]*2}
    local target=assert(surface.create_entity{name="steel-chest",position=target_position,force=game.forces.enemy})
    local actor=assert(surface.create_entity{name="tp-engineer-pose-"..count,position=origin,force=game.forces.player})
    actor.destructible=false
    actor.get_inventory(defines.inventory.character_guns)[1].set_stack{name="pistol",count=1}
    actor.get_inventory(defines.inventory.character_ammo)[1].set_stack{name="firearm-magazine",count=100}
    actor.selected_gun_index=1
    local record={entity=actor,target=target,target_position=target_position,origin=origin,
      count=count,aim=aim,walk=walk,hits=0}
    storage.pose_probe.actors[#storage.pose_probe.actors+1]=record
    storage.pose_probe.targets[target.unit_number]=record
   end
  end
 end
 log("[TP-ENGINEER-POSE] INIT 128 native characters / 64 aim-walk pairs per atlas")
end
script.on_init(initialize)
script.on_event(defines.events.on_entity_damaged,function(event)
 local state=storage.pose_probe
 local record=state and state.targets[event.entity.unit_number]
 if record and event.cause==record.entity then record.hits=record.hits+1 end
end)
local function snapshot(label)
 local result={tick=game.tick,actors={}}
 for _,record in ipairs(storage.pose_probe.actors) do
  local actor=record.entity
  assert(actor.valid and actor.walking_state.walking,"Native diagnostic character is not walking")
  assert(actor.shooting_state.state~=defines.shooting.not_shooting,"Native diagnostic character is not shooting")
  assert(record.hits>0,"Native diagnostic character has not damaged its selected target")
  local ammo=actor.get_inventory(defines.inventory.character_ammo)[1]
  result.actors[#result.actors+1]={count=record.count,aim=record.aim,walk=record.walk,
    position=actor.position,orientation=actor.orientation,direction=actor.direction,
    walking_direction=actor.walking_state.direction,speed=actor.character_running_speed,
    native_hits=record.hits,magazines=ammo.count,remaining_ammo=ammo.ammo}
 end
 storage.pose_probe.snapshots[label]=result
 if graphical_run then
  for _,count in ipairs({18,40}) do
   game.take_screenshot{surface=game.surfaces[1],position={count==18 and 0 or 100,0},
    resolution={1280,1280},zoom=1,path="engineer-pose/pose-"..count.."-"..label..".png",
    show_gui=false,daytime=0,force_render=true,anti_alias=false}
  end
 end
 log("[TP-ENGINEER-POSE] SNAPSHOT "..label.." tick="..game.tick)
end
script.on_event(defines.events.on_tick,function(event)
 local state=storage.pose_probe
 if not state or state.done then return end
 for _,record in ipairs(state.actors) do
  local actor=record.entity
  assert(actor.valid and record.target.valid,"Native diagnostic actor/target disappeared")
  actor.teleport(record.origin)
  record.target.health=record.target.max_health
  actor.walking_state={walking=true,direction=record.walk*2}
  actor.selected=record.target
  actor.shooting_state={state=defines.shooting.shooting_selected,position=record.target_position}
 end
 if event.tick==90 then snapshot("a") end
 if event.tick==102 then
  snapshot("b")
  state.done=true
  helpers.write_file("engineer-pose/snapshots.json",helpers.table_to_json{passed=true,graphical=graphical_run,snapshots=state.snapshots},false)
  log("[TP-ENGINEER-POSE] PASS native walking/shooting states; graphical="..tostring(graphical_run))
 end
end)
'''


def pixel(image, x, y):
    width, height, data = image
    if x < 0 or y < 0 or x >= width or y >= height: return (0, 0, 0)
    begin = (y * width + x) * 3
    return tuple(data[begin:begin + 3])


def decode_marker(image, cx, cy):
    def red(c): return c[0] > 80 and c[0] > c[1] * 2 and c[0] > c[2] * 2
    def blue(c): return c[2] > 80 and c[2] > c[0] * 2 and c[2] > c[1] * 2
    candidates = []
    for dy in range(-10, 11):
        for dx in range(-10, 11):
            left, top = round(cx) - 32 + dx, round(cy) - 32 + dy
            a, b = pixel(image, left + 8, top + 9), pixel(image, left + 56, top + 9)
            if red(a) and blue(b): mirrored = False
            elif blue(a) and red(b): mirrored = True
            else: continue
            # Only centers with both full-width white border strips qualify.
            if min(pixel(image, left + 32, top + 1)) < 180 or min(pixel(image, left + 32, top + 62)) < 180: continue
            def value(y):
                result = 0
                for bit in range(6):
                    x = 12 + bit * 8
                    if mirrored: x = 63 - x
                    if min(pixel(image, left + x, top + y)) > 180: result |= 1 << bit
                return result
            candidates.append((dx * dx + dy * dy, {"row": value(24), "frame": value(40), "mirrored": mirrored, "left": left, "top": top}))
    if not candidates: raise ValueError(f"Encoded native animation absent near ({cx:.2f},{cy:.2f})")
    return min(candidates, key=lambda item: item[0])[1]


def decode(out, native):
    shots = json.loads((native / "snapshots.json").read_text())
    images = {(count, label): png_read(native / f"pose-{count}-{label}.png") for count in (18, 40) for label in ("a", "b")}
    records, errors = [], []
    proof = bytearray(1024 * 1024 * 3)
    for index, actor in enumerate(shots["snapshots"]["a"]["actors"]):
        count, aim, walk = actor["count"], actor["aim"], actor["walk"]
        samples = []
        for label in ("a", "b"):
            position = shots["snapshots"][label]["actors"][index]["position"]
            center = 0 if count == 18 else 100
            image = images[count, label]
            cx, cy = image[0] / 2 + (position["x"] - center) * 32, image[1] / 2 + position["y"] * 32
            try:
                sample = decode_marker(image, cx, cy)
                if sample["row"] >= count or sample["frame"] >= FRAMES: raise ValueError("Decoded row/frame outside atlas")
                samples.append(sample)
                dest_x, dest_y = ((0 if label == "a" else 8) + walk) * CELL, ((0 if count == 18 else 8) + aim) * CELL
                for y in range(CELL):
                    for x in range(CELL):
                        begin = ((dest_y + y) * 1024 + dest_x + x) * 3
                        proof[begin:begin + 3] = bytes(pixel(image, sample["left"] + x, sample["top"] + y))
            except ValueError as exc: errors.append({"count": count, "aim": aim, "walk": walk, "snapshot": label, "error": str(exc)})
        if len(samples) == 2:
            first, second = samples
            if first["row"] != second["row"] or first["mirrored"] != second["mirrored"]:
                errors.append({"count": count, "aim": aim, "walk": walk, "error": "Native row/mirroring changed between snapshots"})
            delta = (second["frame"] - first["frame"] + FRAMES // 2) % FRAMES - FRAMES // 2
            if delta == 0: errors.append({"count": count, "aim": aim, "walk": walk, "error": "No measurable native animation advance"})
            records.append({"count": count, "aim": aim, "walk": walk, "row": first["row"],
                            "mirrored": first["mirrored"], "reversed": delta < 0,
                            "frame_a": first["frame"], "frame_b": second["frame"], "frame_delta": delta})
    tables = {}
    for count in (18, 40):
        tables[str(count)] = {field: [[next((record[field] for record in records if record["count"] == count and record["aim"] == aim and record["walk"] == walk), None)
                                     for walk in range(8)] for aim in range(8)] for field in ("row", "mirrored", "reversed")}
    result = {"passed": not errors and len(records) == 128, "measurement": "native encoded atlas screenshots",
              "axes": "tables[atlas][field][aim][walk], zero-based N,NE,E,SE,S,SW,W,NW",
              "snapshot_ticks": [shots["snapshots"][label]["tick"] for label in ("a", "b")],
              "tables": tables, "records": records, "errors": errors}
    (out / "result.json").write_text(json.dumps(result, indent=2))
    png_write(out / "native-row-proof.png", 1024, 1024, proof)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--factorio", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--headless-only", action="store_true")
    parser.add_argument("--decode-only", action="store_true", help="Re-decode existing native screenshots without launching Factorio")
    args = parser.parse_args()
    out, factorio = args.output_root.resolve(), args.factorio.resolve()
    out.mkdir(parents=True, exist_ok=True)
    native = out / "user-data/script-output/engineer-pose"
    if args.decode_only:
        result = decode(out, native); print(json.dumps(result, separators=(",", ":")), flush=True); return 0 if result["passed"] else 1
    mod = out / "mods" / MOD_NAME; mod.mkdir(parents=True, exist_ok=True)
    (mod / "info.json").write_text(json.dumps({"name": MOD_NAME, "title": "Native Engineer pose probe", "author": "Tech-Priests test harness", "version": "0.0.1", "factorio_version": "2.1", "dependencies": ["base >= 2.1.0"]}))
    (mod / "data-final-fixes.lua").write_text(DATA)
    (mod / "control.lua").write_text(CONTROL)
    for count in (18, 40): make_atlas(mod / f"pose-{count}.png", count)
    (out / "mods/mod-list.json").write_text(json.dumps({"mods": [{"name": name, "enabled": name in ("base", MOD_NAME)} for name in ("base", "space-age", "quality", "elevated-rails", "recycler", MOD_NAME)]}))
    user = out / "user-data"; user.mkdir(exist_ok=True)
    config = out / "config.ini"
    config.write_text("[path]\nread-data=" + str(factorio.parents[2] / "data").replace("\\", "/") + "\nwrite-data=" + str(user).replace("\\", "/") + "\n[other]\ncheck-updates=false\n[graphics]\nfull-screen=false\n")
    save = out / "pose-probe.zip"
    common = [str(factorio), "--config", str(config), "--mod-directory", str(out / "mods")]
    for name, options in (("create", ["--create", str(save)]), ("native-states", ["--test-save", str(save), "--test-ticks", "125"])):
        log = out / f"{name}.log"
        with log.open("w") as handle: run = subprocess.run(common + options, stdout=handle, stderr=subprocess.STDOUT, timeout=180)
        print(f"pose probe {name}: exit={run.returncode}", flush=True)
        if run.returncode:
            print(log.read_text(errors="replace")[-8000:]); return 1
    states = json.loads((native / "snapshots.json").read_text())
    if not states.get("passed"): raise RuntimeError("Native pose-state fixture did not pass")
    if args.headless_only:
        (out / "result.json").write_text(json.dumps({"passed": True, "headless_only": True, "mapping_verified": False, "native_actors": 128}))
        print("PASS native pose-state fixture; graphical mapping remains unmeasured", flush=True); return 0
    (native / "snapshots.json").unlink()
    for path in native.glob("pose-*.png"): path.unlink()
    (mod / "control.lua").write_text(CONTROL.replace("local graphical_run=false", "local graphical_run=true"))
    startup = None
    if os.name == "nt":
        startup = subprocess.STARTUPINFO(); startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW; startup.wShowWindow = 1
    environment = os.environ.copy(); environment["SteamAppId"] = "427520"; environment["SteamGameId"] = "427520"
    log = out / "graphical.log"
    with log.open("w") as handle:
        process = subprocess.Popen(common + ["--load-game", str(save), "--disable-audio"], stdout=handle, stderr=subprocess.STDOUT, startupinfo=startup, env=environment)
        try:
            deadline = time.monotonic() + 150
            while time.monotonic() < deadline and process.poll() is None:
                if (native / "snapshots.json").exists() and all((native / f"pose-{count}-{label}.png").exists() for count in (18, 40) for label in ("a", "b")):
                    time.sleep(1); break
                time.sleep(.25)
        finally:
            if process.poll() is None: process.terminate(); process.wait(timeout=15)
    if not (native / "snapshots.json").exists() or not all((native / f"pose-{count}-{label}.png").exists() for count in (18, 40) for label in ("a", "b")):
        print(log.read_text(errors="replace")[-8000:]); return 1
    result = decode(out, native)
    print("NATIVE_ENGINEER_POSE_RESULT " + json.dumps(result, separators=(",", ":")), flush=True)
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
