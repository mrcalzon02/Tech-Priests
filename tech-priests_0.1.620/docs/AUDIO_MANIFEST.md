# Tech Priests Audio Manifest

## Purpose

This document defines the first-pass audio language for the Tech Priests Factorio mod. The goal is not to create random atmospheric noise. The goal is to make the Tech Priest system easier to understand while reinforcing the grim, sacred, industrial machine-cult identity of the mod.

The first pass should focus on functional sound: sounds that tell the player what the system is doing without becoming annoying, repetitive, or misleading.

## Audio Identity

Tech Priests audio should sound like ancient machinery, damp cathedral electronics, failing relays, servo movement, ritualized industrial maintenance, corrupted cogitators, oil-stained brass mechanisms, and a bureaucratic religious institution trapped inside a diseased loudspeaker.

The soundscape should feel old, mechanical, sacred, corroded, practical, and faintly wrong.

### Correct Texture

Use textures like:

- old relay clicks
- servo movement
- ratcheting hand tools
- metal tension and release
- damp electrical hum
- low transformer buzz
- static-damaged vox texture
- failing cogitator electronics
- oil spray, brush, or applicator hiss
- brass shrine mechanisms
- worn machine strain
- unstable capacitor whine
- dirty CRT or auspex sweep
- short mechanical clacks
- faint robe or cable movement

### Wrong Texture

Avoid textures like:

- clean sci-fi UI beeps
- arcade lasers
- fantasy healing spells
- modern sirens
- orchestral trailer stings
- bright magical sparkles
- clean cyberpunk synthwave
- generic robot voices
- heroic fanfare
- modern cordless drills
- polished corporate UI sounds

## Core Rule

Every sound must answer at least one player-facing question:

- What just happened?
- What is the priest doing?
- What changed in the station/priest relationship?
- Is this machine damaged, degraded, or restored?
- Did the interface accept my action?

Sounds should reveal meaningful behavior. They should not expose tick-level script churn.

## First-Pass Scope

The first audio milestone is functional feedback. Do not begin with ambient music, long Mechanicus chants, full voice acting, elaborate station loops, or large cinematic effects. Those are later layers.

The first pass should cover:

- priest repair action
- priest sanctification/oil application
- priest scan action
- emergency mode entry
- station/priest link established
- station/priest link broken
- low sanctity machine warning
- detritus clog or machine obstruction
- basic diegetic GUI feedback

## File Structure

Recommended directory:

```text
sound/tech-priests/
```

Recommended docs:

```text
docs/AUDIO_MANIFEST.md
docs/AUDIO_GENERATION_PROMPTS.md
```

## Naming Convention

Use this format:

```text
tp_<category>_<action>_<variant>.ogg
```

Examples:

```text
tp_priest_repair_01.ogg
tp_priest_sanctify_oil_01.ogg
tp_priest_scan_01.ogg
tp_station_link_established_01.ogg
tp_station_link_broken_01.ogg
tp_gui_button_press_01.ogg
tp_machine_low_sanctity_warning_01.ogg
```

Use two-digit variant numbers for repeated one-shots.

## First-Pass Asset List

### Priest Task Sounds

```text
tp_priest_repair_01.ogg
tp_priest_repair_02.ogg
tp_priest_repair_03.ogg

tp_priest_sanctify_oil_01.ogg
tp_priest_sanctify_oil_02.ogg
tp_priest_sanctify_oil_03.ogg

tp_priest_scan_01.ogg
tp_priest_scan_02.ogg
tp_priest_scan_03.ogg

tp_priest_emergency_01.ogg
tp_priest_emergency_02.ogg
```

### Station Sounds

```text
tp_station_link_established_01.ogg
tp_station_link_established_02.ogg

tp_station_link_broken_01.ogg
tp_station_link_broken_02.ogg
```

### Machine Sanctity Sounds

```text
tp_machine_low_sanctity_warning_01.ogg
tp_machine_low_sanctity_warning_02.ogg
tp_machine_low_sanctity_warning_03.ogg

tp_machine_detritus_clog_01.ogg
tp_machine_detritus_clog_02.ogg
```

### GUI Sounds

```text
tp_gui_button_press_01.ogg
tp_gui_button_press_02.ogg

tp_gui_panel_open_01.ogg
tp_gui_panel_close_01.ogg

tp_gui_tab_change_01.ogg
tp_gui_portrait_select_01.ogg
```

## Gameplay Meaning By Asset Group

### Priest Repair

The player should understand: a Tech Priest is repairing physical damage.

This should sound practical, mechanical, and hands-on. Use ratchets, tiny tool clicks, solder snaps, cable tightening, and servo wrist movement. It must not sound like sanctification, magic healing, or clean futuristic maintenance.

### Priest Sanctification / Oil Application

The player should understand: a Tech Priest is applying sacred machine oil or performing a small maintenance rite.

This should sound oily, ritualized, mechanical, and slightly reverent without becoming a fantasy spell. Use applicator hiss, viscous spray, brush movement, quiet relay chatter, and faint broken vox murmurs with no intelligible speech.

### Priest Scan

The player should understand: a priest or station is checking inventory, resources, machines, or surroundings.

This should be short, dry, and subtle. Use auspex sweep, optical lens adjustment, low data chirp, and static tick. It must not sound like a weapon laser or high-tech clean scanner.

### Priest Emergency

The player should understand: something has gone wrong and emergency behavior has begun.

This should be serious but not modern. Use low warning tone, broken shrine relay, failing vox speaker, and grim mechanical acknowledgement. Avoid modern sirens and overlarge cinematic alarms.

### Station Link Established

The player should understand: a Cogitator Station and Tech Priest have successfully paired.

This should sound like a sacred data handshake: relay clack, brass latch, low confirmation tone, and tiny cogitator chirp.

### Station Link Broken

The player should understand: the station/priest relationship is abnormal, severed, missing, or invalid.

This should sound like a broken vox tether, failed relay, corrupted handshake, or cut control wire. It should be clearly different from death/explosion sounds.

### Low Sanctity Warning

The player should understand: a machine is spiritually and mechanically degraded.

Use bearing grind, bad combustion cough, belt slip, failing capacitor, electrical misfire, and a low unhappy mechanical groan. This should be occasional and cooldown-limited.

### Detritus Clog

The player should understand: mechanical detritus or poor machine condition is obstructing smooth operation.

Use chunking, jammed gears, metal grit, caught belt, hopper obstruction, and ugly internal machine strain.

### GUI Feedback

The player should understand: the custom interface accepted input or moved panels.

Use diegetic cogitator-shrine sounds: brass tab clack, relay switch, parchment-mechanical slide, tiny static pop, shrine lens alignment, old data-slate detent. Avoid clean modern button beeps.

## Playback Rules

Sounds should only play on meaningful events or state transitions.

Do not play sound from internal task churn, one-tick state changes, repeated validation checks, or every update tick.

### Approved Sound Triggers

- repair action begins
- sanctification action begins or succeeds
- scan action begins or completes
- emergency mode is entered
- station/priest pair is created
- station/priest pair is detected as broken or invalid
- machine crosses a low sanctity threshold
- detritus clog state begins or blocks operation
- GUI button is clicked
- GUI panel opens or closes
- GUI tab changes
- portrait selection changes

### Avoided Sound Triggers

- every on_tick update
- every task-state check
- every repair progress increment
- every sanctity numeric update
- every inventory polling operation
- every failed pathing attempt
- every internal AI branch evaluation
- every temporary state flicker

## Cooldown Rules

A sound helper should determine whether a sound category may play from an entity before playback occurs.

Concept:

```text
Can this sound category play from this entity right now?
```

Recommended first-pass cooldowns:

```text
repair sound: 180 ticks
sanctification sound: 240 ticks
scan sound: 120 ticks
emergency sound: 1800 ticks
station link established: no repeat unless new pairing occurs
station link broken: 600 ticks
low sanctity warning: 1800 to 3600 ticks, preferably randomized
detritus clog: 900 ticks
GUI button: minimal or no cooldown
GUI panel open/close: no cooldown
```

Cooldowns should be per sound category, not only global. Repair sounds should not block emergency warnings. Emergency warnings should not block GUI sounds. Repeated repair sounds should still be controlled.

## Implementation Map

```text
repair_start
→ tp_priest_repair_01/02/03

sanctification_start
→ tp_priest_sanctify_oil_01/02/03

scan_start
→ tp_priest_scan_01/02/03

emergency_mode_entered
→ tp_priest_emergency_01/02

station_pair_created
→ tp_station_link_established_01/02

station_pair_broken
→ tp_station_link_broken_01/02

machine_low_sanctity_threshold_crossed
→ tp_machine_low_sanctity_warning_01/02/03

machine_detritus_clogged
→ tp_machine_detritus_clog_01/02

gui_button_click
→ tp_gui_button_press_01/02

gui_panel_open
→ tp_gui_panel_open_01

gui_panel_close
→ tp_gui_panel_close_01

gui_tab_changed
→ tp_gui_tab_change_01

gui_portrait_selected
→ tp_gui_portrait_select_01
```

## Technical Export Baseline

Recommended target format:

```text
Format: OGG Vorbis
Sample rate: 44.1 kHz or 48 kHz
Channels: mono for positional in-world effects; mono or subtle stereo for GUI/ambience
One-shots: short fade-out tail to prevent clipping
Loops: clean loop points, no audible click at seam
Volume: conservative, not peak-slammed
```

Most first-pass sounds should be mono because they are in-world positional effects or short UI responses.

## Testing Checklist

Before accepting a sound into the mod, test these questions:

- Does the sound tell the player what happened?
- Does it become annoying after five minutes?
- Does it fire too often?
- Does it overlap badly with itself?
- Can the player distinguish repair from sanctification?
- Can the player distinguish scan from GUI?
- Does emergency mode sound serious without becoming a siren nightmare?
- Does the low sanctity warning sound like machine degradation rather than combat?
- Does the station link sound feel like a sacred machine handshake?
- Does the broken-link sound feel abnormal without sounding like a death explosion?
- Are repeated sounds variant-randomized?
- Are cooldowns working?
- Are GUI sounds short enough to tolerate repeated clicking?

## Future Expansion Notes

After the first functional audio layer works, later passes may add:

- Cogitator Station idle loop
- Cogitator Station active coordination loop
- rank-specific Tech Priest footsteps
- junior/intermediate/senior servo movement differences
- senior Tech Priest mechadendrite idle sounds
- fuller emergency machine behavior soundscape
- ritual chanting texture without intelligible speech
- machine sanctity restoration sounds
- major machine backlash sounds
- station death overlay sounds
- doctrine unlock sounds
- orbital trader interface sounds
- offworld cargo/cogitator component handling sounds

These should not be added until the first-pass event hooks and cooldown system are stable.

## Development Reminder

Audio should clarify the mod. It should not become another source of noise, state flicker, or invisible complexity.

The player should hear meaningful events, not every private thought inside the Tech Priest task machine.
