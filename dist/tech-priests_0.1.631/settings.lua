-- Tech Priests - startup/runtime setting definitions.
-- 0.1.479 retired legacy status-symbol settings from the player-facing settings list;
-- the canonical overhead governor now owns visible priest task text. Legacy runtime
-- reads keep safe defaults inside the script, but the old configurable glyph spam is gone.
-- Consecration tuning is runtime-global so existing saves can be tuned without
-- repacking the mod while we iterate on balance.


-- 0.1.626 canonical debug mode. Older debug settings remain as compatibility aliases,
-- but runtime debug/profiler/log-spam behavior is governed by this single mode.
data:extend({
  {
    type = "string-setting",
    name = "tech-priests-debug-mode",
    setting_type = "runtime-global",
    default_value = "off",
    allowed_values = { "off", "summary", "verbose", "profiler", "legacy" },
    order = "z-debug-000[master-debug-mode]"
  }
})

data:extend({
  {
    type = "double-setting",
    name = "tech-priests-base-max-sanctification",
    setting_type = "runtime-global",
    default_value = 100,
    minimum_value = 10,
    maximum_value = 10000,
    order = "a[consecration]-a[base-max]"
  },
  {
    type = "double-setting",
    name = "tech-priests-starting-sanctification",
    setting_type = "runtime-global",
    default_value = 50,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-b[starting]"
  },
  {
    type = "double-setting",
    name = "tech-priests-minimum-sanctification-percent",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[consecration]-c[minimum-percent]"
  },
  {
    type = "double-setting",
    name = "tech-priests-min-degraded-max-sanctification",
    setting_type = "runtime-global",
    default_value = 25,
    minimum_value = 1,
    maximum_value = 10000,
    order = "a[consecration]-d[min-degraded-max]"
  },
  {
    type = "double-setting",
    name = "tech-priests-sacred-oil-restore-amount",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 0.01,
    maximum_value = 10000,
    order = "a[consecration]-e[oil-restore]"
  },
  {
    type = "double-setting",
    name = "tech-priests-min-sanctification-decay-per-operation",
    setting_type = "runtime-global",
    default_value = 3,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-f[min-decay]"
  },
  {
    type = "double-setting",
    name = "tech-priests-max-sanctification-decay-per-operation",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-g[max-decay]"
  },
  {
    type = "double-setting",
    name = "tech-priests-sanctification-decay-random-jitter-percent",
    setting_type = "runtime-global",
    default_value = 35,
    minimum_value = 0,
    maximum_value = 500,
    order = "a[consecration]-g2[random-jitter]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-show-sanctification-decay-floaters",
    setting_type = "runtime-global",
    default_value = true,
    order = "a[consecration]-g3[decay-floaters]"
  },
  {
    type = "double-setting",
    name = "tech-priests-sanctification-decay-floater-min-amount",
    setting_type = "runtime-global",
    default_value = 0.25,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-g4[decay-floater-min]"
  }

  ,
  {
    type = "double-setting",
    name = "tech-priests-physical-damage-threshold",
    setting_type = "runtime-global",
    default_value = 35,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-h[physical-damage-threshold]"
  },
  {
    type = "double-setting",
    name = "tech-priests-physical-damage-max-chance-percent",
    setting_type = "runtime-global",
    default_value = 65,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[consecration]-i[physical-damage-chance]"
  },
  {
    type = "double-setting",
    name = "tech-priests-physical-damage-min-health-percent",
    setting_type = "runtime-global",
    default_value = 0.2,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[consecration]-j[physical-damage-min]"
  },
  {
    type = "double-setting",
    name = "tech-priests-physical-damage-max-health-percent",
    setting_type = "runtime-global",
    default_value = 2.5,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[consecration]-k[physical-damage-max]"
  },
  {
    type = "double-setting",
    name = "tech-priests-max-sanctification-damage-threshold",
    setting_type = "runtime-global",
    default_value = 50,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-l[max-sanctity-damage-threshold]"
  },
  {
    type = "double-setting",
    name = "tech-priests-max-sanctification-damage-max-chance-percent",
    setting_type = "runtime-global",
    default_value = 14,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[consecration]-m[max-sanctity-damage-chance]"
  },
  {
    type = "double-setting",
    name = "tech-priests-max-sanctification-damage-min-amount",
    setting_type = "runtime-global",
    default_value = 14,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-n[max-sanctity-damage-min]"
  },
  {
    type = "double-setting",
    name = "tech-priests-max-sanctification-damage-max-amount",
    setting_type = "runtime-global",
    default_value = 19,
    minimum_value = 0,
    maximum_value = 10000,
    order = "a[consecration]-o[max-sanctity-damage-max]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-enable-station-request-debug-icons",
    setting_type = "runtime-global",
    default_value = false,
    order = "z-debug-a[station-request-icons]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-enable-idle-scan-behavior",
    setting_type = "runtime-global",
    default_value = true,
    order = "z-debug-b[idle-scan]"
  }
  ,
  {
    type = "bool-setting",
    name = "tech-priests-enable-logistics-debug-overlay",
    setting_type = "runtime-global",
    default_value = false,
    order = "z-debug-c[logistics-overlay]"
  }

  ,
  {
    type = "bool-setting",
    name = "tech-priests-enable-idle-conversations",
    setting_type = "runtime-global",
    default_value = true,
    order = "b[priest-status]-z[idle-conversation-enabled]"
  },
  {
    type = "int-setting",
    name = "tech-priests-idle-conversation-chance-percent",
    setting_type = "runtime-global",
    default_value = 18,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[priest-status]-z[idle-conversation-chance]"
  }

  ,
  {
    type = "bool-setting",
    name = "tech-priests-enable-sound-manager",
    setting_type = "runtime-global",
    default_value = true,
    order = "b[priest-status]-zy[sound-manager-enabled]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-enable-task-sounds",
    setting_type = "runtime-global",
    default_value = true,
    order = "b[priest-status]-zz[task-sounds-enabled]"
  },
  {
    type = "int-setting",
    name = "tech-priests-task-sound-volume-percent",
    setting_type = "runtime-global",
    default_value = 70,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[priest-status]-zz[task-sounds-volume]"
  }
  ,
  {
    type = "bool-setting",
    name = "tech-priests-enable-full-priority-diagnostics",
    setting_type = "runtime-global",
    default_value = false,
    order = "z-debug-aa[full-priority-diagnostics]"
  },
  {
    type = "int-setting",
    name = "tech-priests-priority-diagnostics-interval-ticks",
    setting_type = "runtime-global",
    default_value = 7200,
    minimum_value = 30,
    maximum_value = 36000,
    order = "z-debug-ab[full-priority-diagnostics-interval]"
  },

  {
    type = "int-setting",
    name = "tech-priests-cogitator-bios-boot-speed-percent",
    setting_type = "runtime-global",
    default_value = 50,
    minimum_value = 1,
    maximum_value = 100,
    order = "b[cogitator-workstate]-a[bios-boot-speed]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-enable-emergency-diagnostics",
    setting_type = "runtime-global",
    default_value = false,
    order = "z-debug-ab2[emergency-diagnostics-enabled]"
  },
  {
    type = "int-setting",
    name = "tech-priests-emergency-diagnostics-interval-ticks",
    setting_type = "runtime-global",
    default_value = 7200,
    minimum_value = 600,
    maximum_value = 36000,
    order = "z-debug-ab3[emergency-diagnostics-interval]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-quarantine-idle-until-priorities-clear",
    setting_type = "runtime-global",
    default_value = true,
    order = "z-debug-ac[idle-priority-quarantine]"
  }

  ,
  {
    type = "bool-setting",
    name = "tech-priests-enable-background-chatter",
    setting_type = "runtime-global",
    default_value = true,
    order = "b[chatter]-a[enabled]"
  },
  {
    type = "int-setting",
    name = "tech-priests-background-chatter-chance-percent",
    setting_type = "runtime-global",
    default_value = 5,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[chatter]-b[chance]"
  },
  {
    type = "int-setting",
    name = "tech-priests-background-chatter-busy-reject-percent",
    setting_type = "runtime-global",
    default_value = 85,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[chatter]-c[busy-reject]"
  },
  {
    type = "int-setting",
    name = "tech-priests-background-chatter-interval-ticks",
    setting_type = "runtime-global",
    default_value = 240,
    minimum_value = 30,
    maximum_value = 36000,
    order = "b[chatter]-d[interval]"
  },
  {
    type = "int-setting",
    name = "tech-priests-doctrine-argument-chance-percent",
    setting_type = "runtime-global",
    default_value = 12,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[chatter]-e[doctrine-argument-chance]"
  },
  {
    type = "int-setting",
    name = "tech-priests-doctrine-chatter-chance-percent",
    setting_type = "runtime-global",
    default_value = 45,
    minimum_value = 0,
    maximum_value = 100,
    order = "b[chatter]-f[doctrine-chatter-chance]"
  }


})


-- 0.1.332 Visual and chatter tuning.
data:extend({
  {
    type = "bool-setting",
    name = "tech-priests-background-chatter-allow-passive-busy-rejection",
    setting_type = "runtime-global",
    default_value = false,
    order = "z[tech-priests-chatter]-e[passive-busy-rejection]"
  },
  {
    type = "int-setting",
    name = "tech-priests-background-chatter-line-cooldown-ticks",
    setting_type = "runtime-global",
    default_value = 7200,
    minimum_value = 0,
    maximum_value = 216000,
    order = "z[tech-priests-chatter]-f[line-cooldown]"
  },
  {
    type = "double-setting",
    name = "tech-priests-direct-priest-tap-chatter-cooldown-ticks",
    setting_type = "runtime-global",
    default_value = 120,
    minimum_value = 15,
    maximum_value = 36000,
    order = "z[tech-priests-chatter]-g[direct-tap-cooldown]"
  }
})

-- 0.1.476 Task retention and writ cadence tuning.
data:extend({
  {
    type = "int-setting",
    name = "tech-priests-task-retention-seconds",
    setting_type = "runtime-global",
    default_value = 20,
    minimum_value = 1,
    maximum_value = 600,
    order = "c[task-retention]-a[current-task-retention]"
  },
  {
    type = "int-setting",
    name = "tech-priests-standard-writ-cadence-seconds",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 1,
    maximum_value = 3600,
    order = "c[task-retention]-b[standard-writ-cadence]"
  },
  {
    type = "int-setting",
    name = "tech-priests-magos-writ-cadence-seconds",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 1,
    maximum_value = 3600,
    order = "c[task-retention]-c[magos-writ-cadence]"
  },
  {
    type = "int-setting",
    name = "tech-priests-magos-plan-cadence-seconds",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 1,
    maximum_value = 3600,
    order = "c[task-retention]-d[magos-plan-cadence]"
  },
  {
    type = "int-setting",
    name = "tech-priests-standard-pending-writ-cap",
    setting_type = "runtime-global",
    default_value = 3,
    minimum_value = 0,
    maximum_value = 20,
    order = "c[task-retention]-e[standard-pending-cap]"
  },
  {
    type = "int-setting",
    name = "tech-priests-magos-pending-writ-cap",
    setting_type = "runtime-global",
    default_value = 2,
    minimum_value = 0,
    maximum_value = 20,
    order = "c[task-retention]-f[magos-pending-cap]"
  }
})


-- 0.1.477 Active-order execution watchdog and audio de-chatter tuning.
data:extend({
  {
    type = "int-setting",
    name = "tech-priests-order-execution-watchdog-seconds",
    setting_type = "runtime-global",
    default_value = 10,
    minimum_value = 2,
    maximum_value = 600,
    order = "c[task-retention]-g[execution-watchdog]"
  },
  {
    type = "int-setting",
    name = "tech-priests-station-task-switch-sound-cooldown-seconds",
    setting_type = "runtime-global",
    default_value = 45,
    minimum_value = 1,
    maximum_value = 3600,
    order = "c[task-retention]-h[station-switch-audio-cooldown]"
  },
  {
    type = "int-setting",
    name = "tech-priests-writ-audio-cooldown-seconds",
    setting_type = "runtime-global",
    default_value = 30,
    minimum_value = 1,
    maximum_value = 3600,
    order = "c[task-retention]-i[writ-audio-cooldown]"
  }
})


-- 0.1.586 optional lean graphics mode for lower-memory clients.
data:extend({
  {
    type = "bool-setting",
    name = "tech-priests-use-lean-gui-sprites",
    setting_type = "startup",
    default_value = false,
    order = "z-performance-a[lean-gui-sprites]"
  }
})


-- 0.1.589 Conclave schism governance toggles.
data:extend({
  {
    type = "bool-setting",
    name = "tech-priests-enable-doctrine-rebellions",
    setting_type = "runtime-global",
    default_value = true,
    order = "d[conclave]-a[doctrine-rebellions]"
  },
  {
    type = "bool-setting",
    name = "tech-priests-dont-touch-my-toys",
    setting_type = "runtime-global",
    default_value = true,
    order = "d[conclave]-b[dont-touch-my-toys]"
  }
})
