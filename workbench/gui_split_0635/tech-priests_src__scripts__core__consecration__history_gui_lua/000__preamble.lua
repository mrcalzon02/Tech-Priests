-- split source: tech-priests_src/scripts/core/consecration/history_gui.lua lines 1-15
-- Tech Priests 0.1.422 consecration history GUI and operation ledger.
-- This module has two jobs:
--   1. Keep a compact operation-by-operation sanctification history per machine.
--   2. Display that history when the machine GUI is opened, so live tests can
--      verify consecration decay, max-cap damage, waste, and backlash behavior.

local M = { name = "scripts.core.consecration.history_gui", version = "0.1.526" }

local FRAME_NAME = "tech_priests_consecration_history_0422"
local CLOSE_NAME = "tech_priests_consecration_history_close_0422"
local REFRESH_NAME = "tech_priests_consecration_history_refresh_0422"
local HISTORY_LIMIT = 80
local GRAPH_WIDTH = 28
local TRAIT_TABLE_WIDTH = 850

