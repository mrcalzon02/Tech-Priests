"""Generate the original Tech-Priests event sounds with Python and FFmpeg."""

import argparse
import csv
import math
import random
import struct
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RATE = 44100
TAU = 2 * math.pi


class Sound:
    def __init__(self, duration, seed):
        self.samples = [0.0] * round(duration * RATE)
        self.random = random.Random(seed)
        self.tuning = self.random.uniform(0.93, 1.07)

    def add(self, start, length, sample):
        first = round(start * RATE)
        count = min(round(length * RATE), len(self.samples) - first)
        for index in range(count):
            time = index / RATE
            fade = min(1, index / 28, (count - index - 1) / 120)
            self.samples[first + index] += sample(time) * fade

    def metal(self, start, pitch, strength, decay):
        ratios = (1.0, 1.51, 2.69, 4.07, 6.25)
        weights = (0.28, 0.36, 0.22, 0.11, 0.05)
        modes = [(TAU * pitch * self.tuning * ratio, weight)
                 for ratio, weight in zip(ratios, weights)]

        def sample(time):
            ring = sum(weight * math.sin(frequency * time) for frequency, weight in modes)
            impact = self.random.uniform(-0.3, 0.3) * math.exp(-time / 0.003)
            return strength * (ring * math.exp(-time / decay) + impact)

        self.add(start, decay * 5, sample)

    def noise(self, start, length, low, high, strength, flutter=0):
        slow = 0.0
        fast = 0.0
        lower = 1 - math.exp(-TAU * low / RATE)
        upper = 1 - math.exp(-TAU * high / RATE)

        def sample(time):
            nonlocal slow, fast
            grain = self.random.uniform(-1, 1)
            fast += upper * (grain - fast)
            slow += lower * (fast - slow)
            pulse = 0.58 + 0.42 * math.sin(TAU * flutter * time + 1.4)
            shape = math.sin(math.pi * time / length) ** 0.65
            return strength * (fast - slow) * pulse * shape

        self.add(start, length, sample)

    def motor(self, start, length, low, high, strength, pulse):
        low *= self.tuning
        sweep = (high * self.tuning - low) / length

        def sample(time):
            phase = TAU * (low * time + 0.5 * sweep * time * time)
            chatter = math.sin(TAU * pulse * time)
            carrier = (0.55 * math.sin(phase + 0.5 * chatter)
                       + 0.28 * math.sin(2 * phase)
                       + 0.12 * math.sin(3.03 * phase + chatter))
            shape = math.sin(math.pi * time / length) ** 0.8
            return strength * carrier * shape * (0.74 + 0.26 * chatter)

        self.add(start, length, sample)

    def pcm(self, peak):
        level = peak / max(abs(sample) for sample in self.samples)
        return struct.pack(f"<{len(self.samples)}h",
                           *(round(sample * level * 32767) for sample in self.samples))


def repair(sound, length):
    sound.motor(0.015, 0.18, 152, 316, 0.14, 34)
    start = 0.029
    for step in range(7):
        sound.metal(start, 820 - 38 * step, 0.32 - step * 0.022, 0.016)
        start += sound.random.uniform(0.033, 0.055)
    sound.noise(0.27, 0.14, 530, 4100, 0.42, 48)
    sound.metal(0.42, 510, 0.31, 0.024)


def oil(sound, length):
    sound.metal(0.038, 540, 0.29, 0.024)
    sound.noise(0.05, 0.49, 480, 4100, 0.58, 19)
    sound.noise(0.20, 0.44, 135, 1100, 0.43, 11)
    sound.motor(0.36, 0.31, 112, 84, 0.10, 26)
    sound.metal(0.64, 385, 0.23, 0.026)


def scan(sound, length):
    sound.metal(0.01, 980, 0.30, 0.010)
    sound.noise(0.025, 0.19, 990, 5400, 0.41, 65)
    sound.motor(0.05, 0.14, 315, 610, 0.13, 44)
    sound.metal(length - 0.041, 780, 0.17, 0.010)


def emergency(sound, length):
    sound.metal(0.041, 360, 0.45, 0.043)
    for start, duration in ((0.12, 0.34), (0.51, 0.23), (0.86, 0.39)):
        sound.motor(start, duration, 166, 102, 0.39, 48)
        sound.noise(start, duration, 280, 1900, 0.44, 22)
    sound.metal(1.26, 278, 0.31, 0.047)


def link_established(sound, length):
    sound.metal(0.025, 710, 0.33, 0.022)
    sound.noise(0.05, 0.14, 470, 3200, 0.27, 43)
    sound.metal(0.153, 431, 0.39, 0.041)
    sound.motor(0.16, 0.23, 136, 149, 0.17, 27)


def link_broken(sound, length):
    sound.metal(0.018, 690, 0.23, 0.017)
    sound.metal(0.067, 548, 0.32, 0.020)
    sound.motor(0.075, 0.24, 204, 53, 0.24, 57)
    sound.noise(0.09, 0.30, 620, 4600, 0.48, 24)
    sound.metal(0.438, 335, 0.28, 0.022)


def sanctity_warning(sound, length):
    sound.motor(0.02, length - 0.06, 91, 49, 0.44, 18)
    sound.noise(0.07, length - 0.1, 180, 1800, 0.49, 26)
    sound.metal(0.22, 290, 0.21, 0.047)
    sound.metal(0.58, 260, 0.26, 0.042)


def detritus(sound, length):
    sound.motor(0.08, length - 0.18, 153, 43, 0.29, 31)
    sound.noise(0.12, length - 0.20, 540, 3600, 0.60, 35)
    for start, pitch in ((0.045, 420), (0.16, 325), (0.34, 260), (length - 0.12, 196)):
        sound.metal(start, pitch, 0.36, 0.038)


def button(sound, length):
    sound.metal(0.002, 1120, 0.42, 0.006)
    sound.metal(0.013, 570, 0.28, 0.006)


def panel_open(sound, length):
    sound.metal(0.012, 591, 0.25, 0.013)
    sound.noise(0.024, 0.17, 400, 2800, 0.49, 33)
    sound.metal(0.18, 816, 0.37, 0.018)


def panel_close(sound, length):
    sound.noise(0.008, 0.10, 330, 2200, 0.43, 26)
    sound.metal(0.095, 338, 0.42, 0.018)


def tab(sound, length):
    sound.noise(0.011, 0.075, 640, 4100, 0.46, 43)
    sound.metal(0.065, 882, 0.37, 0.012)


def portrait(sound, length):
    sound.metal(0.012, 970, 0.25, 0.012)
    sound.motor(0.033, 0.067, 285, 410, 0.21, 34)
    sound.metal(0.097, 713, 0.37, 0.014)


EVENTS = {
    "gui_button_press": (button, 0.34),
    "gui_panel_open": (panel_open, 0.32),
    "gui_panel_close": (panel_close, 0.32),
    "gui_tab_change": (tab, 0.32),
    "gui_portrait_select": (portrait, 0.32),
    "machine_detritus_clog": (detritus, 0.54),
    "machine_low_sanctity_warning": (sanctity_warning, 0.48),
    "priest_emergency": (emergency, 0.53),
    "priest_repair": (repair, 0.48),
    "priest_sanctify_oil": (oil, 0.47),
    "priest_scan": (scan, 0.37),
    "station_link_broken": (link_broken, 0.49),
    "station_link_established": (link_established, 0.46),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--output", type=Path, default=ROOT / "tech-priests_src/sound/tech-priests")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    index = ROOT / "tech-priests_src/docs/PLACEHOLDER_AUDIO_INDEX.tsv"
    with index.open(newline="", encoding="utf-8") as stream:
        for seed, row in enumerate(csv.DictReader(stream, delimiter="\t"), 20261124):
            filename = row["filename"]
            event, _ = filename.removeprefix("tp_").rsplit("_", 1)
            render, peak = EVENTS[event]
            duration = float(row["duration"].removesuffix("s"))
            sound = Sound(duration, seed)
            render(sound, duration)
            subprocess.run(
                [args.ffmpeg, "-hide_banner", "-loglevel", "error", "-y",
                 "-f", "s16le", "-ar", str(RATE), "-ac", "1", "-i", "pipe:0",
                 "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", "5",
                 str(args.output / filename)],
                input=sound.pcm(peak), check=True,
            )


if __name__ == "__main__":
    main()
