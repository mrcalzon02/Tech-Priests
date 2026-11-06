-- 1159: exercise the ACTUAL native harness Magos receipt proof offline.
-- More than two physically logged deliveries are legitimate; fabricated
-- ledger, duplicate counters, source claims or inventory are never accepted.
package.path="tech-priests_src/?.lua;tech-priests_src/?/init.lua;"..package.path
local h=dofile("tests/scenarios/all-ground-ranks/ground_rank_harness.lua")
assert(type(h.verify_magos_receipt_1159)=="function")
local units={442,443,444,445}
local mission={need="iron-ore",delivered_to_magos_count=1}
local test={units=units,machine_courier=false,mined=true,last_hop=3}
local courier={phase="magos-delivered",quantity=1,inventory=nil,
  hops_completed=3,receipt_hop=3,delivered_count=1,
  delivered_station_unit=442,item="iron-ore",
  receipts_0982={
    {hop=1,source_station_unit=445,destination_station_unit=444,
      carrier_priest_unit=754,item="iron-ore",quantity=1,
      destination_before=0,destination_after=1,tick=100},
    {hop=2,source_station_unit=444,destination_station_unit=443,
      carrier_priest_unit=755,item="iron-ore",quantity=1,
      destination_before=0,destination_after=1,tick=200},
    {hop=3,source_station_unit=443,destination_station_unit=442,
      carrier_priest_unit=756,item="iron-ore",quantity=1,
      destination_before=0,destination_after=1,tick=300},
  },receipt_destination_before=0,receipt_destination_after=1}
local function verify(count)
  return h.verify_magos_receipt_1159(test,mission,courier,count)
end
assert(verify(1)==true,"one naturally mined item did not physically arrive")
test.machine_courier=true
test.machine_magos_count_before=1
test.machine_receipt_count_0994=1
courier.source_kind_0991="drill-output"
courier.drill_receipt_claimed_0991=true
mission.delivered_to_magos_count=13
courier.receipts_0982[3].destination_before=12
courier.receipts_0982[3].destination_after=13
courier.receipt_destination_before=12
courier.receipt_destination_after=13
assert(verify(13)==true,
  "twelve additional genuine machine deliveries were falsely rejected")
mission.delivered_to_magos_count=1
assert(verify(13)==false,"missing Magos count increment was accepted")
mission.delivered_to_magos_count=13
assert(verify(12)==false,"fictitious final Magos inventory was accepted")
courier.receipts_0982[3].destination_after=14
assert(verify(13)==false,"nonconserving final receipt was accepted")
courier.receipts_0982[3].destination_after=13
courier.receipts_0982[2].source_station_unit=999
assert(verify(13)==false,"a skipped upstream station was credited")
courier.receipts_0982[2].source_station_unit=444
courier.drill_receipt_claimed_0991=false
assert(verify(13)==false,"unclaimed machine output was credited")
courier.drill_receipt_claimed_0991=true
courier.inventory={valid=true}
assert(verify(13)==false,"an undebited courier hold was accepted")
courier.inventory=nil
test.machine_magos_count_before=nil
assert(verify(13)==false,"unknown baseline counted extra stock")
test.machine_magos_count_before=13
assert(verify(13)==false,"no new item beyond baseline was accepted")
test.machine_magos_count_before=1
assert(verify(13)==true)
print("[ore-engine-magos-receipt-1159] PASS native harness accepts repeated physical Magos returns, rejects false counts, broken ledgers and unreleased custody")
