-- Per-weapon manufacturing and handling, within the owner's science ceilings.
local M={}
M.profiles={
 ['galvanic-rifle']={role='Starter precision rifle; long reach, five-round clips.',cost={{'iron-plate',10},{'copper-plate',5},{'iron-gear-wheel',2}},time=5,move=.7},
 lasgun={role='Affordable sustained line fire; forty shots per cell.',cost={{'iron-plate',6},{'copper-plate',3},{'electronic-circuit',1}},time=5,move=.65},
 ['power-axe']={role='Contact melee; induction impact, no projectile.',cost={{'steel-plate',4},{'copper-plate',4},{'iron-gear-wheel',3},{'electronic-circuit',2}},time=8,move=.9},
 laspistol={role='Mobile sidearm; shorter range and lower output than a lasgun.',cost={{'iron-plate',4},{'copper-plate',2},{'electronic-circuit',2}},time=4,move=.9},
 ['bolt-pistol']={role='Compact bolt sidearm; expensive ammunition.',cost={{'steel-plate',6},{'iron-gear-wheel',3},{'electronic-circuit',2}},time=8,move=.85},
 ['radium-carbine']={role='Rapid close-range fire; physical and radiation damage.',cost={{'steel-plate',12},{'advanced-circuit',2},{'battery',2}},time=12,move=.65},
 ['radium-serpenta']={role='Slower, stronger radium shots; greater reach and mobility.',cost={{'steel-plate',10},{'advanced-circuit',4},{'battery',3}},time=14,move=.85},
 ['gamma-pistol']={role='Short-range radiation burst; low cell capacity.',cost={{'steel-plate',12},{'advanced-circuit',6},{'battery',6}},time=16,move=.8},
 boltgun={role='Medium-range bolt fire; higher sustained output than the pistol.',cost={{'steel-plate',16},{'advanced-circuit',2},{'iron-gear-wheel',6}},time=14,move=.6},
 ['dialogus-staff']={role='Powered melee impact; stronger but slower than the axe.',cost={{'steel-plate',12},{'advanced-circuit',4},{'battery',4}},time=16,move=.9},
 ['condemnor-boltgun']={role='Long-range precision bolt fire; no secondary stake attack.',cost={{'steel-plate',22},{'advanced-circuit',6},{'battery',2}},time=20,move=.55},
 ['magnarail-lance']={role='Longest-range single-target shot; three slugs per pack.',cost={{'steel-plate',30},{'advanced-circuit',12},{'battery',10},{'electric-engine-unit',2}},time=30,move=.4},
 ['volkite-blaster']={role='Thermal beam with a small enemy-only impact area.',cost={{'steel-plate',35},{'processing-unit',8},{'battery',20},{'low-density-structure',5}},time=40,move=.35},
 ['heavy-arc-rifle']={role='Electrical crowd damage; broad enemy-only impact area.',cost={{'steel-plate',40},{'processing-unit',8},{'battery',16},{'electric-engine-unit',4}},time=40,move=.3},
 ['heavy-grav-cannon']={role='Final heavy impact: broad enemy-only damage; 1.5 s target slow.',cost={{'steel-plate',60},{'processing-unit',16},{'battery',30},{'low-density-structure',15},{'electric-engine-unit',6}},time=60,move=.25},
}
-- Existing real unit research takes authority in final-fixes. These are standalone bundles.
M.research={
 lasgun={'guard-muster',50,{'steel-processing'}},
 ['power-axe']={'enginseer-initiation',75,{'automation','steel-processing'}},
 laspistol={'officer-corps',100,{'@lasgun','logistics'}},
 ['bolt-pistol']={'commissariat',150,{'@laspistol','military-2','explosives','military-science-pack'}},
 ['radium-carbine']={'vanguard-cohorts',150,{'@power-axe','chemical-science-pack','uranium-processing','advanced-circuit','battery','military-science-pack'}},
 ['radium-serpenta']={'skitarii-command',250,{'@radium-carbine'}},
 ['gamma-pistol']={'cybernetica-protocols',250,{'@power-axe','chemical-science-pack','battery','advanced-circuit','military-science-pack'}},
 boltgun={'militant-orders',200,{'military-2','explosives','military-science-pack','chemical-science-pack','battery','advanced-circuit'}},
 ['dialogus-staff']={'sacred-liturgies',200,{'@boltgun'}},
 ['condemnor-boltgun']={'canoness-command',350,{'@boltgun','@dialogus-staff'}},
 ['magnarail-lance']={'galvanic-mastery',500,{'@gamma-pistol','production-science-pack','electric-engine'}},
 ['volkite-blaster']={'dominus-ascension',750,{'@magnarail-lance','utility-science-pack','processing-unit','low-density-structure'}},
 ['heavy-arc-rifle']={'heavy-servitor-chassis',750,{'@magnarail-lance','utility-science-pack','processing-unit','electric-engine'}},
 ['heavy-grav-cannon']={'grav-annihilation',1500,{'@volkite-blaster','@heavy-arc-rifle','low-density-structure'}},
}
return M
