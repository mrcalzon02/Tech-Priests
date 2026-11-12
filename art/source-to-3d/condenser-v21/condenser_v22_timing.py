"""Deterministic, Blender-free timing for the source-locked condenser V22 motion.

Eight intake heads operate sequentially, one per 12-frame slot.  Eight
slots make a 96-frame / 8-fps (12-second) cycle.  Frame 97 matches frame 1.
"""
from __future__ import annotations
import math

HEADS = 8
CYCLE = 96
SLOT = CYCLE // HEADS
FPS = 8
STROKE = 0.058  # Blender scene units; this condenser uses 1 unit per tile.
PREVIEW_FRAMES = tuple(range(1, CYCLE + 1, 3))


def clamp(value: float) -> float:
    return max(0.0, min(1.0, value))


def ease(value: float) -> float:
    p = clamp(value)
    return p * p * (3.0 - 2.0 * p)


def slot_phase(frame: int) -> tuple[int, float]:
    offset = (frame - 1) % CYCLE
    return int(offset // SLOT), (offset % SLOT) / SLOT


def lift(phase: float) -> float:
    """Ease up, hold for intake, then reseat; never overlap another head."""
    if phase < 0.08:
        return 0.0
    if phase < 0.33:
        return ease((phase - 0.08) / 0.25)
    if phase < 0.66:
        return 1.0
    if phase < 0.95:
        return 1.0 - ease((phase - 0.66) / 0.29)
    return 0.0


def head_lift(frame: int, head: int) -> float:
    current, phase = slot_phase(frame)
    return STROKE * lift(phase) if head == current else 0.0


def inward_stream(frame: int, head: int) -> tuple[float, float]:
    """Curve bevel bounds: a short visible segment moves outside -> INLET.

    At inactivity both bounds coincide, making a zero-length wisp rather than
    expelling one.  Data is shared by all 3 stream strands on the active head.
    """
    current, phase = slot_phase(frame)
    if current != head or phase <= 0.12 or phase >= 0.91:
        return 0.0, 0.0
    progress = ease((phase - 0.12) / 0.79)
    end = clamp(1.30 * progress)
    start = max(0.0, end - 0.38)
    return start, end


def signals(frame: int) -> dict[str, float]:
    """Small original indicator covers; intake amber, run green, rare red tick."""
    current, phase = slot_phase(frame)
    return {
        'red': 0.025 + (0.20 if current in (0, 4) and 0.60 <= phase < 0.75 else 0.0),
        'amber': 0.025 + (0.95 if 0.24 <= phase < 0.83 else 0.0),
        'green': 0.10 + (0.30 if (int(((frame - 1) % CYCLE) / 6) % 2 == 0) else 0.0),
        'lcd': 0.08 + 0.09 * (1.0 + math.sin(2.0 * math.pi * ((frame - 1) % CYCLE) / CYCLE * 3)) / 2.0,
    }


def snake_order(positions: list[tuple[str, float, float]]) -> list[str]:
    """Visually sweep across a 4x2 rack, then back along its second row.

    positions = [(approved source name, world x, world y), ...]. The model's
    original coordinates decide the order; names/digits do not assume layout.
    """
    if len(positions) != HEADS or len({p[0] for p in positions}) != HEADS:
        raise ValueError('Expected eight individually named original canisters')
    by_y = sorted(positions, key=lambda p: (p[2], p[1]))
    a, b = by_y[:4], by_y[4:]
    if abs(sum(x[2] for x in b) / 4 - sum(x[2] for x in a) / 4) < 0.08:
        raise ValueError('No distinct 4x2 canister rows found')
    forward = sorted(a, key=lambda p: p[1])
    reverse = sorted(b, key=lambda p: p[1], reverse=True)
    return [p[0] for p in forward + reverse]
