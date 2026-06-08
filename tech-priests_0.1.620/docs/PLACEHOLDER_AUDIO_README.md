# Tech Priests Placeholder Audio Batch

This package contains procedural placeholder OGG files for testing Tech Priests audio hooks before final sound-design work. These sounds are intentionally simple, synthetic, and conservative. Their purpose is to verify that event wiring, cooldowns, variation selection, volume, and repetition behavior are sane before final generated or hand-edited audio replaces them.

## Contents

- `docs/AUDIO_MANIFEST.md`
- `docs/AUDIO_GENERATION_PROMPTS.md`
- `sound/tech-priests/*.ogg`

## Use Notes

Treat these as temporary implementation placeholders. Do not judge the final artistic direction from these files alone. Judge whether the correct event fires, whether it fires too often, whether repair is distinguishable from sanctification, and whether GUI sounds are short enough to avoid irritation.

## Replacement Rule

Final assets should keep these filenames unless the manifest is intentionally revised. This prevents unnecessary Lua churn.
