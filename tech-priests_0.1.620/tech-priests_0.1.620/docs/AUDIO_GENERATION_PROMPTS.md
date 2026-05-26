# Tech Priests Audio Generation Prompts

## Purpose

This document contains reusable prompts for generating the first-pass Tech Priests sound set. These prompts are written to keep audio generation focused on gameplay clarity and the mod's grim industrial religious identity.

Use these prompts with an audio generation tool, sound design workflow, or as direction for procedural placeholder sounds.

## Global Style Guide

All generated sounds should feel like they belong to a Warhammer-40K-inspired industrial priest machine system inside Factorio.

The sound language should be:

```text
ancient machinery, damp cathedral electronics, failing relays, servo movement, ritualized industrial maintenance, corrupted cogitators, oil-stained brass, bad vox speakers, and machine-cult bureaucracy
```

Avoid:

```text
clean sci-fi, arcade lasers, fantasy magic, modern alarms, trailer music, heroic orchestration, polished corporate UI, readable speech, or generic robot voices
```

Most first-pass sounds should be short one-shots. Repeated gameplay actions need variants.

---

# Priest Task Sounds

## tp_priest_repair_01.ogg / 02 / 03

### Gameplay Purpose

A Tech Priest begins repairing a damaged machine or entity.

### Prompt

Generate a short game sound effect for a grim industrial machine-priest repairing damaged factory equipment. The sound should include small metal ratchet clicks, servo wrist movement, tiny solder crackle, cable tightening, and faint robe or cable movement. It should feel practical, old, mechanical, and slightly ritual-adjacent, but it must primarily read as physical repair work.

### Negative Prompt

No magic healing sparkle, no clean sci-fi UI beep, no fantasy spell, no orchestral sting, no modern cordless drill, no readable spoken words, no heroic fanfare.

### Duration

0.6 to 1.0 seconds.

### Playback Type

One-shot.

### Notes

Create three variants with different click/rattle timing so repeated repairs do not become irritating.

---

## tp_priest_sanctify_oil_01.ogg / 02 / 03

### Gameplay Purpose

A Tech Priest applies sacred machine oil or performs a minor sanctification rite on a machine.

### Prompt

Generate a short game sound effect for a grim machine cult priest applying sacred machine oil to old industrial equipment. Include a viscous oil applicator hiss, tiny brass nozzle movement, brush or smear texture, soft servo positioning, faint corrupted vox murmur with no intelligible words, and a low oily mechanical settling sound. The sound should feel sacred, mechanical, grimy, and practical.

### Negative Prompt

No fantasy potion sound, no magical healing chime, no choir, no clean cyberpunk synth, no readable speech, no bright success jingle, no sparkling effects.

### Duration

0.8 to 1.6 seconds.

### Playback Type

One-shot.

### Notes

This must be clearly different from repair. Repair is tools and damage. Sanctification is oil, ritual maintenance, and machine appeasement.

---

## tp_priest_scan_01.ogg / 02 / 03

### Gameplay Purpose

A Tech Priest or Cogitator Station scans inventory, resources, machines, or nearby conditions.

### Prompt

Generate a short subtle auspex scan sound for an ancient industrial machine-priest system. Use a dirty optical lens adjustment, faint CRT whine, low static tick, tiny relay chirp, and a dry data sweep. The sound should feel old and mechanical rather than futuristic. It should be light enough for repeated gameplay use.

### Negative Prompt

No laser weapon zap, no bright sci-fi scanner beam, no clean Star Trek interface beep, no arcade sound, no large rising sweep, no magic shimmer.

### Duration

0.25 to 0.7 seconds.

### Playback Type

One-shot.

### Notes

This sound may occur more often than emergency or link sounds, so it must be subtle and cooldown-safe.

---

## tp_priest_emergency_01.ogg / 02

### Gameplay Purpose

A Tech Priest enters emergency behavior or Martian emergency recovery mode.

### Prompt

Generate a serious but restrained emergency cue for an ancient machine-cult system entering survival recovery mode. Use a low damaged warning tone, failing shrine relay clack, static-damaged vox speaker burst, heavy brass switch movement, and a grim mechanical acknowledgement. The sound should feel like an old religious industrial warning system rather than a modern alarm.

### Negative Prompt

No modern siren, no ambulance or fire alarm, no clean spaceship alert, no orchestral hit, no voice line, no musical fanfare, no loud looping alarm.

### Duration

1.0 to 2.5 seconds.

### Playback Type

One-shot.

### Notes

Emergency sounds should be rare and important. They must not become constant siren noise.

---

# Station Sounds

## tp_station_link_established_01.ogg / 02

### Gameplay Purpose

A Cogitator Station successfully pairs with a Tech Priest.

### Prompt

Generate a short sacred data-handshake sound for an ancient Cogitator Station linking to a machine priest. Include brass relay clacks, a low confirmation tone, tiny cogitator chatter, shrine-latch movement, and a final stable electrical hum. It should feel like a successful pairing between old religious machinery and a cybernetic servant.

### Negative Prompt

No clean computer login sound, no modern phone notification, no bright UI chime, no magic spell, no orchestral success cue, no readable speech.

### Duration

0.7 to 1.4 seconds.

### Playback Type

One-shot.

### Notes

This should make station placement or priest creation feel complete and deliberate.

---

## tp_station_link_broken_01.ogg / 02

### Gameplay Purpose

The station/priest relationship is broken, invalid, severed, or missing.

### Prompt

Generate a short broken machine-link warning for an ancient Cogitator Station losing contact with its paired Tech Priest. Use a failed relay sequence, corrupted data handshake, frayed vox tether static, low electrical drop-out, and a final unstable click. It should sound abnormal and worrying, but not like an explosion or death.

### Negative Prompt

No explosion, no death scream, no modern error beep, no clean computer alert, no siren, no readable speech, no dramatic orchestral sting.

### Duration

0.8 to 1.8 seconds.

### Playback Type

One-shot.

### Notes

This sound is especially useful for debugging and player clarity when priest tracking or pairing becomes abnormal.

---

# Machine Sanctity Sounds

## tp_machine_low_sanctity_warning_01.ogg / 02 / 03

### Gameplay Purpose

A machine is spiritually and mechanically degraded, below a sanctity threshold.

### Prompt

Generate a short degraded industrial machine warning for a grim machine-cult factory. Use bearing grind, belt slip, bad combustion cough, failing capacitor buzz, metal stress, and an unhappy low mechanical groan. It should sound like a machine spirit becoming neglected, damaged, and resentful, without sounding supernatural.

### Negative Prompt

No ghost sound, no fantasy curse, no clean alarm beep, no combat hit, no explosion, no orchestral horror sting, no voice, no magic.

### Duration

0.8 to 2.0 seconds.

### Playback Type

One-shot, occasional warning.

### Notes

This should be cooldown-limited and should not loop constantly. It is a warning, not a permanent siren.

---

## tp_machine_detritus_clog_01.ogg / 02

### Gameplay Purpose

Mechanical detritus, poor condition, or clogging is interfering with machine operation.

### Prompt

Generate a short ugly machine clog sound for a dirty industrial factory machine. Use jammed gears, metal grit, hopper obstruction, caught belt, chunking scrap, and strained motor vibration. The sound should feel like debris has entered the machine and the mechanism is fighting through it badly.

### Negative Prompt

No explosion, no weapon impact, no clean error tone, no magic, no creature sound, no bright UI beep, no musical sting.

### Duration

0.6 to 1.4 seconds.

### Playback Type

One-shot.

### Notes

This should sound more physical than low sanctity warning. Low sanctity is degradation; detritus clog is obstruction and grit.

---

# GUI Sounds

## tp_gui_button_press_01.ogg / 02

### Gameplay Purpose

The player presses a custom Tech Priests GUI button.

### Prompt

Generate a very short diegetic interface button sound for an ancient cogitator shrine. Use a brass tab click, tiny relay snap, parchment-mechanical detent, and faint static pop. It should feel tactile, old, and mechanical, not like a modern digital button.

### Negative Prompt

No clean UI beep, no phone tap, no modern computer click, no arcade blip, no magic sound, no loud clank.

### Duration

0.08 to 0.25 seconds.

### Playback Type

One-shot UI sound.

### Notes

Must tolerate repeated clicking.

---

## tp_gui_panel_open_01.ogg

### Gameplay Purpose

A custom Tech Priests GUI panel opens, such as the Doctrine Web or identity reliquary.

### Prompt

Generate a short panel-opening sound for an ancient mechanical cogitator interface. Use sliding brass rails, small relay awakening clicks, faint parchment movement, low electrical bloom, and a quiet data-slate static rise. It should feel like an old shrine mechanism opening.

### Negative Prompt

No whooshy modern UI transition, no clean sci-fi door, no magic reveal, no orchestral swell, no voice.

### Duration

0.4 to 0.9 seconds.

### Playback Type

One-shot UI sound.

### Notes

Should be satisfying but quiet enough for frequent interface use.

---

## tp_gui_panel_close_01.ogg

### Gameplay Purpose

A custom Tech Priests GUI panel closes.

### Prompt

Generate a short panel-closing sound for an ancient mechanical cogitator interface. Use a brass slide returning, relay shutdown clicks, tiny static drop, and a firm but muted shrine-latch closure. It should feel old, tactile, and mechanical.

### Negative Prompt

No modern app close sound, no clean beep, no sci-fi whoosh, no magic vanish, no loud slam.

### Duration

0.3 to 0.8 seconds.

### Playback Type

One-shot UI sound.

### Notes

This should be related to the panel-open sound but lower and more final.

---

## tp_gui_tab_change_01.ogg

### Gameplay Purpose

The player changes tabs in a custom Tech Priests GUI.

### Prompt

Generate a very short tab-change sound for an old machine-cult cogitator interface. Use a small brass selector detent, relay tick, and faint static flicker. It should feel like a mechanical selector moving one position.

### Negative Prompt

No modern web tab sound, no clean beep, no arcade menu blip, no magic, no musical tone.

### Duration

0.08 to 0.25 seconds.

### Playback Type

One-shot UI sound.

### Notes

Must be short and unobtrusive.

---

## tp_gui_portrait_select_01.ogg

### Gameplay Purpose

The player selects a Tech Priest portrait or identity reliquary portrait option.

### Prompt

Generate a short portrait-selection sound for an ancient identity reliquary interface. Use a shrine lens sliding into alignment, tiny servo focus movement, brass detent click, faint CRT static flicker, and a small confirmation relay. It should feel like a physical portrait plate or sacred identification lens locking into place.

### Negative Prompt

No modern camera shutter, no clean digital beep, no magic sparkle, no phone notification, no voice.

### Duration

0.2 to 0.5 seconds.

### Playback Type

One-shot UI sound.

### Notes

This should support the portrait menu visually and make selection feel intentional.

---

# Procedural Placeholder Direction

If final generated audio is not ready, temporary placeholder sounds may be procedurally synthesized for implementation testing.

Placeholder sounds should still follow the naming convention and rough gameplay meaning. They do not need to be beautiful. They need to test:

- event hooks
- cooldowns
- random variant selection
- positional playback
- GUI playback
- volume balance
- spam prevention

Do not over-polish placeholders before testing event behavior.

# Generation QA Checklist

Before accepting generated sounds:

- Does repair sound clearly differ from sanctification?
- Does scan sound avoid sounding like a weapon?
- Does emergency sound avoid modern sirens?
- Does link established sound feel like successful pairing?
- Does link broken sound feel abnormal but not explosive?
- Does low sanctity sound suggest machine degradation?
- Does detritus clog sound suggest physical obstruction?
- Are GUI sounds short enough for repeated use?
- Are all sounds free of readable speech?
- Are all one-shots short and cleanly ended?
- Are repeated sounds generated in useful variants?
