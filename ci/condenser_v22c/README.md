# Condenser V22C — REAL graphical Factorio capture

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

Core30 already produces Blender Cycles frames and passes headless Factorio pipe acceptance; the Steam label routed to Core30 but its Actions process is a Windows service, not an interactive game session. For repeated unattended **graphical** game capture, register a separate reusable Windows runner inside the logged-on desktop under its own directory with a **gui-desktop** execution label; keep the existing service runner for Blender, builds and headless game validation. Do not elevate the service, weaken Windows permissions or create extra project-only machine labels.

The included desktop CMD/PowerShell launcher is the immediate non-admin route while that permanent interactive runner is not configured.
