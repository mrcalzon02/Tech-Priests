# Condenser V22C — REAL graphical Factorio capture

## Completed native Steam runner captures (November 12, 2026)

**The game-client capture has now actually run and passed.** The full Windows Factorio 2.1.24 Steam executable on `OLD-CORE30-homebrew` used the explicit **OpenGL** backend in Session 0. Despite the older Direct3D 11 failure, this backend created all **16 native `game.take_screenshot` images**, with 8 physically placed V22C condensers and 8 native pipe connections. The first run was too dark (`daytime=0.5`); a corrected `daytime=0.0` daylight rerender also passed.

- [Successful initial native GUI run](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43352134779)
- [Successful daylight native GUI run](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43352927548)
- [Published genuine in-game four-direction contact PNG](../../art/source-to-3d/condenser-v21/captures/v22c/Condenser_V22C_REAL_Factorio_noonday_four_directions.png)
- [SHA-verified native capture receipt](../../art/source-to-3d/condenser-v21/captures/v22c/Condenser_V22C_REAL_Factorio_native_capture_receipt.json)
- [Manually dispatched private OpenGL capture workflow](https://github.com/mrcalzon02/Dens-Mortis/blob/main/.github/workflows/condenser-v22c-opengl-probe.yml)

The PNG is a thumbnail of the authentic sixteen-image screenshot contact, committed as an actual binary GitHub object to bypass the exhausted Actions artifact quota; the **source images were genuine engine PNGs**, not fabricated. The isolated working directory retains no rights to alter the user's Steam installation or saves. Owner visual approval of fine pipe overlaps and mist appearance is separate from automated engine capture success.

### Execution-mode distinction

The standard local `launch_from_interactive_desktop.ps1` still requires a signed-in desktop and is valid. The proven trusted GitHub worker instead performs a **bounded source-pinned experimental OpenGL Session-0 override** of only that preflight, not of the screenshot integrity checks. The same real Factorio executable and `visual_capture.py` create and verify the screenshots. This backend-specific result must not be generalized to arbitrary Direct3D or Windows GUI applications.


This test captures **actual Factorio 2.1 GUI pixels** of the approved native Blender V22C condenser, not headless logs, Blender previews, or AI-created images. It does **not** modify the production mod, the user profile, any saved game, Windows runner services or the source model.

## Run from the signed-in Steam Windows desktop

**Simplest option:** download the single repository-root launcher
[FETCH_AND_RUN_CONDENSER_V22C_STEAM_GUI.cmd](../../FETCH_AND_RUN_CONDENSER_V22C_STEAM_GUI.cmd)
to the signed-in Steam desktop and double-click it. It requires Git for Windows,
checks out only the production mod, approved Cycles proof and capture scripts,
then invokes the native capture. It keeps its downloaded source and all genuine
evidence under a new Documents/TechPriests-V22C-GUI-* directory.

With a current Tech-Priests checkout already available on that machine, double-click the repository-root file:

**RUN_CONDENSER_V22C_IN_GAME_CAPTURE.cmd**

Or execute in a normal, non-elevated desktop PowerShell:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ci\condenser_v22c\launch_from_interactive_desktop.ps1

If the Steam machine does not already have a checkout, use a bounded sparse clone (requires installed Git):

    git clone --depth 1 --filter=blob:none --sparse https://github.com/mrcalzon02/Tech-Priests.git Tech-Priests
    cd Tech-Priests
    git sparse-checkout set ci/condenser_v22c tech-priests_src art/source-to-3d/condenser-v21/captures/v22c

Then double-click the CMD file from that directory. All required source assets, not merely artwork mockups, are in these paths.

**Do not launch this script as a Windows GitHub Actions service job.** A service executes in Session 0; that environment previously failed SDL/DXGI and cannot supply genuine Factorio images. The Steam-labelled Actions job [#43317134025](https://github.com/mrcalzon02/Dens-Mortis/actions/runs/43317134025) was assigned to OLD-CORE30-homebrew; the labels alone did not establish a usable interactive graphics context.

## Actual native checks and evidence

The script:
1. Verifies its Windows process has a nonzero interactive session ID and refuses to close or interfere with an already running Factorio game.
2. Locates the genuine Steam/standalone Windows Factorio 2.1 client using bounded installation paths, Steam library metadata, and executable version resources as a fallback for silent GUI-subsystem version output.
3. Verifies every approved HR/SD PNG against the committed SHA-256 atlas manifest and the exact V21 source identity.
4. Stages a fresh **isolated mod list, config, save profile, and development Steam app-id** under a unique temporary directory. It does not write into installed game files or the user's normal saves.
5. Starts the real graphical game client with the original tech-priests mod and a disposable visual-test mod. In the world, Factorio itself creates eight actual condensers, eight actually attached fluid pipes, and supplies real coal to the four active machines.
6. Uses the engine's **game.take_screenshot** at normal **1.0×** and close **2.7×** zoom in all four directions, for both idle and working states: **16 authentic 1152×864 PNGs**.
7. Reads all sixteen PNG signatures, dimensions, image diversity, hashes and engine log markers; produces contact sheets and an independently checked ZIP. The comparison sheet contains the original real Blender Cycles proof separately labeled from genuine in-game images.

Output defaults to ci/condenser_v22c/visual-client-<UTC timestamp>/, with a matching .zip after success. The report includes client-capture-qa.json, factorio-gui-client.log, 16 raw engine screenshots, condenser-v22c-real-game-four-directions.png, and client-vs-approved-v22c-blender.png.

**Release/acceptance boundary:** a completed native capture proves authentic screenshots exist; it does not automatically approve visual pipe overlap, body position, or the moving mist. Those still require reviewing the actual game images against the approved source. On failure, client-capture-error.json and native engine logs remain; no screenshots are fabricated and no success marker is emitted.

## Runner architecture

Core30 produces Blender Cycles frames, passes native pipe acceptance, **and now demonstrably captures real Factorio client screenshots via OpenGL in its existing Windows service Session 0**. The `Steam` label routes to Core30. The separate `gui-desktop` registration is still useful for Direct3D clients and applications that cannot render under the verified OpenGL fallback, but is no longer a prerequisite for this condenser's in-game pictures. Keep the existing runner, strict source/PNG validation and normal Windows security boundaries.

The included desktop CMD/PowerShell launcher remains a supported alternative; the existing private GitHub OpenGL workflow is the now-proven unattended route.
