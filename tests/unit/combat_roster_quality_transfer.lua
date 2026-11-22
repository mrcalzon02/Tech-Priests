-- AAI replacement Quality audit must never invent, downgrade or grant items.
package.path="./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;"..package.path
local M=require("scripts.core.combat_quality_contract")
local logs={}
local function report(msg) logs[#logs+1]=msg end
local state={}
local function e(unit,quality)
  return {valid=true,unit_number=unit,quality=quality and {name=quality} or nil}
end
local old,unchanged=e(101,"legendary"),e(102,"legendary")
local same=assert(M.audit_replacement(state,old,unchanged,5,report))
assert(same.equal and state.combat_quality_audit==nil and #logs==0,
  "same-quality AAI replacement created fake warning")
local normal=assert(M.audit_replacement(state,e(103,nil),e(104,"normal"),6,report))
assert(normal.equal,"missing Quality feature must be Normal on both sides")
local drop=assert(M.audit_replacement(state,old,e(105,"normal"),7,report))
assert(not drop.equal and drop.before_quality=="legendary"
  and drop.after_quality=="normal","Legendary-to-Normal loss not detected")
local gain=assert(M.audit_replacement(state,e(106,"rare"),e(107,"legendary"),8,report))
assert(not gain.equal,"unpaid quality gain was not detected")
assert(state.combat_quality_audit.mismatches==2 and #logs==2,
  "AAI Quality counter incorrect")
assert(state.combat_quality_audit.last.old_unit==106
  and state.combat_quality_audit.last.new_unit==107
  and state.combat_quality_audit.last.tick==8,
  "AAI Quality audit did not persist exact identity")
for i=1,103 do
  M.audit_replacement(state,e(200+i,"epic"),e(400+i,"rare"),20+i,report)
end
assert(state.combat_quality_audit.mismatches==105 and #logs==6,
  "quality audit log throttle failed")
assert(M.audit_replacement(state,e(1,"normal"),e(2,"normal"),1,report).equal)
assert(M.replacement_identity({valid=false},e(2,"normal"))==nil,
  "invalid source was reported as quality transfer")
print("[combat-roster-quality-transfer] PASS exact quality preservation audit, bounded diagnostics")
