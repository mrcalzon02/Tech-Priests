#!/usr/bin/env python3
from pathlib import Path
ROOT=Path('.')
P4=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_004.lua'
P7=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_007.lua'
P13=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_013.lua'
P14=ROOT/'tech-priests_src/scripts/generated/control_legacy_part_014.lua'
CONV=ROOT/'tech-priests_src/scripts/idle_priest_conversations.lua'
HIST=ROOT/'docs/DEVELOPMENT_HISTORY.md'

def cut_function(text, signature, marker):
    if text.count(signature)!=1: raise SystemExit(f'{signature}: {text.count(signature)}')
    start=text.index(signature); lines=text[start:].splitlines(True); depth=0; endpos=0
    for line in lines:
        s=line.strip()
        if s.startswith('function ') or ' = function(' in s: depth+=1
        if s.startswith('if ') and s.endswith(' then'): depth+=1
        if s.startswith('for ') and s.endswith(' do'): depth+=1
        if s.startswith('while ') and s.endswith(' do'): depth+=1
        if s=='end' or s.startswith('end '): depth-=1
        endpos+=len(line)
        if depth==0: break
    return text[:start]+marker+'\n'+text[start+endpos:]

all_text='\n'.join(p.read_text(errors='replace') for p in (ROOT/'tech-priests_src').rglob('*.lua'))
assert all_text.count('function is_pair_available_for_idle_scan(pair)')==3
assert all_text.count('function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)')==4

p4=P4.read_text(); p4=cut_function(p4,'function is_pair_available_for_idle_scan(pair)','-- 0.1.674-dev / 0787: base idle-scan eligibility is integrated into fragment 014.\nTECH_PRIESTS_BASE_IDLE_SCAN_AVAILABILITY_0248_MERGED = true'); P4.write_text(p4)
p7=P7.read_text(); p7=cut_function(p7,'function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)','-- 0.1.674-dev / 0787: base conversation eligibility is integrated into the final 0249 module.\nTECH_PRIESTS_BASE_IDLE_CONVERSATION_AVAILABILITY_0249_MERGED = true'); P7.write_text(p7)

p13=P13.read_text(); start=p13.index('TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246 ='); end=p13.index('TECH_PRIESTS_FINAL_TICK_PAIR_BEFORE_DIAGNOSTICS_0246 =',start)
p13=p13[:start]+'''-- 0.1.674-dev / 0787: 0246 priority quarantine is called directly by canonical predicates.
TECH_PRIESTS_0246_IDLE_SCAN_AVAILABILITY_WRAPPER_RETIRED = true
TECH_PRIESTS_0246_IDLE_CONVERSATION_AVAILABILITY_WRAPPER_RETIRED = true

'''+p13[end:]; P13.write_text(p13)

p14=P14.read_text(); start=p14.index('TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248 ='); end=p14.index('TECH_PRIESTS_TICK_PAIR_BEFORE_0248 =',start)
replacement='''-- 0.1.674-dev / 0787: canonical idle-scan availability predicate.
TECH_PRIESTS_IDLE_SCAN_AVAILABLE_PREDECESSORS_RETIRED = true
function is_pair_available_for_idle_scan(pair)
  local probe = tech_priests_0248_higher_priority_probe and tech_priests_0248_higher_priority_probe(pair) or nil
  if probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
    if tech_priests_0248_cancel_idle_layers then tech_priests_0248_cancel_idle_layers(pair, probe.priority) end
    return false
  end
  if tech_priests_0246_priority_blocks_idle and tech_priests_0246_priority_blocks_idle(pair) then
    if pair then pair.idle_scan_quarantined_0246 = game and game.tick or 0 end
    return false
  end
  if not read_global_bool_setting("tech-priests-enable-idle-scan-behavior", true) then return false end
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  if pair.target and pair.target.valid then return false end
  if pair.idle_conversation or pair.idle_conversation_listener_until then return false end
  if pair.inventory_scan or pair.scavenge or pair.cram then return false end
  local mode = pair.mode or "idle"
  if mode ~= "idle" and mode ~= "returning" and mode ~= "" then return false end
  return true
end

TECH_PRIESTS_0248_IDLE_CONVERSATION_AVAILABILITY_WRAPPER_RETIRED = true

'''
p14=p14[:start]+replacement+p14[end:]; P14.write_text(p14)

conv=CONV.read_text(); start=conv.index('tech_priests_original_is_pair_available_for_idle_conversation_0249 ='); end=conv.index('tech_priests_original_start_idle_conversation_0249 =',start)
replacement='''-- 0.1.674-dev / 0787: canonical conversation availability predicate.
TECH_PRIESTS_IDLE_CONVERSATION_AVAILABILITY_PREDECESSORS_RETIRED = true
function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)
  if tech_priests_idle_priest_conversations_higher_priority_visible_0249(pair) then
    tech_priests_idle_priest_conversations_cancel_0249(pair, "higher-priority-work")
    return false
  end
  local probe = tech_priests_0248_higher_priority_probe and tech_priests_0248_higher_priority_probe(pair) or nil
  if probe and probe.priority and probe.priority ~= "idle" and probe.priority ~= "invalid" then
    if tech_priests_0248_cancel_idle_layers then tech_priests_0248_cancel_idle_layers(pair, probe.priority) end
    tech_priests_idle_priest_conversations_cancel_0249(pair, "higher-priority-probe:" .. tostring(probe.priority))
    return false
  end
  if tech_priests_0246_priority_blocks_idle and tech_priests_0246_priority_blocks_idle(pair) then
    if pair then pair.idle_conversation_quarantined_0246 = game and game.tick or 0 end
    return false
  end
  if not read_global_bool_setting("tech-priests-enable-idle-conversations", true) then return false end
  if not (pair and pair.priest and pair.priest.valid and pair.station and pair.station.valid) then return false end
  if pair.idle_conversation then return false end
  if pair.idle_conversation_listener_until and game.tick < pair.idle_conversation_listener_until then return false end
  if pair.target and pair.target.valid then return false end
  if pair.inventory_scan or pair.scavenge or pair.cram or pair.emergency_craft then return false end
  local mode = pair.mode or "idle"
  if mode ~= "idle" and mode ~= "returning" and mode ~= "" then return false end
  if not as_listener then
    if game.tick < (pair.next_idle_conversation_tick or 0) then return false end
    if game.tick < (pair.next_idle_conversation_attempt_tick or 0) then return false end
  end
  return true
end

'''
conv=conv[:start]+replacement+conv[end:]; CONV.write_text(conv)

after='\n'.join(p.read_text(errors='replace') for p in (ROOT/'tech-priests_src').rglob('*.lua'))
assert after.count('function is_pair_available_for_idle_scan(pair)')==1
assert after.count('function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)')==1
for x in ['TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_SCAN_0246','TECH_PRIESTS_ORIGINAL_IS_PAIR_AVAILABLE_FOR_IDLE_CONVERSATION_0246','TECH_PRIESTS_IDLE_SCAN_AVAILABLE_BEFORE_0248','TECH_PRIESTS_IDLE_CONVERSATION_AVAILABLE_BEFORE_0248','tech_priests_original_is_pair_available_for_idle_conversation_0249']:
    assert x not in after,x
h=HIST.read_text(); heading='## 2026-07-21 — Milestone 0787: Canonical Idle Availability Predicates'
if heading not in h:
    h+=f'''\n\n{heading}\n\nConsolidated the idle-scan and idle-conversation availability predecessor stacks into one authoritative predicate per behavior. Fragment 014 now owns idle-scan availability with direct 0248 higher-priority cancellation, 0246 quarantine, settings, validity, mode, and conflicting-state checks. The final editable idle_priest_conversations.lua module now owns conversation availability with direct 0249 visibility cancellation, 0248 probing, 0246 quarantine, settings, validity, listener timing, cooldown, mode, and conflicting-state checks. The base 0167/idle-scan definitions, 0246 wrappers, 0248 wrappers, and 0249 predecessor capture are explicitly retired. tick_pair, conversation start/update, and movement behavior remain unchanged. Static Source validation does not constitute Factorio runtime proof.\n'''; HIST.write_text(h)
print('0787 transformation complete')
