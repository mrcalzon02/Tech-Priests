local Gate=dofile("tech-priests_src/scripts/core/self_construction_frustration_gate.lua")
assert(not Gate.ready())
assert(not Gate.ready({}))
assert(not Gate.ready({logistic_frustration_start_tick=100},200))
assert(not Gate.ready({logistic_frustration_due_tick=700},800))
local p={logistic_frustration_start_tick=100,logistic_frustration_due_tick=700}
assert(not Gate.ready(p,99))
assert(not Gate.ready(p,699))
assert(p.self_construction_frustration_unlocked_1504==nil)
local ok,reason=Gate.ready(p,700)
assert(ok and reason=="logistics-frustration-reached")
assert(p.self_construction_frustration_reached_tick_1504==700)
p.logistic_frustration_start_tick=nil
p.logistic_frustration_due_tick=nil
assert(Gate.ready(p,701),"successful logistics must not undo autonomous escalation")
assert(not Gate.ready({logistic_frustration_start_tick=800,logistic_frustration_due_tick=799},801))
assert(not Gate.ready({scavenge_started_tick=1,emergency_craft={started_tick=1}},100000))
assert(not Gate.ready({logistic_frustration_start_tick=100,logistic_frustration_due_tick=700},699))
print("PASS autonomous factory escalation waits for actual logistics frustration and persists")
