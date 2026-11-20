-- Regression 1505: classification and tier choice stay behavior-equivalent.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
local C=require('scripts.core.route_classification_1505')
local function old(category,owner,n,diag)
  category=string.lower(tostring(category or ''))
  owner=string.lower(tostring(owner or ''))
  if category=='diagnostics' or owner:find('diagnostics',1,true) or owner:find('pair_dump',1,true) then
    if not diag then return 999999,'diagnostics-off' end
    if n>=80 then return 8,'diagnostics-heavy' end
    return 3,'diagnostics'
  end
  if category=='visuals' or category=='audio' or category=='gui'
    or owner:find('visual',1,true) or owner:find('overhead',1,true)
    or owner:find('sound',1,true) or owner:find('voice',1,true)
    or owner:find('chatter',1,true) then
    if n>=160 then return 8,'presentation-extreme' end
    if n>=80 then return 5,'presentation-heavy' end
    if n>=35 then return 3,'presentation-busy' end
    return 1,'presentation-quiet'
  end
  if category=='inventory' or category=='scheduler' or category=='crafting'
    or owner:find('order_queue',1,true) or owner:find('planning',1,true)
    or owner:find('reserve',1,true) or owner:find('inventory',1,true) then
    if n>=160 then return 3,'background-extreme' end
    if n>=80 then return 2,'background-heavy' end
    return 1,'background-quiet'
  end
  return 1,'critical-or-unknown'
end
local categories={'diagnostics','visuals','audio','gui','inventory','scheduler','crafting','economy','unknown','Diagnostics','VISUALS',''}
local owners={'event_registry','pair_dump','emergency_diagnostics','overhead_text','sound_manager','voice_magos','chatter_random','order_queue_0469','planning_0259','reserve','inventory_0741','unrecognized','PAIR_DUMP','pair_dump_sound'}
local tiers={0,1,34,35,79,80,159,160,240}
local tests=0
for _,cat in ipairs(categories) do
 for _,owner in ipairs(owners) do
  local class=C.classify(cat,owner)
  for _,count in ipairs(tiers) do
   for _,diag in ipairs({false,true}) do
    local want,reason=old(cat,owner,count,diag)
    local actual,why=C.multiplier(class,count,diag)
    assert(actual==want and reason==why,
      ('mismatch %s/%s/%d/%s %d:%s vs %d:%s'):format(cat,owner,count,tostring(diag),want,reason,actual,why))
    tests=tests+1
   end
  end
 end
end
assert(C.classify('gui','pair_dump')=='diagnostics','priority of diagnostic route changed')
assert(C.classify('inventory','sound_manager')=='presentation','priority of visual route changed')
assert(C.classify('economy','safe_worker')=='other')
assert(C.multiplier('other',999,false)==1)
print(('[route-classification-1505] PASS: %d behavior-equivalent tier decisions'):format(tests))
