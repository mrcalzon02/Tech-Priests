-- Regression 1483: readable Auspex ledger should not overflow typical screens.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local L=require("scripts.core.catalog_gui_layout_1483")
local scenarios = {
  {width=1920,height=1080,scale=1},
  {width=1366,height=768,scale=1},
  {width=1280,height=720,scale=1.5},
  {width=960,height=540,scale=1.5},
  {width=800,height=600,scale=1.25},
  {width=800,height=600,scale=2},
  {width=640,height=480,scale=1},
  {width=720,height=480,scale=1},
}
for _,spec in ipairs(scenarios) do
  local player={valid=true,display_scale=spec.scale,display_resolution={width=spec.width,height=spec.height}}
  local got=L.for_player(player)
  assert(got.frame_width>0 and got.frame_height>0 and got.details_width>0 and got.details_height>0)
  assert(got.frame_width <= got.logical_width and got.frame_height <= got.logical_height,
    "frame exceeds logical display dimensions")
  assert(got.details_width <= got.frame_width and got.details_height <= got.frame_height,
    "scrollable details exceed frame bounds")
  assert(got.position.x>=0 and got.position.y>=0,
    "negative window position")
  assert(got.position.x+got.frame_width <= got.logical_width
    and got.position.y+got.frame_height <= got.logical_height,
    "fixed-position GUI spills off the screen")
end
local wide=L.for_player({valid=true,display_resolution={width=1920,height=1080},display_scale=1})
assert(wide.position.x==24 and wide.position.y==96 and wide.details_height==500,
  "wide desktop layout unexpectedly changed")
local highdpi=L.for_player({valid=true,display_resolution={width=1280,height=720},display_scale=2})
assert(highdpi.logical_width==640 and highdpi.logical_height==360,
  "display scaling ignored")
local missing=L.for_player(nil)
assert(missing.frame_width==440 and missing.frame_height==720,
  "missing display metadata should use safe desktop fallback")
local broken=L.for_player({valid=true,display_resolution={width=0,height=0},display_scale=0})
assert(broken.frame_width>0 and broken.frame_height>0,
  "bogus display values produced nonpositive dimensions")
local labels={}
local parent={add=function(spec)
  local label={valid=true,style={},caption=spec.caption,type=spec.type}
  labels[#labels+1]=label
  return label
end}
local label=L.add_label(parent,"Long diagnostic text that must wrap",128)
assert(label.type=="label" and label.caption:find("Long diagnostic"),
  "responsive helper changed label contents")
assert(label.style.single_line==false and label.style.maximal_width==128,
  "long diagnostic label cannot wrap inside fixed width")
assert(L.add_label(parent,"x",-4).style.maximal_width==1,
  "invalid width was not bounded")
print("[catalog-gui-layout-1483] PASS: resolution, scaling, frame bounds and wrapping")
