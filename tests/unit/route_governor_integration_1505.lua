-- Integration: 0594 route wrapper retains deterministic throttling, exemption
-- for 0598-admitted routes and live diagnostic toggle semantics.
package.path='./tech-priests_src/?.lua;./tech-priests_src/?/init.lua;'..package.path
storage={tech_priests={pairs_by_station={}}}
for i=1,90 do
 storage.tech_priests.pairs_by_station[i]={station={valid=true},priest={valid=true}}
end
game={tick=0}
settings={global={['tech-priests-enable-emergency-diagnostics']={value=false},
 ['tech-priests-enable-full-priority-diagnostics']={value=false}}}
local counts={}
local entries={}
local function entry(id,category,owner,budgeted)
 local x={id=id,tick=5,category=category,owner=owner,tech_priests_0598_budgeted=budgeted,
  handler=function(event)counts[id]=(counts[id]or 0)+1;return true end}
 entries[id]=x
 return x
end
local routes={entry('visual','visuals','visual-overlay'),entry('inventory','inventory','storage-writ'),
 entry('diag','diagnostics','pair_dump'),entry('delegated','visuals','sound-manager',true),
 entry('diag-delegated','diagnostics','pair_dump',true),
 entry('unclassified','economy','unknown'),entry('combat','combat','movement-dispatcher')}
local R={nth_tick_routes={['5']=routes}, on_nth_tick=function(n,fn,opts)
 assert(n==1800 and opts.owner=='efficiency_economy_0594');return true end}
_G.TechPriestsRuntimeEventRegistry=R
local original_critical=entries.combat.handler
local M=require('scripts.core.efficiency_economy_0594')
assert(M.install())
assert(entries.combat.handler==original_critical,'combat/movement route was wrapped')
for _,id in ipairs({'visual','inventory','diag','delegated','diag-delegated','unclassified'}) do
 assert(entries[id].tech_priests_0594_wrapped==true,'route not wrapped: '..id)
end
assert(M.install() and entries.visual.tech_priests_0594_wrapped,'repeat installation failed')
local first=game.tick
-- Diagnostics OFF must remain suppressed even when 0598 already budgeted it.
for tick=5,295,5 do
 game.tick=tick
 for _,x in ipairs(routes)do x.handler({tick=tick}) end
end
assert((counts.diag or 0)==0 and (counts['diag-delegated']or 0)==0,
 'disabled diagnostics were executed')
assert(counts.delegated==59,'0598-admitted presentation route was throttled twice')
assert(counts.unclassified==59,'unknown critical-compatible route was throttled')
assert(counts.combat==59,'critical combat routing was throttled')
assert((counts.visual or 0)>0 and counts.visual<59,
 'presentation throttling outside heavy-tier bounds')
assert((counts.inventory or 0)>0 and counts.inventory<59,
 'background throttling outside heavy-tier bounds')
-- Diagnostic toggles are read LIVE (not cached across a settings change).
settings.global['tech-priests-enable-emergency-diagnostics'].value=true
game.tick=300
for _,x in ipairs(routes)do x.handler({tick=300}) end
assert((counts['diag-delegated']or 0)==1,
 'diagnostics enable did not take effect on next callback')
assert(counts.delegated==60)
settings.global['tech-priests-enable-emergency-diagnostics'].value=false
game.tick=305
for _,x in ipairs(routes)do x.handler({tick=305}) end
assert((counts['diag-delegated']or 0)==1,
 'diagnostics disable did not take effect on next callback')
local state=storage.tech_priests.efficiency_economy_0594
assert(state.recent_pair_count==90 and state.recent_tier=='heavy')
assert(state.wrapped==6,'critical route was wrapped or double-counted')
assert((state.ran['budgeted-by-0598']or 0)>=60,
 'delegated admission did not report previous gate')
-- A rescan changes current tier, and unbudgeted presentation will speed up.
storage.tech_priests.pairs_by_station={}
for i=1,5 do
 storage.tech_priests.pairs_by_station[i]={station={valid=true},priest={valid=true}}
end
state.next_rescan_tick=0
game.tick=310
entries.visual.handler({tick=310})
assert(state.recent_tier=='quiet' and state.recent_pair_count==5)
assert((state.ran['presentation-quiet']or 0)>=1,
 'quiet-tier presentation callbacks did not fully resume')
print('[route-governor-integration-1505] PASS')
