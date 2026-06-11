-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 1-54
-- scripts/core/station_work_inventory.lua
-- Tech Priests 0.1.358 Station-Bound Operational Catechism Audit and GUI panel.
--
-- Purpose:
--   Enforce the current master-plan doctrine in one place:
--     Cogitator Station = inventory, memory, command authority, task owner.
--     Tech-Priest = mobile actuator and temporary carrier only.
--
-- This pass is intentionally conservative.  It does not rewrite every executor;
-- it creates the canonical inspection/API surface and a station side-panel so we
-- can see when older behavior paths still drift away from the doctrine.

local M = {}
local DoctrineMap = require("scripts.core.doctrine_map")
local PriestIdentity0525 = require("scripts.core.priest_identity_background_0525")

M.version = "0.1.541"
M.gui_name = "tech_priests_station_workstate_0358"
M.max_rows = 10
M.default_radius = 36
M.boot_refresh_ticks = 15
M.boot_stage_ticks = 360
M.boot_hold_ticks = 180
M.boot_speed_setting_name = "tech-priests-cogitator-bios-boot-speed-percent"

M.font_terminal = "default"
M.font_header = "default-bold"
M.font_glyph = "default"
M.font_small_glyph = "default"
M.font_necron_glyph = "default"
M.terminal_green_tag = "green"
M.label_wrap_width = 620
M.resource_wrap_width = 660
M.relationship_wrap_width = 680
M.dim_color_tag = "0.45,0.45,0.45"

local station_rank
local station_label
local priest_label
local add_label
local add_summary_table_0521 -- forward for structured UI plaques


local EMERGENCY_ENTITIES = {
  ["tech-priests-emergency-miner"] = "miner",
  ["tech-priests-atmospheric-water-condenser"] = "condenser",
  ["tech-priests-emergency-boiler"] = "boiler",
  ["tech-priests-emergency-steam-engine"] = "steam-engine",
  ["tech-priests-emergency-smelter"] = "smelter",
  ["tech-priests-emergency-assembler"] = "assembler",
  ["tech-priests-emergency-laboratorium"] = "lab",
  ["tech-priests-emergency-power-grid"] = "power-grid",
}

