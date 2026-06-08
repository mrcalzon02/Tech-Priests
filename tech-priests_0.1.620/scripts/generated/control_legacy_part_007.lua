-- Auto-split control.lua fragment 007 for Tech Priests 0.1.438.
-- Generated mechanically from 0.1.437 monolithic control.lua.
-- Purpose: reduce Lua main-chunk local/register pressure without deleting behavior.



-- 0.1.167 idle Tech-Priest conversation doctrine:
-- Adds a conservative idle-only conversation action between nearby Tech-Priests.
-- The spoken doctrine is selected from the last researched technology, the
-- speaker tier, and the listener tier. Unknown modded technologies intentionally
-- fall back to confusion, reverence, and suspicion of xenos-adjacent doctrine.
TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167 = "__fallback_unknown_technology__"
TECH_PRIESTS_DEFAULT_CONVERSATION_TOPIC_0167 = "cogitator-station-deployment"
TECH_PRIESTS_IDLE_CONVERSATION_DURATION_TICKS_0167 = 60 * 7
TECH_PRIESTS_IDLE_CONVERSATION_LINE_TICKS_0167 = 60 * 2
TECH_PRIESTS_IDLE_CONVERSATION_COOLDOWN_TICKS_0167 = 60 * 50
TECH_PRIESTS_IDLE_CONVERSATION_ATTEMPT_TICKS_0167 = 60 * 12
TECH_PRIESTS_IDLE_CONVERSATION_MIN_DISTANCE_SQ_0167 = 6.25
TECH_PRIESTS_IDLE_CONVERSATION_RENDER_TTL_0167 = 130

TECH_PRIESTS_CONVERSATION_TOPIC_ALIASES_0167 = {
  ["pure-carbon-processing"] = "general-material-doctrine",
  ["ritual-wood-pulping"] = "general-material-doctrine",
  ["ritual-salt-extraction"] = "general-material-doctrine",
  ["sodium-carbonate-synthesis"] = "general-material-doctrine",
  ["paraffin-separation"] = "efficient-sacred-oil-rendering",
  ["sacred-candle-rendering"] = "machine-maintenance-litanies",
  ["machine-spirit-initial-consecration-1"] = "machine-maintenance-litanies",
  ["machine-spirit-initial-consecration-2"] = "machine-maintenance-litanies",
  ["machine-spirit-capacity-1"] = "ritual-of-machine-appeasement",
  ["machine-spirit-capacity-2"] = "ritual-of-machine-appeasement",
  ["cogitator-operating-radius-1"] = "cogitator-station-deployment",
  ["cogitator-operating-radius-2"] = "intermediate-cogitator-stations",
  ["cogitator-operating-radius-3"] = "senior-cogitator-stations",
  ["tech-priest-rite-of-kinetic-exemption"] = "senior-cogitator-stations",
  ["orbital-relic-procurement"] = "orbital-trader-deployment",
  ["blackstone-citadel-manufacture"] = "orbital-trader-deployment",
  ["hydrogen-thruster-propulsion"] = "thetazine-propulsion"
}

TECH_PRIESTS_CONVERSATION_LINES_0167 = {
  ["general-material-doctrine"] = {
    senior = {
      senior = {
        "__TECH_ICON__ The factory has learned another material rite. Useful, provided accounting survives the enthusiasm.",
        "__TECH_ICON__ Every new intermediate is a promise that the belts will become worse before they become holy."
      },
      intermediate = {
        "__TECH_ICON__ Treat the new material as doctrine under audit: route it cleanly, buffer it visibly, and waste none of it.",
        "__TECH_ICON__ Do not let a new ingredient become a new excuse for belt heresy."
      },
      junior = {
        "__TECH_ICON__ A new material rite has been authorized. Touch only what the Cogitator assigns."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The new material chain functions, Magos, though its byproducts look personally offended.",
        "__TECH_ICON__ I can integrate the process, but the early buffers will need watching."
      },
      intermediate = {
        "__TECH_ICON__ Another input, another chance for the factory to tie itself into sacred knots.",
        "__TECH_ICON__ We should isolate the new chain before it infects every belt with ambition."
      },
      junior = {
        "__TECH_ICON__ If the new material appears in your station, move it only as instructed."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ New material doctrine detected. Understanding absent. Obedience intact." },
      intermediate = { "__TECH_ICON__ New ingredient acknowledged. Awaiting assigned purpose." },
      junior = { "__TECH_ICON__ The factory has learned a thing. I have not." }
    }
  },
  ["cogitator-station-deployment"] = {
    senior = {
      senior = {
        "__TECH_ICON__ The Junior Cogitator Station is less a command node than a leash, but a leash is better than faith-based maintenance.",
        "__TECH_ICON__ Observe the radius discipline: one shrine, one servant, one tolerable pocket of machine compliance."
      },
      intermediate = {
        "__TECH_ICON__ Do not overextend the Junior station. Its priest obeys locally, consumes locally, and fails locally.",
        "__TECH_ICON__ Stock repair packs first, sacred oil second, ammunition third. Panic is not an inventory strategy."
      },
      junior = {
        "__TECH_ICON__ Remain within station doctrine. Repair what is assigned. Consecrate what is permitted. Wander nowhere.",
        "__TECH_ICON__ The boundary is not a suggestion. It is the shape of your permitted thoughts."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The Junior station appears stable, Magos, but its supply limitations are severe.",
        "__TECH_ICON__ It obeys well when fed, and sulks immediately when not."
      },
      intermediate = {
        "__TECH_ICON__ If the station inventory dries up, the Junior priest simply waits. Efficient, in the same sense that a locked door is efficient.",
        "__TECH_ICON__ Stage oil and repair packs near the shrine before the machines discover neglect as a lifestyle."
      },
      junior = {
        "__TECH_ICON__ Check the station inventory before complaint. The Cogitator does not conjure supplies from hurt feelings."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Instruction received. Remaining within blessed radius." },
      intermediate = { "__TECH_ICON__ Station boundary respected. Wandering withheld." },
      junior = { "__TECH_ICON__ Local doctrine acknowledged. Wandering is heresy." }
    }
  },
  ["efficient-sacred-oil-rendering"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Efficient oil rendering gives the maintenance chain enough volume to pretend it was planned.",
        "__TECH_ICON__ Sacred Machine Oil is not a luxury; it is the cheapest apology we can offer abused machinery."
      },
      intermediate = {
        "__TECH_ICON__ Use improved oil where machines cycle constantly. A machine that works often sins often.",
        "__TECH_ICON__ Do not waste sacred oil on a machine about to be replaced. Reverence requires accounting."
      },
      junior = {
        "__TECH_ICON__ Apply the oil to strained machines. Do not drink it. Do not bless yourself with it. Do not improvise."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The improved process increases supply, but consumption still spikes around overworked production blocks.",
        "__TECH_ICON__ Should oil priority follow damage risk, sanctification loss, or production value?"
      },
      intermediate = {
        "__TECH_ICON__ The new oil process helps, but mostly reveals how much neglect we were normalizing.",
        "__TECH_ICON__ High-cycle machines eat sanctity faster than management eats explanations."
      },
      junior = {
        "__TECH_ICON__ Oil the assigned machine, then return. Do not begin a personal crusade against friction."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Sacred oil acknowledged. Lubrication is obedience." },
      intermediate = { "__TECH_ICON__ The bottle shall be respected." },
      junior = { "__TECH_ICON__ Oil is holy. Slipping is not." }
    }
  },
  ["machine-maintenance-litanies"] = {
    senior = {
      senior = {
        "__TECH_ICON__ The Machine Maintenance Litany is where maintenance stops apologizing and begins making demands.",
        "__TECH_ICON__ A litany is not merely an item. It is a compressed argument against entropy."
      },
      intermediate = {
        "__TECH_ICON__ Reserve litanies for machines whose sanctity loss exceeds ordinary oil doctrine.",
        "__TECH_ICON__ A litany should be staged where failure would cascade, not where the floor happens to look dramatic."
      },
      junior = {
        "__TECH_ICON__ When issued a litany, apply it with both hands and no interpretation."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The litany restores more, but its ingredient chain is more fragile than the machines it disciplines.",
        "__TECH_ICON__ Should litanies be reserved for max-capacity damage risk or ordinary low sanctification?"
      },
      intermediate = {
        "__TECH_ICON__ Litanies are expensive enough that using them badly feels like a reportable spiritual offense.",
        "__TECH_ICON__ We need a threshold policy. Otherwise every machine cough becomes a chapel service."
      },
      junior = {
        "__TECH_ICON__ Do not apply a litany unless the station issued it. Improvised reverence is how inventories disappear."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Litany accepted. No interpretation will occur." },
      intermediate = { "__TECH_ICON__ Rite delivery acknowledged." },
      junior = { "__TECH_ICON__ The sacred document will be applied." }
    }
  },
  ["cogitator-logistic-requisition"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Logistic requisition turns the station from a shrine into a supply bureaucracy, which is to say: progress.",
        "__TECH_ICON__ Hidden requester caches are ugly, but so is watching a priest stare at an empty inventory slot."
      },
      intermediate = {
        "__TECH_ICON__ When logistics are available, let the network feed the station before authorizing scavenger behavior.",
        "__TECH_ICON__ Do not mistake requester access for infinite supply. The network lies by omission."
      },
      junior = {
        "__TECH_ICON__ If logistics deliver the supply, use it. Do not question the invisible cache."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The network improves availability, but delayed delivery can still leave priests waiting mid-crisis.",
        "__TECH_ICON__ Should local scavenging begin only after a fixed delay, or after network absence is confirmed?"
      },
      intermediate = {
        "__TECH_ICON__ The logistic network is helpful right until it confidently has none of the item we need.",
        "__TECH_ICON__ At least now the priest waits for robots instead of divine intervention."
      },
      junior = {
        "__TECH_ICON__ When the station requests an item, wait. That is not idleness; it is sanctioned disappointment."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Logistic obedience acknowledged. Waiting is sanctioned." },
      intermediate = { "__TECH_ICON__ Invisible cache accepted." },
      junior = { "__TECH_ICON__ I will not chase the robots." }
    }
  },
  ["intermediate-cogitator-stations"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Intermediate stations are where the priest stops merely waiting and begins developing inconvenient initiative.",
        "__TECH_ICON__ Two inventory slots: practically decadence, provided no one puts garbage in both."
      },
      intermediate = {
        "__TECH_ICON__ Search locally, take only what doctrine permits, and return before usefulness becomes wandering.",
        "__TECH_ICON__ Cram-mode clears station clutter; it does not authorize a second logistics department with legs."
      },
      junior = {
        "__TECH_ICON__ Intermediate authority is not yours. Observe and remain station-bound."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The scavenger scan improves resilience, but recent-scan memory prevents loops.",
        "__TECH_ICON__ Cram behavior clears clutter, though destination chest selection remains politically interesting."
      },
      intermediate = {
        "__TECH_ICON__ We can finally look inside nearby chests. I expect this to reveal mostly shame.",
        "__TECH_ICON__ Local scavenging works best when the factory was not arranged by a person fleeing consequences."
      },
      junior = {
        "__TECH_ICON__ Do not touch the chests. Report the need. The station will decide whether someone smarter must rummage."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Limitation acknowledged. I will not rummage." },
      intermediate = { "__TECH_ICON__ Scavenger doctrine withheld." },
      junior = { "__TECH_ICON__ Chest contents are above my rank." }
    }
  },
  ["senior-cogitator-stations"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Senior stations authorize escalation, which is what desperation is called after it receives a red robe.",
        "__TECH_ICON__ Emergency fabrication is doctrine admitting the supply chain has already sinned."
      },
      intermediate = {
        "__TECH_ICON__ Scavenge first, cram second, fabricate only when all proper channels have failed.",
        "__TECH_ICON__ A Senior priest may improvise, but only after every respectable system has humiliated itself."
      },
      junior = {
        "__TECH_ICON__ You are witnessing senior doctrine. Do not copy it, describe it, or attempt it with enthusiasm."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The escalation chain is powerful, but fabrication delays need visible status feedback.",
        "__TECH_ICON__ The Senior station solves problems that should have been prevented upstream."
      },
      intermediate = {
        "__TECH_ICON__ Senior stations are impressive in the same way a fire axe is impressive.",
        "__TECH_ICON__ Emergency fabrication means the priest can repair the factory and indict it simultaneously."
      },
      junior = {
        "__TECH_ICON__ If a Senior fabricates supplies in the field, do not interpret that as permission."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Senior authority acknowledged. Ambition suppressed." },
      intermediate = { "__TECH_ICON__ Standing back reverently." },
      junior = { "__TECH_ICON__ Desperation doctrine observed." }
    }
  },
  ["ritual-of-machine-appeasement"] = {
    senior = {
      senior = {
        "__TECH_ICON__ The Ritual of Machine Appeasement is diplomacy with an armed toaster.",
        "__TECH_ICON__ At this tier, we remind the machine spirit what compliance costs."
      },
      intermediate = {
        "__TECH_ICON__ Use appeasement rites for machines whose failure would propagate, not for every assembler with a sad noise.",
        "__TECH_ICON__ Escalate when ordinary oil and litanies are insufficient, not when you are bored."
      },
      junior = {
        "__TECH_ICON__ If issued the rite, deliver it. Do not ask why the machine deserves ceremony."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The restoration value is excellent, but target selection determines whether it is doctrine or waste.",
        "__TECH_ICON__ Should the rite prefer damaged maximums or low current sanctification?"
      },
      intermediate = {
        "__TECH_ICON__ Appeasement is what happens when oil fails, litanies fail, and someone still wants output.",
        "__TECH_ICON__ The rite is costly enough that the machine should at least look ashamed afterward."
      },
      junior = {
        "__TECH_ICON__ Carry the rite carefully. Apply only when ordered. Do not wave it at random machines."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Formal intervention acknowledged." },
      intermediate = { "__TECH_ICON__ No waving will occur." },
      junior = { "__TECH_ICON__ Appeasement delivery prepared." }
    }
  },
  ["sacred-incense-grenades"] = {
    senior = {
      senior = {
        "__TECH_ICON__ A thrown incense charge is the natural endpoint of maintenance doctrine losing patience.",
        "__TECH_ICON__ Area sanctification is elegant, provided no one asks why the solution became throwable."
      },
      intermediate = {
        "__TECH_ICON__ Use incense where several machines require progressive sanctification within the same radius.",
        "__TECH_ICON__ The smoke field is for clusters, platforms, and emergencies where walking to each machine is beneath the crisis."
      },
      junior = {
        "__TECH_ICON__ Do not throw the sacred grenade unless explicitly ordered."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The field effect is useful, but machine density decides whether the cost is justified.",
        "__TECH_ICON__ Should incense prefer platform machinery or dense terrestrial production blocks?"
      },
      intermediate = {
        "__TECH_ICON__ We have made maintenance throwable. I refuse to pretend this was not inevitable.",
        "__TECH_ICON__ Incense works best when machines are packed tightly enough to share guilt."
      },
      junior = {
        "__TECH_ICON__ Do not pull the pin unless ordered. Do not smell the doctrine."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Pin untouched. Smoke doctrine acknowledged." },
      intermediate = { "__TECH_ICON__ I will not inhale intentionally." },
      junior = { "__TECH_ICON__ Grenade reverence engaged." }
    }
  },
  ["orbital-trader-deployment"] = {
    senior = {
      senior = {
        "__TECH_ICON__ The Orbital Trader is procurement disguised as devotion and logistics disguised as miracle.",
        "__TECH_ICON__ Off-world trade introduces supply, cost, dependency, and exactly enough mystery to keep accounting nervous."
      },
      intermediate = {
        "__TECH_ICON__ Treat off-world components as constrained strategic material, not decorative brass.",
        "__TECH_ICON__ Do not overbuild stations until imported components can keep pace."
      },
      junior = {
        "__TECH_ICON__ The Orbital Trader provides sacred components. You will not question their origin."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The trader stabilizes station production, but component throughput may throttle expansion.",
        "__TECH_ICON__ Should deployment be paced by component stockpile or immediate maintenance need?"
      },
      intermediate = {
        "__TECH_ICON__ The Orbital Trader is wonderful because now our bottlenecks arrive from farther away.",
        "__TECH_ICON__ Imported components solve local shortages by creating expensive nonlocal shortages."
      },
      junior = {
        "__TECH_ICON__ Do not touch off-world components unless the recipe demands it."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Origin unquestioned. Imported component respected." },
      intermediate = { "__TECH_ICON__ Curiosity suppressed." },
      junior = { "__TECH_ICON__ Orbit provides. I obey." }
    }
  },
  ["thetazine-propulsion"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Thetazine propulsion is what happens when chemistry is allowed to read forbidden poetry.",
        "__TECH_ICON__ This chain is not clean. It is merely obedient in the direction of thrust."
      },
      intermediate = {
        "__TECH_ICON__ Treat Thetazine systems as high-energy doctrine. Keep the chain isolated and visibly supplied.",
        "__TECH_ICON__ The thruster is useful, but its chemistry should be respected like a loaded lawsuit."
      },
      junior = {
        "__TECH_ICON__ Do not stand near the Thetazine chain unless ordered."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The chain is powerful, but the intermediates look named during an incident report.",
        "__TECH_ICON__ Should Thetazine fuel be buffered near thrusters or produced just-in-time?"
      },
      intermediate = {
        "__TECH_ICON__ Thetazine is proof that thrust and wisdom are unrelated variables.",
        "__TECH_ICON__ I recommend separate routing before someone lets water and ambition share a pipe."
      },
      junior = {
        "__TECH_ICON__ Do not inspect Thetazine by touching it."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Distance respected. No touching will occur." },
      intermediate = { "__TECH_ICON__ Bubbling will be reported." },
      junior = { "__TECH_ICON__ Propulsion fear acknowledged." }
    }
  },
  ["void-fusion-thruster-propulsion"] = {
    senior = {
      senior = {
        "__TECH_ICON__ Void-fusion propulsion finally gives the platform a spine, provided we ignore the screaming cost structure.",
        "__TECH_ICON__ A one-by-nine drive assembly is not an engine. It is an architectural threat."
      },
      intermediate = {
        "__TECH_ICON__ Void-fusion drives demand deliberate placement, stable power planning, and component reserves.",
        "__TECH_ICON__ Treat the final thruster like infrastructure with a temper."
      },
      junior = {
        "__TECH_ICON__ Do not approach the void-fusion drive without instruction. The engine is larger than your authority."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ The drive footprint suggests we should plan around it before the platform frame is finalized.",
        "__TECH_ICON__ Should drive inspection outrank ordinary platform machinery?"
      },
      intermediate = {
        "__TECH_ICON__ The void-fusion drive is large enough to make layout mistakes visible from orbit.",
        "__TECH_ICON__ I suggest building around the drive before the drive punishes our optimism."
      },
      junior = {
        "__TECH_ICON__ If assigned near the drive, inspect only what the Cogitator marks."
      }
    },
    junior = {
      senior = { "__TECH_ICON__ Fusion authority respected. Improvisation forbidden." },
      intermediate = { "__TECH_ICON__ The hum is not a song." },
      junior = { "__TECH_ICON__ Distance and obedience maintained." }
    }
  },
  [TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167] = {
    senior = {
      senior = {
        "__TECH_ICON__ The Omnissiah has revealed a technology absent from my sanctioned indexes. Miracle or compliance failure remains unresolved.",
        "__TECH_ICON__ The archive recognizes the research event, but not the doctrine. I find this spiritually untidy.",
        "__TECH_ICON__ If this is the Omnissiah's will, it is unusually poorly documented."
      },
      intermediate = {
        "__TECH_ICON__ The latest research is not in your sanctioned training materials. Do not panic. That remains my responsibility.",
        "__TECH_ICON__ The Omnissiah may speak through unfamiliar mechanisms. The xenos may also do this. The distinction is why we have senior clergy.",
        "__TECH_ICON__ If the machinery begins chanting in an unapproved language, escalate immediately."
      },
      junior = {
        "__TECH_ICON__ A new technology has been authorized. You are not required to understand it.",
        "__TECH_ICON__ If the device glows, whispers, rotates incorrectly, or looks pleased with itself, report upward.",
        "__TECH_ICON__ You will obey the Cogitator. You will not interpret the revelation."
      }
    },
    intermediate = {
      senior = {
        "__TECH_ICON__ Magos, the latest research does not correspond to any rite I recognize. Should I be inspired or concerned?",
        "__TECH_ICON__ I cannot determine whether this technology is blessed, alien, or simply from another mod dependency.",
        "__TECH_ICON__ Is this divine mystery, or have we accidentally subscribed to xenos engineering?"
      },
      intermediate = {
        "__TECH_ICON__ The latest research is unfamiliar. I suggest pretending we expected that until someone important arrives.",
        "__TECH_ICON__ Either this is a miracle, or the factory has developed a side project.",
        "__TECH_ICON__ We may have been abandoned by documentation. Again."
      },
      junior = {
        "__TECH_ICON__ A new technology has been researched. Do not ask what it does unless you are prepared to be disappointed.",
        "__TECH_ICON__ The doctrine is pending. Until then, obedience remains the safest interpretation.",
        "__TECH_ICON__ If the machine spirit seems foreign, notify someone with a larger hat."
      }
    },
    junior = {
      senior = {
        "__TECH_ICON__ New revelation detected. Understanding absent. Obedience intact.",
        "__TECH_ICON__ Possible miracle detected. Possible error detected. Standing by."
      },
      intermediate = {
        "__TECH_ICON__ New technology acknowledged. Meaning unclear.",
        "__TECH_ICON__ Is this the Omnissiah's will?"
      },
      junior = {
        "__TECH_ICON__ The factory knows something we do not.",
        "__TECH_ICON__ Perhaps the Omnissiah has spoken softly.",
        "__TECH_ICON__ The machines seem pleased. I am afraid."
      }
    }
  }
}


-- 0.1.172 vanilla / Space Age / Quality research conversation expansion:
-- This pass adds broad topic families for base-game Factorio 2.x, Space Age,
-- Elevated Rails, and Quality technologies.  The exact alias table catches
-- well-known prototype names, while the classifier below catches numbered
-- research chains and future minor additions without forcing them into the
-- unknown-xenos fallback bucket.
function tech_priests_make_research_topic_0172(kind)
  local senior_ss = kind.senior_ss or ("__TECH_ICON__ The doctrine expands. Classify the new rite, trace its dependencies, and keep the factory from celebrating too early.")
  local senior_si = kind.senior_si or ("__TECH_ICON__ Integrate this technology cautiously. A new unlock is not permission to create belt spaghetti with witnesses.")
  local senior_sj = kind.senior_sj or ("__TECH_ICON__ A new rite has been sanctioned. Obey the station and do not improvise with sacred machinery.")
  local intermediate_is = kind.intermediate_is or ("__TECH_ICON__ Magos, the technology functions, though its practical limits deserve further inspection.")
  local intermediate_ii = kind.intermediate_ii or ("__TECH_ICON__ Another research bell, another chance for the factory to become clever in the worst possible way.")
  local intermediate_ij = kind.intermediate_ij or ("__TECH_ICON__ Follow the assigned procedure. If the new machine appears angry, report it before naming it.")
  local junior_js = kind.junior_js or ("__TECH_ICON__ Research acknowledged. Understanding absent. Obedience intact.")
  local junior_ji = kind.junior_ji or ("__TECH_ICON__ New doctrine acknowledged. Awaiting instruction.")
  local junior_jj = kind.junior_jj or ("__TECH_ICON__ The factory has learned. I remain loyal.")
  return {
    senior = {
      senior = { senior_ss, kind.senior_ss2 or senior_ss },
      intermediate = { senior_si, kind.senior_si2 or senior_si },
      junior = { senior_sj, kind.senior_sj2 or senior_sj }
    },
    intermediate = {
      senior = { intermediate_is, kind.intermediate_is2 or intermediate_is },
      intermediate = { intermediate_ii, kind.intermediate_ii2 or intermediate_ii },
      junior = { intermediate_ij, kind.intermediate_ij2 or intermediate_ij }
    },
    junior = {
      senior = { junior_js, kind.junior_js2 or junior_js },
      intermediate = { junior_ji, kind.junior_ji2 or junior_ji },
      junior = { junior_jj, kind.junior_jj2 or junior_jj }
    }
  }
end

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-machine-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Machine doctrine advances. The factory has received another organ, and therefore another way to develop symptoms.",
  senior_ss2 = "__TECH_ICON__ A new machine class demands placement discipline, supply discipline, and preferably fewer heroic assumptions.",
  senior_si = "__TECH_ICON__ Teach the new machine by inputs, outputs, and access lanes. Worship begins after the inserters can reach it.",
  senior_si2 = "__TECH_ICON__ Do not bolt the new machine into the line until maintenance access and power demand have been accounted for.",
  senior_sj = "__TECH_ICON__ A new machine has been authorized. Stand clear unless the Cogitator assigns you a wrench.",
  intermediate_is = "__TECH_ICON__ The new machine class is promising, Magos, though its footprint may punish careless layouts.",
  intermediate_is2 = "__TECH_ICON__ Should this machine be deployed centrally, or staged only where its specialized process is unavoidable?",
  intermediate_ii = "__TECH_ICON__ Another machine, another shape the factory now expects us to feed properly.",
  intermediate_ii2 = "__TECH_ICON__ I suggest reserving service corridors before the new machine turns maintenance into crawling penance.",
  intermediate_ij = "__TECH_ICON__ If assigned to the new machine, inspect the marked side and do not crawl underneath the moving parts.",
  junior_js = "__TECH_ICON__ New machine spirit detected. Awaiting safe distance.",
  junior_ji = "__TECH_ICON__ Machine expansion acknowledged. Curiosity suppressed.",
  junior_jj = "__TECH_ICON__ It has more parts than I have certainty."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-logistics-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Logistics doctrine expands. The belts may move faster, but so may the consequences.",
  senior_ss2 = "__TECH_ICON__ Every transport improvement is a blessing until someone uses it to move disorder at higher throughput.",
  senior_si = "__TECH_ICON__ Upgrade logistics in continuous lanes. Mixing old and new transport is how bottlenecks learn camouflage.",
  senior_si2 = "__TECH_ICON__ Inserter timing, belt capacity, and buffer discipline must advance together or the shrine merely circulates disappointment.",
  senior_sj = "__TECH_ICON__ Faster belts are not toys. Keep robes, hands, and theological optimism clear of the transport path.",
  intermediate_is = "__TECH_ICON__ The new logistics rite improves flow, Magos, but the old bottlenecks will migrate rather than repent.",
  intermediate_is2 = "__TECH_ICON__ Should upgrades begin at mines, science, or the most embarrassing starvation alarm?",
  intermediate_ii = "__TECH_ICON__ Logistics improved. This means the factory can now fail downstream with greater confidence.",
  intermediate_ii2 = "__TECH_ICON__ Watch the inserters. They always reveal where throughput doctrine has lied.",
  intermediate_ij = "__TECH_ICON__ Do not stand on the belt to contemplate motion. Motion will contemplate you back.",
  junior_js = "__TECH_ICON__ Transport rite acknowledged. Feet withdrawn.",
  junior_ji = "__TECH_ICON__ Throughput increased. Fear increased proportionally.",
  junior_jj = "__TECH_ICON__ The belts are faster. I will be slower near them."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-power-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Power doctrine advances. The factory has acquired more lightning, and with it more ways to blame brownouts on faith.",
  senior_ss2 = "__TECH_ICON__ Energy systems must be expanded before need becomes crisis. Darkness is a management report with sparks.",
  senior_si = "__TECH_ICON__ Teach the grid in margins: generation, storage, distribution, then load. Reverse that order only if you enjoy alarms.",
  senior_si2 = "__TECH_ICON__ Power poles and accumulators are not decoration. They are the nervous system of obedience.",
  senior_sj = "__TECH_ICON__ New power rite authorized. Do not touch live equipment unless your next prayer is scheduled.",
  intermediate_is = "__TECH_ICON__ The new power system should stabilize expansion, Magos, provided the grid was not already designed by a desperate artist.",
  intermediate_is2 = "__TECH_ICON__ Should we prioritize generation surplus or distribution redundancy first?",
  intermediate_ii = "__TECH_ICON__ More power means fewer brownouts and larger mistakes.",
  intermediate_ii2 = "__TECH_ICON__ Check the poles. The grid always confesses before the machines do.",
  intermediate_ij = "__TECH_ICON__ If it hums, stay respectful. If it arcs, stay elsewhere.",
  junior_js = "__TECH_ICON__ Lightning doctrine acknowledged. Touching forbidden.",
  junior_ji = "__TECH_ICON__ Grid reverence engaged.",
  junior_jj = "__TECH_ICON__ The wire sings. I will not join."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-fluid-chemistry-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Fluid and chemistry doctrine advances. The factory now moves sins through pipes instead of belts.",
  senior_ss2 = "__TECH_ICON__ A new chemical chain is an argument with pressure, temperature, and whoever forgot the pump.",
  senior_si = "__TECH_ICON__ Route fluids visibly, isolate hazardous intermediates, and never let petroleum doctrine become pipe spaghetti.",
  senior_si2 = "__TECH_ICON__ Buffer chemistry carefully. A full tank can be storage, blockage, or accusation.",
  senior_sj = "__TECH_ICON__ Do not drink, inhale, polish, bless, or taste-test the new fluid.",
  intermediate_is = "__TECH_ICON__ The process unlocks useful intermediates, Magos, but the pipe routing may become hostile.",
  intermediate_is2 = "__TECH_ICON__ Should production be buffered locally, or chained directly into downstream consumers?",
  intermediate_ii = "__TECH_ICON__ Chemistry is logistics after the belts gave up and became tubes.",
  intermediate_ii2 = "__TECH_ICON__ Every new tank is either foresight or a future deadlock with a nice gauge.",
  intermediate_ij = "__TECH_ICON__ Read the label. Then obey the label. Then stand upwind of the label.",
  junior_js = "__TECH_ICON__ Unknown fluid respected from distance.",
  junior_ji = "__TECH_ICON__ Pipe doctrine acknowledged. No tasting will occur.",
  junior_jj = "__TECH_ICON__ The liquid has purpose. I have distance."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-nuclear-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Nuclear doctrine advances. The factory has discovered a more radiant form of responsibility.",
  senior_ss2 = "__TECH_ICON__ Uranium is a sacred material in the same way a loaded reactor is a sacred warning.",
  senior_si = "__TECH_ICON__ Nuclear chains demand inventory accounting, heat discipline, and no improvisation from anyone glowing with confidence.",
  senior_si2 = "__TECH_ICON__ Separate fuel, waste, enrichment, and power doctrine or the ledger will become radioactive literature.",
  senior_sj = "__TECH_ICON__ If it glows, do not touch it. If ordered to carry it, carry it quickly and complain silently.",
  intermediate_is = "__TECH_ICON__ The nuclear chain is potent, Magos, but every buffer now has consequences measured in half-lives.",
  intermediate_is2 = "__TECH_ICON__ Should enriched material be stockpiled centrally or locked near reactor service lines?",
  intermediate_ii = "__TECH_ICON__ We have improved the factory by adding materials that punish forgetfulness for geological time.",
  intermediate_ii2 = "__TECH_ICON__ The centrifuges sound pleased. I dislike that.",
  intermediate_ij = "__TECH_ICON__ Do not hug the warm green rock. This is a complete instruction set.",
  junior_js = "__TECH_ICON__ Radiant doctrine acknowledged. Distance requested.",
  junior_ji = "__TECH_ICON__ Glowing material avoided unless ordered.",
  junior_jj = "__TECH_ICON__ It shines. I am afraid."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-robotics-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Robotics doctrine advances. The factory now delegates labor to flying obedience with battery anxiety.",
  senior_ss2 = "__TECH_ICON__ Robot swarms are excellent servants until the charging grid becomes a public confession.",
  senior_si = "__TECH_ICON__ Place roboports as infrastructure, not ornaments. Coverage, charge capacity, and storage must agree before bots are trusted.",
  senior_si2 = "__TECH_ICON__ Logistic and construction robots require boundaries or they will turn the factory into a cloud of errands.",
  senior_sj = "__TECH_ICON__ The flying servitors are not birds. Do not feed them. Do not chase them.",
  intermediate_is = "__TECH_ICON__ The robotic network increases flexibility, Magos, though recharge congestion may become the new bottleneck.",
  intermediate_is2 = "__TECH_ICON__ Should construction coverage follow defenses first, or production expansion?",
  intermediate_ii = "__TECH_ICON__ Robots solve distance by converting it into electricity and waiting lines.",
  intermediate_ii2 = "__TECH_ICON__ I trust the bots. I distrust whoever set the request amounts.",
  intermediate_ij = "__TECH_ICON__ If a robot takes an item, let it. The small flying thing has paperwork you do not.",
  junior_js = "__TECH_ICON__ Flying servitor doctrine acknowledged.",
  junior_ji = "__TECH_ICON__ I will not chase the robots.",
  junior_jj = "__TECH_ICON__ The little machines know where they go. I do not."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-rail-vehicle-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Transport doctrine enters the locomotive age. Throughput improves, and mistakes now arrive with momentum.",
  senior_ss2 = "__TECH_ICON__ Rails are not paths; they are promises that heavy objects will refuse to negotiate.",
  senior_si = "__TECH_ICON__ Signal the rails before expansion. Unsignaled confidence is just a train crash rehearsing.",
  senior_si2 = "__TECH_ICON__ Separate passenger vanity from freight doctrine. The ore does not care who feels inspired.",
  senior_sj = "__TECH_ICON__ Do not stand on rails. This is not metaphorical doctrine.",
  intermediate_is = "__TECH_ICON__ The transport upgrade is significant, Magos, but signaling discipline must precede scale.",
  intermediate_is2 = "__TECH_ICON__ Should the first rail spine serve ore, oil, or remote defensive resupply?",
  intermediate_ii = "__TECH_ICON__ Trains make logistics elegant by making negligence extremely loud.",
  intermediate_ii2 = "__TECH_ICON__ A rail network is a belt that can kill you from farther away.",
  intermediate_ij = "__TECH_ICON__ If the signal is red, stop. If the train is near, stop existing there.",
  junior_js = "__TECH_ICON__ Rail doctrine acknowledged. Track avoided.",
  junior_ji = "__TECH_ICON__ Locomotive fear installed.",
  junior_jj = "__TECH_ICON__ The iron road is hungry."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["vanilla-space-platform-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Space platform doctrine advances. The factory is no longer content to offend one planet at a time.",
  senior_ss2 = "__TECH_ICON__ Orbital industry requires closed loops, disciplined logistics, and fewer assumptions about gravity doing free work.",
  senior_si = "__TECH_ICON__ Treat platforms as factories with no forgiveness below them. Every missing input becomes an orbital sermon.",
  senior_si2 = "__TECH_ICON__ Thrusters, collectors, ammo, and power must be planned as one organism or the void will audit us.",
  senior_sj = "__TECH_ICON__ Space machinery is above your rank and frequently above your head. Obey markings.",
  intermediate_is = "__TECH_ICON__ Orbital doctrine is viable, Magos, but each shortage becomes more expensive once launched.",
  intermediate_is2 = "__TECH_ICON__ Should platform supply buffers prioritize ammo, fuel, repair, or asteroid processing?",
  intermediate_ii = "__TECH_ICON__ A space platform is just a factory that can drift away from its excuses.",
  intermediate_ii2 = "__TECH_ICON__ The void contains no spare belts. This seems important.",
  intermediate_ij = "__TECH_ICON__ If assigned to platform machinery, tether your curiosity and follow the marked task.",
  junior_js = "__TECH_ICON__ Orbital doctrine acknowledged. Falling avoided where possible.",
  junior_ji = "__TECH_ICON__ The sky factory frightens me usefully.",
  junior_jj = "__TECH_ICON__ The factory goes up now. I was not consulted."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-asteroid-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Asteroid doctrine advances. The void has become a quarry, which is exactly as sensible as it sounds.",
  senior_ss2 = "__TECH_ICON__ Processing rocks in space rewards planning and punishes the assumption that debris is passive.",
  senior_si = "__TECH_ICON__ Balance collectors, crushers, storage, and ammunition. A platform starving for ammo is not mining; it is waiting to be geology.",
  senior_si2 = "__TECH_ICON__ Reprocessing is useful only if the output streams are disciplined before they become orbital clutter.",
  senior_sj = "__TECH_ICON__ Do not stand beneath falling space rocks. Yes, this required documentation.",
  intermediate_is = "__TECH_ICON__ The asteroid chain expands resource autonomy, Magos, but storage priority may determine survival.",
  intermediate_is2 = "__TECH_ICON__ Should excess asteroid chunks be buffered or immediately crushed into usable doctrine?",
  intermediate_ii = "__TECH_ICON__ We mine the sky now. The sky has responded with shrapnel.",
  intermediate_ii2 = "__TECH_ICON__ I recommend ammo before optimism.",
  intermediate_ij = "__TECH_ICON__ If a rock arrives from space, do not greet it personally.",
  junior_js = "__TECH_ICON__ Sky-rock doctrine acknowledged.",
  junior_ji = "__TECH_ICON__ Incoming geology feared.",
  junior_jj = "__TECH_ICON__ The rocks are above us. This is wrong."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-planet-discovery-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Planetary discovery expands the sacred map. The factory has found a new world to disappoint carefully.",
  senior_ss2 = "__TECH_ICON__ A planet is not a destination. It is a hostile logistics problem with scenery.",
  senior_si = "__TECH_ICON__ Prepare remote supply, power doctrine, and return logistics before celebrating the new planet.",
  senior_si2 = "__TECH_ICON__ Each world has different sins. Catalogue them before building over them.",
  senior_sj = "__TECH_ICON__ A new planet has been named. Do not volunteer for landing by falling.",
  intermediate_is = "__TECH_ICON__ The discovery is promising, Magos, though remote production chains may need independent doctrine.",
  intermediate_is2 = "__TECH_ICON__ Should first deployment prioritize science, resources, or survivable infrastructure?",
  intermediate_ii = "__TECH_ICON__ We found another planet. Management will interpret this as permission.",
  intermediate_ii2 = "__TECH_ICON__ New world, new hazards, same missing spare parts.",
  intermediate_ij = "__TECH_ICON__ If sent off-world, obey local doctrine and avoid becoming a landmark.",
  junior_js = "__TECH_ICON__ New world acknowledged. Fear packed.",
  junior_ji = "__TECH_ICON__ Planetary obedience prepared.",
  junior_jj = "__TECH_ICON__ There are more planets? Unsettling."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-vulcanus-metallurgy-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Vulcanus metallurgy advances. The planet offers fire, stone, and large worms with territorial opinions.",
  senior_ss2 = "__TECH_ICON__ Foundry doctrine is magnificent, provided lava and arrogance are not routed through the same plan.",
  senior_si = "__TECH_ICON__ Use foundries and tungsten chains deliberately. Vulcanus rewards heavy industry and punishes casual footprints.",
  senior_si2 = "__TECH_ICON__ Treat demolisher territory as a planning constraint, not a motivational poster.",
  senior_sj = "__TECH_ICON__ If the ground shakes, stop arguing with it and move.",
  intermediate_is = "__TECH_ICON__ Metallurgy output is excellent, Magos, but local extraction may require defensive humility.",
  intermediate_is2 = "__TECH_ICON__ Should foundry production be exported, or should Vulcanus become a primary industrial shrine?",
  intermediate_ii = "__TECH_ICON__ Lava processing is efficient, which is nature's way of hiding the bill.",
  intermediate_ii2 = "__TECH_ICON__ The rocks are hot, the worms are large, and the factory wants more steel.",
  intermediate_ij = "__TECH_ICON__ Do not pet the lava. Do not reason with the worm.",
  junior_js = "__TECH_ICON__ Fire planet doctrine acknowledged.",
  junior_ji = "__TECH_ICON__ Lava avoided. Worms avoided harder.",
  junior_jj = "__TECH_ICON__ The floor is angry."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-fulgora-electromagnetic-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Fulgoran doctrine advances. We now loot dead civilization with electrical supervision.",
  senior_ss2 = "__TECH_ICON__ Scrap, holmium, and lightning: a complete curriculum in why ruins should not be trusted.",
  senior_si = "__TECH_ICON__ Sort scrap rigorously, ground the grid, and treat electromagnetic plants as strategic organs rather than shiny indulgence.",
  senior_si2 = "__TECH_ICON__ Fulgora converts archaeology into production. Keep the recycler from becoming a theology of garbage.",
  senior_sj = "__TECH_ICON__ Do not stand in lightning. Do not salute the ruins. Do not steal anything with teeth.",
  intermediate_is = "__TECH_ICON__ The electromagnetic chain is powerful, Magos, though scrap variance complicates clean planning.",
  intermediate_is2 = "__TECH_ICON__ Should recycler output be sorted centrally or near the mining fields?",
  intermediate_ii = "__TECH_ICON__ We are manufacturing from trash on a thunder planet. This feels like doctrine written during a budget meeting.",
  intermediate_ii2 = "__TECH_ICON__ The ruins are productive, which makes me wonder what killed the previous management.",
  intermediate_ij = "__TECH_ICON__ If lightning begins nearby, your task is to not be nearby.",
  junior_js = "__TECH_ICON__ Thunder-scrap doctrine acknowledged.",
  junior_ji = "__TECH_ICON__ Ruin salvage respected. Lightning feared.",
  junior_jj = "__TECH_ICON__ The garbage has secrets."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-gleba-biology-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Gleba biology advances. The factory now argues with spoilage, nutrients, and meat that learned logistics.",
  senior_ss2 = "__TECH_ICON__ Biological industry is productive, temporary, and smug about both facts.",
  senior_si = "__TECH_ICON__ Design Gleba chains around time. Spoilage is not waste; it is the clock filing a complaint.",
  senior_si2 = "__TECH_ICON__ Nutrients, bioflux, soil, and eggs must be staged with decay in mind, not sentimental storage habits.",
  senior_sj = "__TECH_ICON__ Do not eat the science. Do not trust the egg. Do not insult the plant where it can hear you.",
  intermediate_is = "__TECH_ICON__ The biological chain functions, Magos, but timing errors propagate faster than belts can confess.",
  intermediate_is2 = "__TECH_ICON__ Should fresh inputs be overproduced continuously, or pulse-fed to reduce spoilage?",
  intermediate_ii = "__TECH_ICON__ Gleba teaches that the factory can rot while still technically operating.",
  intermediate_ii2 = "__TECH_ICON__ I miss ores. Ores do not expire out of spite.",
  intermediate_ij = "__TECH_ICON__ If it moves, spoils, hatches, or smells purposeful, report it.",
  junior_js = "__TECH_ICON__ Wet doctrine acknowledged. Appetite disabled.",
  junior_ji = "__TECH_ICON__ Egg suspicion engaged.",
  junior_jj = "__TECH_ICON__ The plants are watching."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["space-age-aquilo-cryogenics-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Aquilo doctrine advances. Industry now freezes if neglected, which is at least honest.",
  senior_ss2 = "__TECH_ICON__ Cryogenic chains demand heat discipline, ammonia respect, and infrastructure that does not sulk into ice.",
  senior_si = "__TECH_ICON__ Plan heat first. A frozen machine is not idle; it is judging the entire command structure.",
  senior_si2 = "__TECH_ICON__ Lithium, fluoroketone, ammonia, and cryogenic science must be routed as survival systems, not mere production lines.",
  senior_sj = "__TECH_ICON__ If the machine is frozen, do not warm it with your face.",
  intermediate_is = "__TECH_ICON__ The cryogenic chain is viable, Magos, but heat coverage will decide whether doctrine becomes ice sculpture.",
  intermediate_is2 = "__TECH_ICON__ Should heating infrastructure be overbuilt before production, or expanded with each block?",
  intermediate_ii = "__TECH_ICON__ Aquilo is a factory where warmth is a consumable and optimism is brittle.",
  intermediate_ii2 = "__TECH_ICON__ I recommend heat pipes before heroics.",
  intermediate_ij = "__TECH_ICON__ Stay near marked heat zones. Frostbite is not a rite of promotion.",
  junior_js = "__TECH_ICON__ Frozen doctrine acknowledged. Shivering contained.",
  junior_ji = "__TECH_ICON__ Heat zone respected.",
  junior_jj = "__TECH_ICON__ The cold has authority."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["quality-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Quality doctrine advances. The factory has discovered vertical improvement, gambling, and disappointment with statistics.",
  senior_ss2 = "__TECH_ICON__ Higher quality is sacred variance disciplined into utility, assuming the recycler does not become a slot machine altar.",
  senior_si = "__TECH_ICON__ Use quality where fewer, better machines matter. Do not sprinkle modules everywhere and call probability a plan.",
  senior_si2 = "__TECH_ICON__ Epic and legendary outcomes require serious sorting doctrine, or the factory will drown in almost-excellent clutter.",
  senior_sj = "__TECH_ICON__ If an item shines differently, do not keep it as a personal relic.",
  intermediate_is = "__TECH_ICON__ Quality improves compact designs, Magos, but storage filters will decide whether it is miracle or landfill.",
  intermediate_is2 = "__TECH_ICON__ Should quality loops be isolated from normal production to prevent inventory contamination?",
  intermediate_ii = "__TECH_ICON__ Quality is when the factory prays to probability and demands receipts.",
  intermediate_ii2 = "__TECH_ICON__ I recommend separate chests before rare gears start forming a cult.",
  intermediate_ij = "__TECH_ICON__ Sort by mark. Do not mix the blessed cog with the ordinary cog unless ordered.",
  junior_js = "__TECH_ICON__ Quality mark acknowledged. Hoarding forbidden.",
  junior_ji = "__TECH_ICON__ Shiny item respected. Personal collection denied.",
  junior_jj = "__TECH_ICON__ Some parts are holier than others."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["module-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Module doctrine advances. We may now alter machine behavior by installing concentrated bad ideas in expensive slots.",
  senior_ss2 = "__TECH_ICON__ Speed, productivity, efficiency, and quality are not virtues. They are tradeoffs wearing icons.",
  senior_si = "__TECH_ICON__ Teach modules by consequence: power, pollution, speed, output, and statistical contamination all matter.",
  senior_si2 = "__TECH_ICON__ Beacons amplify doctrine and mistakes equally. Place them with the fear they deserve.",
  senior_sj = "__TECH_ICON__ Do not insert modules randomly. The machine does not need surprise theology.",
  intermediate_is = "__TECH_ICON__ The module suite expands options, Magos, but mixed effects may complicate debugging.",
  intermediate_is2 = "__TECH_ICON__ Should modules be standardized per block, or tuned per bottleneck?",
  intermediate_ii = "__TECH_ICON__ Modules let us pay electricity to move problems between columns on a spreadsheet.",
  intermediate_ii2 = "__TECH_ICON__ Productivity modules are powerful. They also make every machine breathe smoke like a guilty dragon.",
  intermediate_ij = "__TECH_ICON__ Insert only the specified module. If the slot glows, that is not consent.",
  junior_js = "__TECH_ICON__ Module doctrine acknowledged. Slots untouched.",
  junior_ji = "__TECH_ICON__ No random insertion will occur.",
  junior_jj = "__TECH_ICON__ The square thing changes the big thing. Terrifying."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["combat-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Martial doctrine advances. The factory has improved its ability to turn disagreement into inventory demand.",
  senior_ss2 = "__TECH_ICON__ Weapon research is logistics with explosions at the far end.",
  senior_si = "__TECH_ICON__ Match weapon upgrades to ammunition supply, target profile, and defensive reach. Damage without supply is theatre.",
  senior_si2 = "__TECH_ICON__ Do not celebrate firepower until reload, range, and repair doctrine can survive contact.",
  senior_sj = "__TECH_ICON__ A weapon is not a devotional instrument. Point it away from allies and doubts.",
  intermediate_is = "__TECH_ICON__ The new weapon rite improves survival, Magos, though ammunition throughput may become the true enemy.",
  intermediate_is2 = "__TECH_ICON__ Should defensive upgrades prioritize perimeter turrets, platform weapons, or mobile response?",
  intermediate_ii = "__TECH_ICON__ The factory has become deadlier. I assume this is to protect the parts that remain stupid.",
  intermediate_ii2 = "__TECH_ICON__ More damage only helps if the ammo train arrives before the sermon ends.",
  intermediate_ij = "__TECH_ICON__ Do not test the weapon indoors unless the indoors are already lost.",
  junior_js = "__TECH_ICON__ Martial doctrine acknowledged. Trigger discipline uncertain but obedient.",
  junior_ji = "__TECH_ICON__ Weapon respected. Barrel avoided.",
  junior_jj = "__TECH_ICON__ The loud tool is now louder."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["defense-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Defensive doctrine advances. Walls, turrets, armor, and radar are the factory admitting the planet has opinions.",
  senior_ss2 = "__TECH_ICON__ A defense line without repair supply is merely a delay with architecture.",
  senior_si = "__TECH_ICON__ Build defenses as maintained systems: ammo, power, radar coverage, walls, repair access, and retreat paths.",
  senior_si2 = "__TECH_ICON__ Armor protects the worker; fortifications protect the mistake that placed the worker there.",
  senior_sj = "__TECH_ICON__ Stand behind the wall. This is why the wall was invented.",
  intermediate_is = "__TECH_ICON__ The defense upgrade is sound, Magos, but maintenance corridors must not be forgotten.",
  intermediate_is2 = "__TECH_ICON__ Should new defenses reinforce existing perimeters or secure expansion corridors?",
  intermediate_ii = "__TECH_ICON__ A wall is a boundary between production and consequences. Keep it repaired.",
  intermediate_ii2 = "__TECH_ICON__ Radar sees trouble early so management can ignore it with better data.",
  intermediate_ij = "__TECH_ICON__ If repairing defenses under attack, do not stand where the wall used to be.",
  junior_js = "__TECH_ICON__ Defensive doctrine acknowledged. Wall preferred.",
  junior_ji = "__TECH_ICON__ Standing behind protection.",
  junior_jj = "__TECH_ICON__ The outside wants in."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["personal-equipment-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Personal equipment doctrine advances. The engineer has become a walking grid with opinions.",
  senior_ss2 = "__TECH_ICON__ Armor modules improve survival, mobility, and the likelihood of overconfidence.",
  senior_si = "__TECH_ICON__ Balance personal equipment by mission: shields for risk, batteries for endurance, movement for response, roboports for field work.",
  senior_si2 = "__TECH_ICON__ A personal grid is not a junk drawer. Every slot must justify its electricity.",
  senior_sj = "__TECH_ICON__ Do not borrow the armor. It contains more authority than you.",
  intermediate_is = "__TECH_ICON__ The equipment grid is useful, Magos, though power budget may constrain ambitious layouts.",
  intermediate_is2 = "__TECH_ICON__ Should the engineer favor mobility or defensive uptime for the current theater?",
  intermediate_ii = "__TECH_ICON__ The suit now has more systems than some outposts and fewer labels than I prefer.",
  intermediate_ii2 = "__TECH_ICON__ Personal lasers are convenient until they decide diplomacy is over.",
  intermediate_ij = "__TECH_ICON__ If the armor sparks, report it. Do not climb inside to understand.",
  junior_js = "__TECH_ICON__ Augmentation doctrine acknowledged. Armor untouched.",
  junior_ji = "__TECH_ICON__ Equipment grid respected from outside.",
  junior_jj = "__TECH_ICON__ The suit has a factory in it."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["productivity-research-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Productivity doctrine advances. The factory now extracts more output from the same suffering.",
  senior_ss2 = "__TECH_ICON__ Infinite research is not progress; it is obsession with a science-pack receipt.",
  senior_si = "__TECH_ICON__ Apply productivity gains where they compound through the chain. Do not worship percentages divorced from throughput.",
  senior_si2 = "__TECH_ICON__ Research productivity, mining productivity, and recipe productivity all demand larger science and logistics backbones.",
  senior_sj = "__TECH_ICON__ More output is authorized. Do not ask where the extra material hides before becoming real.",
  intermediate_is = "__TECH_ICON__ The bonus is valuable, Magos, though science consumption may become the new altar of pain.",
  intermediate_is2 = "__TECH_ICON__ Should further research continue here, or should production expand before the next level?",
  intermediate_ii = "__TECH_ICON__ Productivity research makes the factory more efficient by making the laboratories hungrier.",
  intermediate_ii2 = "__TECH_ICON__ Infinite research is a treadmill with better lighting.",
  intermediate_ij = "__TECH_ICON__ The percentage improved. Your instructions did not.",
  junior_js = "__TECH_ICON__ Productivity blessing acknowledged.",
  junior_ji = "__TECH_ICON__ More from same accepted as miracle.",
  junior_jj = "__TECH_ICON__ The numbers grew. I did not."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["science-pack-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Science doctrine advances. The factory has invented a new color of expensive curiosity.",
  senior_ss2 = "__TECH_ICON__ Every science pack is a compact ritual: resources enter, certainty exits, belts suffer.",
  senior_si = "__TECH_ICON__ Stabilize each science chain before demanding the next. Laboratories are bottomless mouths with progress bars.",
  senior_si2 = "__TECH_ICON__ New science unlocks new doctrine, and new doctrine unlocks new ways to starve old doctrine.",
  senior_sj = "__TECH_ICON__ If the flask is not assigned to you, do not shake it, drink it, or call it pretty.",
  intermediate_is = "__TECH_ICON__ The new science tier expands research velocity, Magos, assuming its inputs do not become permanent grievances.",
  intermediate_is2 = "__TECH_ICON__ Should science production be ratio-perfect or overbuilt with honest brute force?",
  intermediate_ii = "__TECH_ICON__ Another science pack means another production chain pretending it is education.",
  intermediate_ii2 = "__TECH_ICON__ The labs consume knowledge in bottle form. This remains unsettling.",
  intermediate_ij = "__TECH_ICON__ Carry flasks only as instructed. Spilled research is just expensive floor color.",
  junior_js = "__TECH_ICON__ Science color acknowledged.",
  junior_ji = "__TECH_ICON__ Flask reverence engaged.",
  junior_jj = "__TECH_ICON__ The liquid knows things."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["circuit-combinator-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Circuit doctrine advances. The factory may now make decisions, which is brave considering who wired it.",
  senior_ss2 = "__TECH_ICON__ Signals are pure until translated by an engineer with three colors of wire and insufficient shame.",
  senior_si = "__TECH_ICON__ Label circuits, isolate control domains, and never let cleverness replace readable failure modes.",
  senior_si2 = "__TECH_ICON__ A combinator network should explain itself before it is allowed to control anything expensive.",
  senior_sj = "__TECH_ICON__ Do not cross the red wire with the green wire unless the Cogitator explicitly demands comedy.",
  intermediate_is = "__TECH_ICON__ The signal system is powerful, Magos, but debugging may require liturgical patience.",
  intermediate_is2 = "__TECH_ICON__ Should control logic be centralized or kept near the machines it governs?",
  intermediate_ii = "__TECH_ICON__ Circuits let the factory be wrong automatically.",
  intermediate_ii2 = "__TECH_ICON__ The lamps blinked in pattern. I refuse to call that consent.",
  intermediate_ij = "__TECH_ICON__ If a wire is colored, assume it knows more than you and less than it claims.",
  junior_js = "__TECH_ICON__ Signal doctrine acknowledged. Wire untouched.",
  junior_ji = "__TECH_ICON__ Blinking light respected.",
  junior_jj = "__TECH_ICON__ The wire thinks. Horrible."
})

TECH_PRIESTS_CONVERSATION_LINES_0167["terrain-infrastructure-doctrine"] = tech_priests_make_research_topic_0172({
  senior_ss = "__TECH_ICON__ Infrastructure doctrine advances. We may now discipline terrain until the planet resembles a spreadsheet.",
  senior_ss2 = "__TECH_ICON__ Concrete, landfill, foundations, and lamps are civilization's way of telling mud to stop participating.",
  senior_si = "__TECH_ICON__ Use infrastructure to support movement, maintenance, rail, and platform expansion. Pretty floors are secondary heresy.",
  senior_si2 = "__TECH_ICON__ Clear cliffs, bridge gaps, light corridors, and leave access for the priests who must repair your confidence.",
  senior_sj = "__TECH_ICON__ If the ground has been improved, try not to immediately stand in the unimproved part.",
  intermediate_is = "__TECH_ICON__ The infrastructure unlock is useful, Magos, though paving may conceal old layout sins.",
  intermediate_is2 = "__TECH_ICON__ Should we prioritize main bus movement, defensive roads, or platform foundations?",
  intermediate_ii = "__TECH_ICON__ We can pave the factory now. It will make the mistakes look official.",
  intermediate_ii2 = "__TECH_ICON__ Lighting reduces accidents and reveals how many there still are.",
  intermediate_ij = "__TECH_ICON__ Walk on the marked path. It exists because someone failed without it.",
  junior_js = "__TECH_ICON__ Improved ground acknowledged.",
  junior_ji = "__TECH_ICON__ Marked path obeyed.",
  junior_jj = "__TECH_ICON__ The floor has doctrine now."
})

TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172 = {
  -- Core machines and production
  ["advanced-circuit"] = "vanilla-machine-doctrine", ["automation"] = "vanilla-machine-doctrine", ["automation-2"] = "vanilla-machine-doctrine", ["automation-3"] = "vanilla-machine-doctrine", ["electric-mining-drill"] = "vanilla-machine-doctrine", ["fast-inserter"] = "vanilla-logistics-doctrine", ["stack-inserter"] = "vanilla-logistics-doctrine", ["bulk-inserter"] = "vanilla-logistics-doctrine", ["processing-unit"] = "vanilla-machine-doctrine", ["rocket-silo"] = "vanilla-space-platform-doctrine", ["biolab"] = "vanilla-machine-doctrine",
  ["steam-power"] = "vanilla-power-doctrine", ["solar-energy"] = "vanilla-power-doctrine", ["electric-energy-accumulators"] = "vanilla-power-doctrine", ["electric-energy-distribution-1"] = "vanilla-power-doctrine", ["electric-energy-distribution-2"] = "vanilla-power-doctrine", ["fusion-reactor"] = "vanilla-power-doctrine", ["lightning-collector"] = "vanilla-power-doctrine",
  ["logistics"] = "vanilla-logistics-doctrine", ["logistics-2"] = "vanilla-logistics-doctrine", ["logistics-3"] = "vanilla-logistics-doctrine", ["transport-belt-capacity-1"] = "vanilla-logistics-doctrine", ["transport-belt-capacity-2"] = "vanilla-logistics-doctrine", ["turbo-transport-belt"] = "vanilla-logistics-doctrine", ["inserter-capacity-bonus-1"] = "vanilla-logistics-doctrine",
  ["fluid-handling"] = "vanilla-fluid-chemistry-doctrine", ["oil-gathering"] = "vanilla-fluid-chemistry-doctrine", ["oil-processing"] = "vanilla-fluid-chemistry-doctrine", ["advanced-oil-processing"] = "vanilla-fluid-chemistry-doctrine", ["coal-liquefaction"] = "vanilla-fluid-chemistry-doctrine", ["sulfur-processing"] = "vanilla-fluid-chemistry-doctrine", ["plastics"] = "vanilla-fluid-chemistry-doctrine", ["lubricant"] = "vanilla-fluid-chemistry-doctrine", ["battery"] = "vanilla-fluid-chemistry-doctrine", ["explosives"] = "vanilla-fluid-chemistry-doctrine", ["flammables"] = "vanilla-fluid-chemistry-doctrine", ["laser"] = "vanilla-fluid-chemistry-doctrine", ["low-density-structure"] = "general-material-doctrine", ["steel-processing"] = "general-material-doctrine", ["advanced-material-processing"] = "general-material-doctrine", ["advanced-material-processing-2"] = "general-material-doctrine",
  ["uranium-mining"] = "vanilla-nuclear-doctrine", ["uranium-processing"] = "vanilla-nuclear-doctrine", ["nuclear-power"] = "vanilla-nuclear-doctrine", ["kovarex-enrichment-process"] = "vanilla-nuclear-doctrine", ["nuclear-fuel-reprocessing"] = "vanilla-nuclear-doctrine", ["uranium-ammo"] = "vanilla-nuclear-doctrine",
  ["robotics"] = "vanilla-robotics-doctrine", ["construction-robotics"] = "vanilla-robotics-doctrine", ["logistic-robotics"] = "vanilla-robotics-doctrine", ["logistic-system"] = "vanilla-robotics-doctrine", ["worker-robot-speed-1"] = "vanilla-robotics-doctrine", ["worker-robot-cargo-size-1"] = "vanilla-robotics-doctrine", ["follower-robot-count-1"] = "combat-doctrine",
  ["railway"] = "vanilla-rail-vehicle-doctrine", ["automated-rail-transportation"] = "vanilla-rail-vehicle-doctrine", ["automobilism"] = "vanilla-rail-vehicle-doctrine", ["fluid-wagon"] = "vanilla-rail-vehicle-doctrine", ["braking-force-1"] = "vanilla-rail-vehicle-doctrine", ["tank"] = "vanilla-rail-vehicle-doctrine", ["spidertron"] = "vanilla-rail-vehicle-doctrine", ["elevated-rail"] = "vanilla-rail-vehicle-doctrine", ["rail-support-foundations"] = "vanilla-rail-vehicle-doctrine",
  -- Space Age machines, planets, resources, and sciences
  ["space-platform"] = "vanilla-space-platform-doctrine", ["space-platform-thruster"] = "vanilla-space-platform-doctrine", ["space-science-pack"] = "science-pack-doctrine", ["advanced-asteroid-processing"] = "space-age-asteroid-doctrine", ["asteroid-reprocessing"] = "space-age-asteroid-doctrine", ["asteroid-productivity"] = "space-age-asteroid-doctrine", ["rocket-part-productivity"] = "productivity-research-doctrine",
  ["planet-discovery-vulcanus"] = "space-age-planet-discovery-doctrine", ["planet-discovery-fulgora"] = "space-age-planet-discovery-doctrine", ["planet-discovery-gleba"] = "space-age-planet-discovery-doctrine", ["planet-discovery-aquilo"] = "space-age-planet-discovery-doctrine",
  ["tungsten-carbide"] = "space-age-vulcanus-metallurgy-doctrine", ["calcite-processing"] = "space-age-vulcanus-metallurgy-doctrine", ["foundry"] = "space-age-vulcanus-metallurgy-doctrine", ["big-mining-drill"] = "space-age-vulcanus-metallurgy-doctrine", ["tungsten-steel"] = "space-age-vulcanus-metallurgy-doctrine", ["metallurgic-science-pack"] = "science-pack-doctrine",
  ["recycling"] = "space-age-fulgora-electromagnetic-doctrine", ["holmium-processing"] = "space-age-fulgora-electromagnetic-doctrine", ["electromagnetic-plant"] = "space-age-fulgora-electromagnetic-doctrine", ["electromagnetic-science-pack"] = "science-pack-doctrine", ["supercapacitor"] = "space-age-fulgora-electromagnetic-doctrine", ["scrap-recycling-productivity"] = "productivity-research-doctrine",
  ["jellynut"] = "space-age-gleba-biology-doctrine", ["yumako"] = "space-age-gleba-biology-doctrine", ["heating-tower"] = "space-age-gleba-biology-doctrine", ["agriculture"] = "space-age-gleba-biology-doctrine", ["biochamber"] = "space-age-gleba-biology-doctrine", ["artificial-soil"] = "space-age-gleba-biology-doctrine", ["overgrowth-soil"] = "space-age-gleba-biology-doctrine", ["bioflux"] = "space-age-gleba-biology-doctrine", ["bacteria-cultivation"] = "space-age-gleba-biology-doctrine", ["bioflux-processing"] = "space-age-gleba-biology-doctrine", ["agricultural-science-pack"] = "science-pack-doctrine", ["fish-breeding"] = "space-age-gleba-biology-doctrine", ["tree-seeding"] = "space-age-gleba-biology-doctrine", ["biter-egg-handling"] = "space-age-gleba-biology-doctrine", ["captivity"] = "space-age-gleba-biology-doctrine", ["captive-biter-spawner"] = "space-age-gleba-biology-doctrine", ["carbon-fiber"] = "space-age-gleba-biology-doctrine",
  ["lithium-processing"] = "space-age-aquilo-cryogenics-doctrine", ["cryogenic-plant"] = "space-age-aquilo-cryogenics-doctrine", ["cryogenic-science-pack"] = "science-pack-doctrine", ["quantum-processor"] = "space-age-aquilo-cryogenics-doctrine", ["foundation"] = "terrain-infrastructure-doctrine", ["promethium-science-pack"] = "science-pack-doctrine",
  -- Quality, modules, and equipment
  ["quality-module"] = "quality-doctrine", ["quality-module-2"] = "quality-doctrine", ["quality-module-3"] = "quality-doctrine", ["epic-quality"] = "quality-doctrine", ["legendary-quality"] = "quality-doctrine",
  ["modules"] = "module-doctrine", ["effect-transmission"] = "module-doctrine", ["speed-module"] = "module-doctrine", ["speed-module-2"] = "module-doctrine", ["speed-module-3"] = "module-doctrine", ["productivity-module"] = "module-doctrine", ["productivity-module-2"] = "module-doctrine", ["productivity-module-3"] = "module-doctrine", ["efficiency-module"] = "module-doctrine", ["efficiency-module-2"] = "module-doctrine", ["efficiency-module-3"] = "module-doctrine",
  ["belt-immunity-equipment"] = "personal-equipment-doctrine", ["discharge-defense-equipment"] = "personal-equipment-doctrine", ["energy-shield-equipment"] = "personal-equipment-doctrine", ["energy-shield-mk2-equipment"] = "personal-equipment-doctrine", ["exoskeleton-equipment"] = "personal-equipment-doctrine", ["night-vision-equipment"] = "personal-equipment-doctrine", ["battery-equipment"] = "personal-equipment-doctrine", ["battery-mk2-equipment"] = "personal-equipment-doctrine", ["battery-mk3-equipment"] = "personal-equipment-doctrine", ["personal-laser-defense-equipment"] = "personal-equipment-doctrine", ["personal-roboport-equipment"] = "personal-equipment-doctrine", ["personal-roboport-mk2-equipment"] = "personal-equipment-doctrine", ["fission-reactor-equipment"] = "personal-equipment-doctrine", ["fusion-reactor-equipment"] = "personal-equipment-doctrine", ["solar-panel-equipment"] = "personal-equipment-doctrine", ["toolbelt-equipment"] = "personal-equipment-doctrine", ["modular-armor"] = "personal-equipment-doctrine", ["power-armor"] = "personal-equipment-doctrine", ["power-armor-mk2"] = "personal-equipment-doctrine", ["mech-armor"] = "personal-equipment-doctrine", ["heavy-armor"] = "personal-equipment-doctrine", ["health"] = "personal-equipment-doctrine", ["steel-axe"] = "personal-equipment-doctrine", ["toolbelt"] = "personal-equipment-doctrine",
  -- Military and defense
  ["military"] = "combat-doctrine", ["military-2"] = "combat-doctrine", ["military-3"] = "combat-doctrine", ["military-4"] = "combat-doctrine", ["gun-turret"] = "defense-doctrine", ["stone-wall"] = "defense-doctrine", ["gate"] = "defense-doctrine", ["laser-turret"] = "defense-doctrine", ["flamethrower"] = "combat-doctrine", ["land-mine"] = "defense-doctrine", ["rocketry"] = "combat-doctrine", ["explosive-rocketry"] = "combat-doctrine", ["atomic-bomb"] = "combat-doctrine", ["artillery"] = "defense-doctrine", ["rocket-turret"] = "defense-doctrine", ["tesla-weapons"] = "combat-doctrine", ["railgun"] = "combat-doctrine", ["defender"] = "combat-doctrine", ["distractor"] = "combat-doctrine", ["destroyer"] = "combat-doctrine", ["physical-projectile-damage-1"] = "combat-doctrine", ["weapon-shooting-speed-1"] = "combat-doctrine", ["laser-shooting-speed-1"] = "combat-doctrine", ["energy-weapons-damage-1"] = "combat-doctrine", ["laser-weapons-damage-1"] = "combat-doctrine", ["electric-weapons-damage-1"] = "combat-doctrine", ["stronger-explosives-1"] = "combat-doctrine", ["refined-flammables-1"] = "combat-doctrine", ["artillery-shell-range-1"] = "defense-doctrine", ["artillery-shell-shooting-speed-1"] = "defense-doctrine", ["artillery-shell-damage-1"] = "defense-doctrine", ["railgun-damage-1"] = "combat-doctrine", ["railgun-shooting-speed-1"] = "combat-doctrine", ["radar"] = "defense-doctrine", ["repair-pack"] = "defense-doctrine",
  -- Science, circuits, terrain, bonuses
  ["automation-science-pack"] = "science-pack-doctrine", ["logistic-science-pack"] = "science-pack-doctrine", ["military-science-pack"] = "science-pack-doctrine", ["chemical-science-pack"] = "science-pack-doctrine", ["production-science-pack"] = "science-pack-doctrine", ["utility-science-pack"] = "science-pack-doctrine",
  ["electronics"] = "circuit-combinator-doctrine", ["circuit-network"] = "circuit-combinator-doctrine", ["advanced-combinators"] = "circuit-combinator-doctrine", ["lamp"] = "terrain-infrastructure-doctrine",
  ["concrete"] = "terrain-infrastructure-doctrine", ["landfill"] = "terrain-infrastructure-doctrine", ["cliff-explosives"] = "terrain-infrastructure-doctrine",
  ["mining-productivity-1"] = "productivity-research-doctrine", ["research-productivity"] = "productivity-research-doctrine", ["lab-research-speed-1"] = "productivity-research-doctrine", ["steel-plate-productivity"] = "productivity-research-doctrine", ["low-density-structure-productivity"] = "productivity-research-doctrine", ["processing-unit-productivity"] = "productivity-research-doctrine", ["plastic-bar-productivity"] = "productivity-research-doctrine", ["rocket-fuel-productivity"] = "productivity-research-doctrine", ["rocket-fuel"] = "vanilla-fluid-chemistry-doctrine"
}

function tech_priests_strip_numeric_research_suffix_0172(name)
  name = tostring(name or "")
  return (string.gsub(name, "%-%d+$", ""))
end

function tech_priests_classify_known_research_topic_0172(tech_name)
  if not tech_name or tech_name == "" then return nil end
  local name = string.lower(tostring(tech_name))
  local base = tech_priests_strip_numeric_research_suffix_0172(name)
  if TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172[name] then return TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172[name] end
  if TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172[base] then return TECH_PRIESTS_CONVERSATION_EXACT_ALIASES_0172[base] end

  if string.find(name, "quality", 1, true) then return "quality-doctrine" end
  if string.find(name, "module", 1, true) or string.find(name, "beacon", 1, true) or string.find(name, "effect%-transmission") then return "module-doctrine" end
  if string.find(name, "productivity", 1, true) or string.find(name, "research%-speed") or string.find(name, "mining%-productivity") then return "productivity-research-doctrine" end
  if string.find(name, "science%-pack") or string.find(name, "science", 1, true) then return "science-pack-doctrine" end
  if string.find(name, "weapon") or string.find(name, "damage") or string.find(name, "shooting%-speed") or string.find(name, "military") or string.find(name, "flamethrower") or string.find(name, "rocket") or string.find(name, "artillery") or string.find(name, "railgun") or string.find(name, "tesla") or string.find(name, "atomic") or string.find(name, "defender") or string.find(name, "distractor") or string.find(name, "destroyer") then return "combat-doctrine" end
  if string.find(name, "turret") or string.find(name, "wall") or string.find(name, "gate") or string.find(name, "armor") or string.find(name, "radar") or string.find(name, "repair") or string.find(name, "mine", 1, true) then return "defense-doctrine" end
  if string.find(name, "robot") or string.find(name, "roboport") or string.find(name, "logistic%-system") then return "vanilla-robotics-doctrine" end
  if string.find(name, "logistic") or string.find(name, "transport%-belt") or string.find(name, "belt") or string.find(name, "inserter") or string.find(name, "stack") or string.find(name, "bulk") then return "vanilla-logistics-doctrine" end
  if string.find(name, "rail") or string.find(name, "train") or string.find(name, "wagon") or string.find(name, "automobilism") or string.find(name, "spidertron") or string.find(name, "tank") then return "vanilla-rail-vehicle-doctrine" end
  if string.find(name, "space%-platform") or string.find(name, "thruster") then return "vanilla-space-platform-doctrine" end
  if string.find(name, "asteroid") then return "space-age-asteroid-doctrine" end
  if string.find(name, "planet%-discovery") then return "space-age-planet-discovery-doctrine" end
  if string.find(name, "tungsten") or string.find(name, "foundry") or string.find(name, "calcite") or string.find(name, "metallurgic") or string.find(name, "vulcanus") then return "space-age-vulcanus-metallurgy-doctrine" end
  if string.find(name, "holmium") or string.find(name, "electromagnetic") or string.find(name, "recycling") or string.find(name, "scrap") or string.find(name, "fulgora") then return "space-age-fulgora-electromagnetic-doctrine" end
  if string.find(name, "gleba") or string.find(name, "bio") or string.find(name, "yumako") or string.find(name, "jelly") or string.find(name, "agri") or string.find(name, "bacteria") or string.find(name, "nutrient") or string.find(name, "egg") or string.find(name, "soil") or string.find(name, "carbon%-fiber") then return "space-age-gleba-biology-doctrine" end
  if string.find(name, "aquilo") or string.find(name, "cryogenic") or string.find(name, "lithium") or string.find(name, "quantum") or string.find(name, "fusion") then return "space-age-aquilo-cryogenics-doctrine" end
  if string.find(name, "nuclear") or string.find(name, "uranium") or string.find(name, "kovarex") then return "vanilla-nuclear-doctrine" end
  if string.find(name, "oil") or string.find(name, "fluid") or string.find(name, "sulfur") or string.find(name, "plastic") or string.find(name, "lubricant") or string.find(name, "battery") or string.find(name, "chemical") or string.find(name, "explosive") or string.find(name, "flammable") or string.find(name, "laser") then return "vanilla-fluid-chemistry-doctrine" end
  if string.find(name, "power") or string.find(name, "solar") or string.find(name, "electric%-energy") or string.find(name, "accumulator") or string.find(name, "steam") or string.find(name, "lightning") then return "vanilla-power-doctrine" end
  if string.find(name, "circuit") or string.find(name, "combinator") or string.find(name, "electronics") then return "circuit-combinator-doctrine" end
  if string.find(name, "concrete") or string.find(name, "landfill") or string.find(name, "foundation") or string.find(name, "cliff") or string.find(name, "lamp") then return "terrain-infrastructure-doctrine" end
  if string.find(name, "equipment") or string.find(name, "shield") or string.find(name, "exoskeleton") or string.find(name, "night%-vision") or string.find(name, "personal") or string.find(name, "toolbelt") then return "personal-equipment-doctrine" end
  if string.find(name, "automation") or string.find(name, "processing") or string.find(name, "machine") or string.find(name, "engine") or string.find(name, "steel") or string.find(name, "material") or string.find(name, "structure") then return "vanilla-machine-doctrine" end
  return nil
end

TECH_PRIESTS_CONVERSATION_RESPONSES_0167 = {
  junior = {
    "Obedience maintained.",
    "Understanding not required.",
    "Blessed confusion acknowledged.",
    "Standing by.",
    "I will report strange humming."
  },
  intermediate = {
    "Clarification requested: should unknown doctrine be quarantined or normalized?",
    "I understand the need for restraint, though the factory appears unconcerned.",
    "The technology functions, but I dislike that it does so without explanation.",
    "I recommend observation before integration.",
    "This may be divine mystery, but it has the shape of a dependency issue."
  },
  senior = {
    "Unfamiliar does not mean forbidden, but it does mean supervised.",
    "The distinction between revelation and contamination is paperwork, testing, and casualties avoided.",
    "Proceed with observation. Reverence may follow evidence.",
    "Do not fear the unknown. Fear undocumented confidence.",
    "If it is xenos, it will betray itself through elegance, efficiency, or insufficient bureaucracy."
  }
}

function tech_priests_get_pair_tier_name_0167(pair)
  if not pair then return "junior" end
  if pair.tier and pair.tier ~= "" then return pair.tier end
  if pair.station and pair.station.valid and get_station_config then
    local cfg = get_station_config(pair.station)
    if cfg and cfg.tier then return cfg.tier end
  end
  return "junior"
end

function tech_priests_get_last_researched_technology_0167(force)
  ensure_storage()
  storage.tech_priests.last_researched_technology_by_force = storage.tech_priests.last_researched_technology_by_force or {}
  if force and force.valid then
    local stored = storage.tech_priests.last_researched_technology_by_force[force.name]
    if stored and stored ~= "" then return stored end
  end
  return TECH_PRIESTS_DEFAULT_CONVERSATION_TOPIC_0167
end

function tech_priests_get_conversation_topic_for_force_0167(force)
  local tech_name = tech_priests_get_last_researched_technology_0167(force)
  local topic = tech_name
  if TECH_PRIESTS_CONVERSATION_TOPIC_ALIASES_0167[topic] then
    topic = TECH_PRIESTS_CONVERSATION_TOPIC_ALIASES_0167[topic]
  end
  if not TECH_PRIESTS_CONVERSATION_LINES_0167[topic] then
    topic = tech_priests_classify_known_research_topic_0172(tech_name) or topic
  end
  if not TECH_PRIESTS_CONVERSATION_LINES_0167[topic] then
    topic = TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167
  end
  return topic, tech_name
end

function tech_priests_format_conversation_line_0167(line, tech_name)
  local icon = ""
  if tech_name and tech_name ~= "" then
    icon = "[technology=" .. tostring(tech_name) .. "]"
  end
  line = tostring(line or "...")
  line = string.gsub(line, "__TECH_ICON__", icon)
  line = string.gsub(line, "__TECH__", tostring(tech_name or "an unidentified doctrine"))
  return line
end

function tech_priests_choose_deterministic_line_0167(lines, seed)
  if not lines or #lines == 0 then return "..." end
  local index = ((seed or 0) % #lines) + 1
  return lines[index]
end

function tech_priests_choose_conversation_lines_0167(speaker_pair, listener_pair)
  local speaker_rank = tech_priests_get_pair_tier_name_0167(speaker_pair)
  local listener_rank = tech_priests_get_pair_tier_name_0167(listener_pair)
  local force = speaker_pair and speaker_pair.station and speaker_pair.station.valid and speaker_pair.station.force or nil
  local topic, tech_name = tech_priests_get_conversation_topic_for_force_0167(force)
  local topic_table = TECH_PRIESTS_CONVERSATION_LINES_0167[topic] or TECH_PRIESTS_CONVERSATION_LINES_0167[TECH_PRIESTS_FALLBACK_UNKNOWN_TECH_TOPIC_0167]
  local branch = topic_table and topic_table[speaker_rank] and topic_table[speaker_rank][listener_rank] or nil
  local seed = ((speaker_pair and speaker_pair.station_unit) or 0) + ((listener_pair and listener_pair.station_unit) or 0) + (game and game.tick or 0)
  local speaker_line = tech_priests_choose_deterministic_line_0167(branch, seed)
  local response_lines = TECH_PRIESTS_CONVERSATION_RESPONSES_0167[listener_rank] or TECH_PRIESTS_CONVERSATION_RESPONSES_0167.junior
  local response_line = tech_priests_choose_deterministic_line_0167(response_lines, seed + 7)
  return {
    tech_name = tech_name,
    topic = topic,
    speaker_rank = speaker_rank,
    listener_rank = listener_rank,
    speaker_line = tech_priests_format_conversation_line_0167(speaker_line, tech_name),
    response_line = tech_priests_format_conversation_line_0167(response_line, tech_name)
  }
end

function tech_priests_clear_idle_conversation_text_0167(pair)
  ensure_storage()
  storage.tech_priests.idle_conversation_texts = storage.tech_priests.idle_conversation_texts or {}
  local key = pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number))
  if not key then return end
  local object = storage.tech_priests.idle_conversation_texts[key]
  if object then destroy_render_object(object) end
  storage.tech_priests.idle_conversation_texts[key] = nil
end

function tech_priests_draw_idle_conversation_text_0167(pair, text, listener)
  if not (pair and pair.priest and pair.priest.valid and text and text ~= "") then return end
  ensure_storage()
  storage.tech_priests.idle_conversation_texts = storage.tech_priests.idle_conversation_texts or {}
  tech_priests_clear_idle_conversation_text_0167(pair)
  local color = listener and { r = 0.70, g = 0.95, b = 1.00, a = 0.95 } or { r = 1.00, g = 0.92, b = 0.55, a = 0.95 }
  local object = draw_priest_status_text({
    text = text,
    target = { entity = pair.priest, offset = { 0, -2.15 } },
    surface = pair.priest.surface,
    color = color,
    scale = 0.80,
    alignment = "center",
    time_to_live = TECH_PRIESTS_IDLE_CONVERSATION_RENDER_TTL_0167
  })
  if object then storage.tech_priests.idle_conversation_texts[pair.station_unit or pair.station.unit_number] = object end
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_stop_idle_conversation_0167 (old lines 9851-9861); next definition begins at old line 10025. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.

function tech_priests_is_pair_available_for_idle_conversation_0167(pair, as_listener)
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


function tech_priests_pair_has_real_work_0167(pair)
  if not pair then return true end
  if pair.target and pair.target.valid then return true end
  if pair.inventory_scan or pair.scavenge or pair.cram or pair.emergency_craft then return true end
  local mode = pair.mode or "idle"
  if mode == "idle-conversation" then return false end
  if mode ~= "idle" and mode ~= "returning" and mode ~= "" then return true end
  return false
end

function tech_priests_find_nearest_idle_conversation_partner_0167(pair)
  if not (pair and pair.station and pair.station.valid and pair.priest and pair.priest.valid) then return nil end
  ensure_storage()
  local station = pair.station
  local radius = refresh_pair_radius(pair)
  local best = nil
  local best_dist = nil
  for _, other in pairs(storage.tech_priests.pairs_by_station or {}) do
    if other ~= pair and tech_priests_is_pair_available_for_idle_conversation_0167(other, true) then
      if other.station and other.station.valid and other.priest and other.priest.valid and other.station.force == station.force and other.station.surface == station.surface then
        local dxs = other.station.position.x - station.position.x
        local dys = other.station.position.y - station.position.y
        local station_dist = dxs * dxs + dys * dys
        if station_dist <= radius * radius then
          local dx = other.priest.position.x - pair.priest.position.x
          local dy = other.priest.position.y - pair.priest.position.y
          local dist = dx * dx + dy * dy
          if not best_dist or dist < best_dist then
            best = other
            best_dist = dist
          end
        end
      end
    end
  end
  return best, best_dist
end

-- TECH-PRIESTS 0.1.431: removed superseded duplicate function tech_priests_start_idle_conversation_0167 (old lines 9918-9939); next definition begins at old line 9997. No intervening capture/registration/reference was detected by tools/audit_control_deletion_candidates.py.



-- 0.1.169 idle conversation/scan polish pass:
-- * idle conversations now halt both participants once they are in speaking range
-- * conversation text is rendered with a conservative typewriter reveal instead of full-line popping
-- * idle scanning now shows the scanned entity icon and a short inspection blurb above the priest
TECH_PRIESTS_IDLE_CONVERSATION_TYPEWRITER_TICKS_PER_CHAR_0169 = 2
TECH_PRIESTS_IDLE_CONVERSATION_HALT_REFRESH_TICKS_0169 = 15
TECH_PRIESTS_IDLE_SCAN_FEEDBACK_TTL_0169 = 30
TECH_PRIESTS_IDLE_SCAN_FEEDBACK_REFRESH_TICKS_0169 = 24

function tech_priests_halt_priest_0169(priest)
  if not (priest and priest.valid) then return false end
  if tech_priests_route_ground_command_0429 and defines and defines.command then
    local ok, result = pcall(function() return tech_priests_route_ground_command_0429(priest, { type = defines.command.stop }, "idle-conversation-halt-0169", { priority = 95, ttl = 60 }) end)
    if ok and result then return true end
  end
  local commandable = priest.commandable
  if commandable and commandable.valid and defines and defines.command and defines.command.stop then
    local ok = pcall(function()
      commandable.set_command({ type = defines.command.stop })
    end)
    if ok then return true end
  end
  if issue_priest_command and priest.position then
    return issue_priest_command(priest, {
      type = defines.command.go_to_location,
      destination = priest.position,
      radius = 0.15,
      distraction = defines.distraction.by_enemy
    })
  end
  return false
end

function tech_priests_halt_conversation_pair_0169(pair, listener_pair)
  if pair and pair.priest and pair.priest.valid then tech_priests_halt_priest_0169(pair.priest) end
  if listener_pair and listener_pair.priest and listener_pair.priest.valid then tech_priests_halt_priest_0169(listener_pair.priest) end
end

function tech_priests_visible_typewriter_line_0169(text, started_tick)
  text = tostring(text or "...")
  local prefix, body = string.match(text, "^(%[technology=[^%]]+%]%s*)(.*)$")
  if not prefix then
    prefix = ""
    body = text
  end
  local elapsed = math.max(0, (game.tick or 0) - (started_tick or game.tick or 0))
  local count = math.floor(elapsed / TECH_PRIESTS_IDLE_CONVERSATION_TYPEWRITER_TICKS_PER_CHAR_0169)
  if count < 1 then count = 1 end
  if count > #body then count = #body end
  local visible = string.sub(body, 1, count)
  return prefix .. visible, count >= #body
end

function tech_priests_start_idle_conversation_0167(pair, listener_pair)
  if not (pair and listener_pair and pair.priest and pair.priest.valid and listener_pair.priest and listener_pair.priest.valid) then return false end
  local chosen = tech_priests_choose_conversation_lines_0167(pair, listener_pair)
  local conversation_duration = math.max(TECH_PRIESTS_IDLE_CONVERSATION_DURATION_TICKS_0167, ((#(chosen.speaker_line or "") + #(chosen.response_line or "")) * TECH_PRIESTS_IDLE_CONVERSATION_TYPEWRITER_TICKS_PER_CHAR_0169) + 60 * 3)
  pair.idle_conversation = {
    listener_station_unit = listener_pair.station_unit or listener_pair.station.unit_number,
    started_tick = game.tick,
    due_tick = game.tick + conversation_duration,
    next_line_tick = game.tick,
    phase_started_tick = game.tick,
    last_halt_tick = 0,
    phase = 1,
    speaker_line = chosen.speaker_line,
    response_line = chosen.response_line,
    tech_name = chosen.tech_name,
    topic = chosen.topic
  }
  pair.next_idle_conversation_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_COOLDOWN_TICKS_0167
  listener_pair.next_idle_conversation_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_COOLDOWN_TICKS_0167
  listener_pair.idle_conversation_listener_until = game.tick + conversation_duration
  listener_pair.idle_conversation_speaker_station_unit = pair.station_unit or pair.station.unit_number
  pair.mode = "idle-conversation"
  listener_pair.mode = "idle-conversation"
  if stop_idle_scan then stop_idle_scan(pair) stop_idle_scan(listener_pair) end
  tech_priests_halt_conversation_pair_0169(pair, listener_pair)
  return true
end

function tech_priests_stop_idle_conversation_0167(pair)
  if not pair then return end
  local convo = pair.idle_conversation
  if convo and convo.listener_station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station then
    local listener_pair = storage.tech_priests.pairs_by_station[convo.listener_station_unit]
    if listener_pair then
      listener_pair.idle_conversation_listener_until = nil
      listener_pair.idle_conversation_speaker_station_unit = nil
      tech_priests_clear_idle_conversation_text_0167(listener_pair)
      if not tech_priests_pair_has_real_work_0167(listener_pair) then listener_pair.mode = "idle" end
    end
  end
  pair.idle_conversation = nil
  pair.mode = "idle"
  tech_priests_clear_idle_conversation_text_0167(pair)
end

function update_idle_conversation_behavior(pair)
  if not pair then return false end
  if pair.idle_conversation then
    local convo = pair.idle_conversation
    local listener_pair = convo.listener_station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[convo.listener_station_unit] or nil
    if not (pair.priest and pair.priest.valid and listener_pair and listener_pair.priest and listener_pair.priest.valid) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end
    if tech_priests_pair_has_real_work_0167(pair) or tech_priests_pair_has_real_work_0167(listener_pair) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end
    if game.tick >= (convo.due_tick or 0) then
      tech_priests_stop_idle_conversation_0167(pair)
      return false
    end

    local dx = pair.priest.position.x - listener_pair.priest.position.x
    local dy = pair.priest.position.y - listener_pair.priest.position.y
    if dx * dx + dy * dy > TECH_PRIESTS_IDLE_CONVERSATION_MIN_DISTANCE_SQ_0167 then
      move_priest_to(pair.priest, listener_pair.priest)
      -- The listener should also stop instead of wandering while being approached.
      tech_priests_halt_priest_0169(listener_pair.priest)
      return true
    end

    if game.tick >= (convo.last_halt_tick or 0) + TECH_PRIESTS_IDLE_CONVERSATION_HALT_REFRESH_TICKS_0169 then
      tech_priests_halt_conversation_pair_0169(pair, listener_pair)
      convo.last_halt_tick = game.tick
    end

    local line = convo.phase == 1 and convo.speaker_line or convo.response_line
    local visible, complete = tech_priests_visible_typewriter_line_0169(line, convo.phase_started_tick or game.tick)
    if convo.phase == 1 then
      tech_priests_draw_idle_conversation_text_0167(pair, visible, false)
      tech_priests_clear_idle_conversation_text_0167(listener_pair)
    else
      tech_priests_draw_idle_conversation_text_0167(listener_pair, visible, true)
      tech_priests_clear_idle_conversation_text_0167(pair)
    end

    if complete and not convo.phase_complete_tick then
      convo.phase_complete_tick = game.tick
    end
    if complete and convo.phase_complete_tick and game.tick >= convo.phase_complete_tick + 45 then
      if convo.phase == 1 then
        convo.phase = 2
      else
        convo.phase = 1
      end
      convo.phase_started_tick = game.tick
      convo.phase_complete_tick = nil
      convo.next_line_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_LINE_TICKS_0167
    end

    pair.mode = "idle-conversation"
    listener_pair.mode = "idle-conversation"
    return true
  end

  if pair.idle_conversation_listener_until and game.tick < pair.idle_conversation_listener_until then
    if tech_priests_pair_has_real_work_0167(pair) then
      pair.idle_conversation_listener_until = nil
      pair.idle_conversation_speaker_station_unit = nil
      tech_priests_clear_idle_conversation_text_0167(pair)
      return false
    end
    local speaker_pair = pair.idle_conversation_speaker_station_unit and storage and storage.tech_priests and storage.tech_priests.pairs_by_station and storage.tech_priests.pairs_by_station[pair.idle_conversation_speaker_station_unit] or nil
    if speaker_pair and speaker_pair.idle_conversation then
      tech_priests_halt_priest_0169(pair.priest)
    end
    pair.mode = "idle-conversation"
    return true
  elseif pair.idle_conversation_listener_until then
    pair.idle_conversation_listener_until = nil
    pair.idle_conversation_speaker_station_unit = nil
    tech_priests_clear_idle_conversation_text_0167(pair)
  end

  if not tech_priests_is_pair_available_for_idle_conversation_0167(pair, false) then return false end
  pair.next_idle_conversation_attempt_tick = game.tick + TECH_PRIESTS_IDLE_CONVERSATION_ATTEMPT_TICKS_0167 + ((pair.station_unit or 0) % 90)
  local chance = tonumber(settings.global["tech-priests-idle-conversation-chance-percent"] and settings.global["tech-priests-idle-conversation-chance-percent"].value) or 18
  if chance <= 0 then return false end
  local roll = ((game.tick + (pair.station_unit or 0) * 31) % 100)
  if roll >= chance then return false end
  local partner = tech_priests_find_nearest_idle_conversation_partner_0167(pair)
  if not partner then return false end
  return tech_priests_start_idle_conversation_0167(pair, partner)
end

function tech_priests_clear_idle_scan_feedback_0169(pair)
  ensure_storage()
  storage.tech_priests.idle_scan_feedback_texts = storage.tech_priests.idle_scan_feedback_texts or {}
  local key = pair and (pair.station_unit or (pair.station and pair.station.valid and pair.station.unit_number))
  if not key then return end
  local object = storage.tech_priests.idle_scan_feedback_texts[key]
  if object then destroy_render_object(object) end
  storage.tech_priests.idle_scan_feedback_texts[key] = nil
end

tech_priests_original_clear_idle_scan_line_0169 = clear_idle_scan_line
function clear_idle_scan_line(pair)
  if tech_priests_original_clear_idle_scan_line_0169 then tech_priests_original_clear_idle_scan_line_0169(pair) end
  tech_priests_clear_idle_scan_feedback_0169(pair)
end

function tech_priests_get_idle_scan_blurb_0169(entity)
  if not (entity and entity.valid) then return "Machine spirit lost."
  end
  if entity.health and entity.max_health and entity.health < entity.max_health then
    return "Damage scars catalogued."
  end
  if is_consecration_target and is_consecration_target(entity) and get_consecration_record then
    local record = get_consecration_record(entity)
    if record then
      local max_value = record.max_sanctification or get_base_sanctification_max(entity.force)
      local current = record.sanctification or 0
      if max_value > 0 then
        return "Sanctity reading: " .. tostring(math.floor((current / max_value) * 100 + 0.5)) .. "%."
      end
    end
  end
  local entity_type = entity.type or ""
  if entity_type == "assembling-machine" then return "Assembly rite audited." end
  if entity_type == "furnace" then return "Thermal spirit temperament nominal." end
  if entity_type == "inserter" then return "Grasping servo devotion measured." end
  if entity_type == "transport-belt" or entity_type == "underground-belt" or entity_type == "splitter" then return "Conveyor catechism velocity checked." end
  if entity_type == "electric-pole" or entity_type == "power-switch" then return "Current hymns traced." end
  if entity_type == "pipe" or entity_type == "pipe-to-ground" or entity_type == "pump" then return "Fluid omens reviewed." end
  if entity_type == "container" or entity_type == "logistic-container" then return "Inventory reliquary indexed." end
  if entity_type == "mining-drill" then return "Extraction prayers sampled." end
  if entity_type == "lab" then return "Research shrine murmurs recorded." end
  if entity_type == "roboport" then return "Drone choir discipline observed." end
  if entity_type == "ammo-turret" or entity_type == "electric-turret" or entity_type == "fluid-turret" or entity_type == "artillery-turret" then return "Defensive oath reviewed." end
  if entity_type == "reactor" or entity_type == "generator" or entity_type == "boiler" or entity_type == "solar-panel" or entity_type == "accumulator" then return "Power spirit compliance checked." end
  if entity_type == "thruster" then return "Propulsion shrine inspected from a respectful distance." end
  return "Unclassified machine spirit observed."
end

function tech_priests_draw_idle_scan_feedback_0169(pair)
  if not (pair and pair.priest and pair.priest.valid and pair.idle_scan and pair.idle_scan.target and pair.idle_scan.target.valid) then return end
  local scan = pair.idle_scan
  if game.tick < (scan.next_feedback_tick or 0) then return end
  scan.next_feedback_tick = game.tick + TECH_PRIESTS_IDLE_SCAN_FEEDBACK_REFRESH_TICKS_0169
  tech_priests_clear_idle_scan_feedback_0169(pair)
  local target = scan.target
  local text = "[entity=" .. tostring(target.name) .. "] " .. tech_priests_get_idle_scan_blurb_0169(target)
  ensure_storage()
  storage.tech_priests.idle_scan_feedback_texts = storage.tech_priests.idle_scan_feedback_texts or {}
  local object = draw_priest_status_text({
    text = text,
    target = { entity = pair.priest, offset = { 0, -2.65 } },
    surface = pair.priest.surface,
    color = { r = 0.65, g = 1.00, b = 0.70, a = 0.92 },
    scale = 0.72,
    alignment = "center",
    time_to_live = TECH_PRIESTS_IDLE_SCAN_FEEDBACK_TTL_0169
  })
  if object then storage.tech_priests.idle_scan_feedback_texts[pair.station_unit or pair.station.unit_number] = object end
end

tech_priests_original_draw_idle_scan_line_0169 = draw_idle_scan_line
function draw_idle_scan_line(pair)
  if tech_priests_original_draw_idle_scan_line_0169 then tech_priests_original_draw_idle_scan_line_0169(pair) end
  tech_priests_draw_idle_scan_feedback_0169(pair)
end

tech_priests_original_clear_all_runtime_rendering_0169 = clear_all_runtime_rendering
function clear_all_runtime_rendering()
  if tech_priests_original_clear_all_runtime_rendering_0169 then tech_priests_original_clear_all_runtime_rendering_0169() end
  if storage and storage.tech_priests then
    storage.tech_priests.idle_scan_feedback_texts = {}
  end
end


-- 0.1.170 High Fabricator / Archmagos player-awareness doctrine:
-- Adds flavor-only player-aware idle conversation variants. These lines do not change priest work logic.
-- Factorio does not reliably expose which multiplayer client is the local host to deterministic mod code.
-- Single-player defaults to High Fabricator. Multiplayer defaults to Archmagos unless a player is manually designated.

TECH_PRIESTS_PLAYER_ADDRESS_CHANCE_PERCENT_0170 = 38
TECH_PRIESTS_PLAYER_CONTEXT_MAX_AGE_TICKS_0170 = 60 * 60 * 12
TECH_PRIESTS_PLAYER_CONTEXT_RADIUS_SQ_0170 = 48 * 48
TECH_PRIESTS_HIGH_FABRICATOR_COMMAND_0170 = "tech-priests-high-fabricator"

function tech_priests_ensure_player_awareness_storage_0170()
  ensure_storage()
  storage.tech_priests.last_player_context_by_force = storage.tech_priests.last_player_context_by_force or {}
  storage.tech_priests.last_player_context_by_player = storage.tech_priests.last_player_context_by_player or {}
end

function tech_priests_is_multiplayer_0170()
  if game and game.is_multiplayer then
    local ok, result = pcall(function() return game.is_multiplayer() end)
    if ok then return result end
  end
  local count = 0
  if game and game.players then
    for _, _ in pairs(game.players) do
      count = count + 1
      if count > 1 then return true end
    end
  end
  return false
end
