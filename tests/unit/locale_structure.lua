-- Native startup once failed because new locale lines were inserted INTO a
-- comment containing [technology-description]. Parse every line and require
-- actual single section headers and unique scoped key identities.
local path="tech-priests_src/locale/en/base.cfg"
local f=assert(io.open(path,"rb"),"could not open canonical locale")
local seen,section={},nil
local sectionCounts={}
for line in f:lines() do
  if line:match("^%s*$") or line:match("^%s*;") then
    -- comments and whitespace
  else
    local h=line:match("^%[([%w_.%-]+)%]$")
    if h then
      assert(not seen[h],"duplicate locale section "..h)
      seen[h]={};section=h;sectionCounts[h]=0
    else
      local key=line:match("^([%w_.%-]+)=")
      assert(key,"malformed locale line: "..line:sub(1,120))
      assert(section,"unscoped locale key "..key)
      assert(not seen[section][key],"duplicate locale key "..section.." / "..key)
      seen[section][key]=true
      sectionCounts[section]=sectionCounts[section]+1
    end
  end
end
f:close()
for _,kind in ipairs({"order","chaos"}) do
  for tier=1,2 do
    local item="tech-priests-"..kind.."-module-"..tier
    local tech="machine-spirit-"..(kind=="order" and "law-order" or "chaos-anarchy").."-"..tier
    for _,sec in ipairs({"item-name","item-description","recipe-name","recipe-description"}) do
      assert(seen[sec] and seen[sec][item],sec.." missing "..item)
    end
    for _,sec in ipairs({"technology-name","technology-description"}) do
      assert(seen[sec] and seen[sec][tech],sec.." missing "..tech)
    end
  end
end
assert(seen["item-name"]["tech-priests-data-spike"] and
  seen["entity-name"]["tech-priests-data-spike-projectile"],
  "original Data Spike names lost their locale identity")
print("[locale-structure] PASS unique sections, scoped keys, bilateral modules and Data Spike")
