-- Tech Priests - sound prototypes.
-- Registers a reusable movement sound so runtime script can play footsteps for unit-based Tech-Priests.

require("sound-util")

data:extend({
  {
    type = "sound",
    name = "tech-priest-metal-footstep",
    variations = sound_variations("__core__/sound/walking/transport-belt", 9, 0.28),
    category = "game-effect",
    priority = 96,
    aggregation = {
      max_count = 6,
      remove = true,
      count_already_playing = true
    }
  }
})


-- 0.1.530 Tech-Priest voice bark prototypes.
-- Uploaded MP3 clips are converted to OGG at packaging time because Factorio sound definitions load OGG/WAV assets.
local tech_priests_voice_0530 = {}
local function add_voice(name, file, volume, speed)
  tech_priests_voice_0530[#tech_priests_voice_0530 + 1] = {
    type = "sound",
    name = name,
    filename = "__tech-priests__/sound/voice/0530/" .. file,
    category = "game-effect",
    priority = 72,
    volume = volume or 0.55,
    speed = speed or 1.0,
    aggregation = {
      max_count = 4,
      remove = true,
      count_already_playing = true
    }
  }
end

for i = 1, 12 do
  local file = string.format("blahblah_%02d.ogg", i)
  local base = string.format("tech-priests-voice-blahblah-%02d", i)
  add_voice(base, file, 0.52, 1.00)
  add_voice(base .. "-slow", file, 0.54, 0.92)
  add_voice(base .. "-fast", file, 0.50, 1.08)
end
add_voice("tech-priests-voice-blahblah-tech", "blahblahtech.ogg", 0.58, 1.00)
add_voice("tech-priests-voice-blahblah-tech-slow", "blahblahtech.ogg", 0.60, 0.94)
add_voice("tech-priests-voice-blahblah-tech-fast", "blahblahtech.ogg", 0.55, 1.06)

data:extend(tech_priests_voice_0530)


-- 0.1.531 Operational/mechanical sound prototypes.
-- These are reporter assets only. Runtime hooks must route through the sound
-- manager or the operational sound module so audio cues do not become hidden
-- behavior controllers.
local tech_priests_operation_0531 = {}
local function add_operation_sound(name, file, volume, speed, max_count)
  tech_priests_operation_0531[#tech_priests_operation_0531 + 1] = {
    type = "sound",
    name = name,
    filename = "__tech-priests__/sound/operation/0531/" .. file,
    category = "game-effect",
    priority = 70,
    volume = volume or 0.45,
    speed = speed or 1.0,
    aggregation = {
      max_count = max_count or 4,
      remove = true,
      count_already_playing = true
    }
  }
end

add_operation_sound("tech-priests-machine-running-0531", "machine_running.ogg", 0.38, 1.00, 5)
add_operation_sound("tech-priests-machine-start-0531", "machine_start.ogg", 0.50, 1.00, 4)
add_operation_sound("tech-priests-machine-wind-down-0531", "machine_wind_down.ogg", 0.45, 1.00, 4)
add_operation_sound("tech-priests-cathonk-0531", "cathonk.ogg", 0.46, 1.00, 6)
add_operation_sound("tech-priests-clak-0531", "clak.ogg", 0.42, 1.00, 6)
add_operation_sound("tech-priests-clanking-keys-0531", "clanking_keys.ogg", 0.36, 1.00, 3)
add_operation_sound("tech-priests-clicker-button-0531", "clicker_button.ogg", 0.38, 1.00, 6)
add_operation_sound("tech-priests-gas-mask-breathing-0531", "gas_mask_breathing.ogg", 0.32, 1.00, 3)
add_operation_sound("tech-priests-snap-0531", "snap.ogg", 0.38, 1.00, 6)
add_operation_sound("tech-priests-typing-sounds-0531", "typing_sounds.ogg", 0.32, 1.00, 3)

data:extend(tech_priests_operation_0531)


-- 0.1.533 Functional placeholder audio prototypes.
-- These are temporary one-shot OGG cues from docs/AUDIO_MANIFEST.md.
-- Runtime playback remains reporter-only through sound_manager_0475 and placeholder_audio_0533.
local tech_priests_placeholder_audio_0533 = {}
local function add_placeholder_audio_0533(file, volume, max_count)
  local base = file:gsub("%.ogg$", "")
  tech_priests_placeholder_audio_0533[#tech_priests_placeholder_audio_0533 + 1] = {
    type = "sound",
    name = "tech-priests-" .. base:gsub("_", "-"),
    filename = "__tech-priests__/sound/tech-priests/" .. file,
    category = "game-effect",
    priority = 74,
    volume = volume or 0.45,
    aggregation = {
      max_count = max_count or 4,
      remove = true,
      count_already_playing = true
    }
  }
end
add_placeholder_audio_0533("tp_gui_button_press_01.ogg", 0.25, 8)
add_placeholder_audio_0533("tp_gui_button_press_02.ogg", 0.25, 8)
add_placeholder_audio_0533("tp_gui_panel_close_01.ogg", 0.30, 4)
add_placeholder_audio_0533("tp_gui_panel_open_01.ogg", 0.30, 4)
add_placeholder_audio_0533("tp_gui_portrait_select_01.ogg", 0.28, 4)
add_placeholder_audio_0533("tp_gui_tab_change_01.ogg", 0.26, 4)
add_placeholder_audio_0533("tp_machine_detritus_clog_01.ogg", 0.45, 3)
add_placeholder_audio_0533("tp_machine_detritus_clog_02.ogg", 0.45, 3)
add_placeholder_audio_0533("tp_machine_low_sanctity_warning_01.ogg", 0.44, 3)
add_placeholder_audio_0533("tp_machine_low_sanctity_warning_02.ogg", 0.44, 3)
add_placeholder_audio_0533("tp_machine_low_sanctity_warning_03.ogg", 0.44, 3)
add_placeholder_audio_0533("tp_priest_emergency_01.ogg", 0.50, 3)
add_placeholder_audio_0533("tp_priest_emergency_02.ogg", 0.50, 3)
add_placeholder_audio_0533("tp_priest_repair_01.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_repair_02.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_repair_03.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_sanctify_oil_01.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_sanctify_oil_02.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_sanctify_oil_03.ogg", 0.42, 4)
add_placeholder_audio_0533("tp_priest_scan_01.ogg", 0.24, 4)
add_placeholder_audio_0533("tp_priest_scan_02.ogg", 0.24, 4)
add_placeholder_audio_0533("tp_priest_scan_03.ogg", 0.24, 4)
add_placeholder_audio_0533("tp_station_link_broken_01.ogg", 0.44, 3)
add_placeholder_audio_0533("tp_station_link_broken_02.ogg", 0.44, 3)
add_placeholder_audio_0533("tp_station_link_established_01.ogg", 0.42, 3)
add_placeholder_audio_0533("tp_station_link_established_02.ogg", 0.42, 3)
data:extend(tech_priests_placeholder_audio_0533)
