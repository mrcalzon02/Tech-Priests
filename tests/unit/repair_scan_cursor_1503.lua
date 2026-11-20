package.path = './tech-priests_src/?.lua;./tech-priests_src/?/init.lua;' .. package.path
local Cursor = require('scripts.core.repair_scan_cursor_1503')
local pair = {}
local seen = {}
for pass=1,4 do
  local start, n, complete, after = Cursor.window(pair, 97, 32)
  assert(n == 32 and not complete and after >= 1 and after <= 97)
  for i=0,n-1 do
    local index = ((start + i - 1)%97)+1
    seen[index] = true
  end
end
local all=0
for i=1,97 do assert(seen[i], 'repair target in tail was never reached: '..i); all=all+1 end
assert(all==97)
local s,n,full = Cursor.window({}, 7, 32)
assert(s==1 and n==7 and full, 'small scans must certify full coverage')
local s2,n2,full2 = Cursor.window({}, 0, 32)
assert(s2==1 and n2==0 and full2, 'empty scans are complete')
local over = {}
local st,checks = Cursor.window(over, 10000, 1000000)
assert(st==1 and checks==128, 'unbounded requested limit bypassed scan budget')
local small_limit={}
assert(select(2, Cursor.window(small_limit, 7, -99))==1,'negative limit not clamped')
local shrink = {}
Cursor.window(shrink, 100, 80)
local st2,checks2,complete2 = Cursor.window(shrink, 12, 5)
assert(st2==1 and checks2==5 and not complete2,'shrunken result retained invalid cursor')
assert(select(4,Cursor.window(shrink, 12, 5)) == 11, 'rotating cursor did not advance')
local changes={}
for _=1,20 do Cursor.window(changes, 80, 8) end
assert(Cursor.window(changes, 80, 8))
print('[repair-scan-cursor-1503] PASS: tail coverage, bounds, empty, shrink')
