-- Synthetic Lua only; 0528 custody diagnostics with unchanged state.
package.path='./tech-priests_src/?.lua;'..package.path
local Probe=require('scripts.core.dispatcher_custody_probe_1504')
local N=120000
local function safe(v)
 if v==nil then return 'nil' end
 local ok,s=pcall(tostring,v)
 return ok and s or '?'
end
local function new_pair()
 return {order_queue_0469={current={kind='deliver'}},movement_request_0418={owner='0528'}}
end
local function legacy(pair,pending,tick)
 local prev=pair.machine_return_entry_probe_0510
 local flags={
  '0528-custody='..safe(pending.custody~=nil),
  'pair-0528-custody='..safe(pair.machine_logistics_custody_0528~=nil),
  'direct-custody='..safe(pair.direct_acquisition_custody_0513~=nil),
  'direct-active='..safe(false),
  'defense-task='..safe(pair.defense_task_0259~=nil),
  'combat-target='..safe(nil),
  'machine-valid='..safe(nil),
  'order='..safe(pair.order_queue_0469.current.kind),
  'movement-owner='..safe(pair.movement_request_0418.owner),
 }
 local signature=table.concat(flags,',')
 local emit=not prev or prev.signature~=signature
  or tick-(tonumber(prev.last_log_tick)or 0)>=600
 pair.machine_return_entry_probe_0510={tick=tick,last_log_tick=emit and tick or prev.last_log_tick,
  signature=signature,last_service_tick=pending.active_updated_tick}
 return emit,signature
end
local function run(fn)
 local pair,pending=new_pair(),{active_updated_tick=4}
 local emits,last
 local started=os.clock()
 local count=0
 for tick=1,N do
  local emit,signature=fn(pair,pending,tick)
  if emit then count=count+1;last=signature end
 end
 return (os.clock()-started)*1000,count,last,pair.machine_return_entry_probe_0510
end
local old_ms,old_count,old_signature,old_record=run(legacy)
local new_ms,new_count,new_signature,new_record=run(function(pair,pending,tick)
 return Probe.update(pair,pending,tick,false,nil,nil)
end)
assert(old_count==new_count,'diagnostic log cadence changed')
assert(old_signature==new_signature,'diagnostic text changed')
assert(old_record.signature==new_record.signature and old_record.last_log_tick==new_record.last_log_tick)
print(string.format('[custody-probe-1504-perf] %d pulses, %d logs, original=%.2fms new=%.2fms ratio=%.2fx',N,new_count,old_ms,new_ms,old_ms/new_ms))
