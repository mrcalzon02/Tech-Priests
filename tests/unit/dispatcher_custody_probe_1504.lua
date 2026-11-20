-- Regression: custody probe signature, change detection, log interval and
-- persisted record identity match old behavior without per-pulse allocations.
package.path = './tech-priests_src/?.lua;./tech-priests_src/?/init.lua;' .. package.path
local P = require('scripts.core.dispatcher_custody_probe_1504')
local pair = {
  direct_acquisition_custody_0513 = {},
  order_queue_0469 = {current = {kind = 'deliver'}},
  movement_request_0418 = {owner = 'machine-0528'},
}
local pending = {custody = {}, active_updated_tick = 100}
local expected = '0528-custody=true,pair-0528-custody=false,' ..
  'direct-custody=true,direct-active=true,defense-task=false,' ..
  'combat-target=nil,machine-valid=false,order=deliver,' ..
  'movement-owner=machine-0528'
local emit, text, record = P.update(pair, pending, 100, true, nil, false)
assert(emit and text == expected and record == pair.machine_return_entry_probe_0510,
  'initial diagnostic signature changed')
assert(record.tick == 100 and record.last_log_tick == 100
  and record.last_service_tick == 100)
local previous = record
for tick=101,699 do
  pending.active_updated_tick = tick + 2
  local e, string_out, rec = P.update(pair, pending, tick, true, nil, false)
  assert(not e and string_out == nil and rec == previous,
    'stable custody probe constructed/emitted a redundant diagnostic')
  assert(rec.tick == tick and rec.last_service_tick == tick+2)
end
assert(record.signature == expected and record.last_log_tick == 100)
emit,text,record = P.update(pair,pending,700,true,nil,false)
assert(emit and text == expected and record.last_log_tick == 700,
  '600 tick refresh did not preserve the signature')
pair.machine_logistics_custody_0528 = {}
emit,text,record = P.update(pair,pending,701,true,nil,false)
assert(emit and text:find('pair-0528-custody=true',1,true),
  'custody change was not reported immediately')
local last_tick=record.last_log_tick
pair.order_queue_0469.current.kind = 'return'
emit,text = P.update(pair,pending,701,true,nil,false)
assert(emit and text:find('order=return',1,true),
  'same tick order transition not reported')
pair.movement_request_0418.owner = 'repair'
emit,text = P.update(pair,pending,701,true,nil,false)
assert(emit and text:find('movement-owner=repair',1,true),
  'same tick movement-owner change not reported')
pair.combat_target = {valid = false}
emit,text = P.update(pair,pending,702,true,false,false)
assert(emit and text:find('combat-target=false',1,true),
  'nil versus false validity distinction was lost')
assert(pair.machine_return_entry_probe_0510 == previous,
  'a transition allocated a replacement saved diagnostic record')
-- Existing save: legacy signature already matches, so first new observation
-- should not force an unneeded log while migration is reconstructed.
local loaded = {order_queue_0469={current={kind='deliver'}},
  movement_request_0418={owner='machine-0528'},
  direct_acquisition_custody_0513={},
  machine_return_entry_probe_0510={signature=expected,last_log_tick=700,tick=700}}
local old=loaded.machine_return_entry_probe_0510
local again,log_text,rec=P.update(loaded,pending,701,true,nil,false)
assert(not again and log_text==nil and rec==old and rec.last_log_tick==700,
  'matching legacy save diagnostic incorrectly logged again')
print('[dispatcher-custody-probe-1504] PASS: signature, interval, changes, save reuse')
