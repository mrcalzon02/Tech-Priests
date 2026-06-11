-- split source: tech-priests_src/scripts/core/station_work_inventory.lua lines 75-76
local function dist_sq(a,b) local dx=(a.x or 0)-(b.x or 0); local dy=(a.y or 0)-(b.y or 0); return dx*dx+dy*dy end

