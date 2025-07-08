#!/usr/bin/env python3
"""
Practice session – modular refactor of the original monolithic script.
Author: <you>
"""

from __future__ import annotations

import os
import random
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import Iterable, List, Sequence

import pygame


# ──────────────────────────────────────────────────────────────────────────────
# 1.  CONSTANTS & HELPERS
# ──────────────────────────────────────────────────────────────────────────────
SOUND_FOLDER = Path("notes")               # folder containing *.mp3
MIN_OCTAVE   = 3
MAX_OCTAVE   = 5
NOTE_DURATION_SEC = 1.0
SESSION_DURATION_SEC = 40 * 60            # 40 minutes

NOTE_TO_SEMITONE = {
    'C': 0,  'C#': 1,  'Db': 1,
    'D': 2,  'D#': 3,  'Eb': 3,
    'E': 4,  'Fb': 4,  'E#': 5,
    'F': 5,  'F#': 6,  'Gb': 6,
    'G': 7,  'G#': 8,  'Ab': 8,
    'A': 9,  'A#': 10, 'Bb': 10,
    'B': 11, 'Cb': 11,
}

KEY_SIGNATURES: list[list[str]] = [
    ['C',  'D',  'E',  'F',  'G',  'A',  'B'],          # C
    ['G',  'A',  'B',  'C',  'D',  'E',  'Gb'],         # G (F♯ → G♭)
    ['F',  'G',  'A',  'Bb', 'C',  'D',  'E'],          # F
    ['D',  'E',  'Gb', 'G',  'A',  'B',  'Db'],         # D
    ['A',  'B',  'Db', 'D',  'E',  'Gb', 'Ab'],         # A
    ['E',  'Gb', 'Ab', 'A',  'B',  'Db', 'Eb'],         # E
    ['B',  'Db', 'Eb', 'E',  'Gb', 'Ab', 'Bb'],         # B
    ['Gb', 'Ab', 'Bb', 'B',  'Db', 'Eb', 'F'],          # F♯ major
    ['Bb', 'C',  'D',  'Eb', 'F',  'G',  'A'],          # B♭
    ['Eb', 'F',  'G',  'Ab', 'Bb', 'C',  'D'],          # E♭
    ['Ab', 'Bb', 'C',  'Db', 'Eb', 'F',  'G'],          # A♭
    ['Db', 'Eb', 'F',  'Gb', 'Ab', 'Bb', 'C'],          # D♭
    ['Gb', 'Ab', 'Bb', 'B',  'Db', 'Eb', 'F'],          # G♭
    ['B',  'Db', 'Eb', 'E',  'Gb', 'Ab', 'Bb'],         # C♭
]


def wrap(index: int, modulus: int) -> int:
    """Modulo that always returns a positive number in [0, modulus)."""
    return (index + modulus) % modulus


# ──────────────────────────────────────────────────────────────────────────────
# 2.  KEY BUILDER
# ──────────────────────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class KeyBuilder:
    signature: Sequence[str]
    min_octave: int = MIN_OCTAVE
    max_octave: int = MAX_OCTAVE
    expanded: list[str] = field(init=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "expanded", self._expand())

    # --------------------------------------------------------------------- #
    def _expand(self) -> list[str]:
        """Return ['C3', 'D3', …, 'B5'] for the given signature."""
        out: list[str] = []
        octave = self.min_octave
        prev_note: str | None = None

        while octave <= self.max_octave:
            for note in self.signature:
                if prev_note and NOTE_TO_SEMITONE[prev_note] > NOTE_TO_SEMITONE[note]:
                    octave += 1
                    if octave > self.max_octave:
                        break
                out.append(f"{note}{octave}")
                prev_note = note
            else:
                continue
            break     # loop was broken – stop outer loop
        return out

    # --------------------------------------------------------------------- #
    def degree(self, note: str) -> int:
        """Return degree (0–6) of a note relative to the underlying scale."""
        base = note[:-1]   # strip octave
        return self.signature.index(base)


# ──────────────────────────────────────────────────────────────────────────────
# 3.  SOUND PLAYER
# ──────────────────────────────────────────────────────────────────────────────
class SoundPlayer:
    def __init__(self,
                 sound_folder: Path = SOUND_FOLDER,
                 channels: int = 32,
                 note_duration: float = NOTE_DURATION_SEC,
                 volume: float = 1.0) -> None:

        pygame.mixer.init()
        pygame.mixer.set_num_channels(channels)

        self.sound_folder = sound_folder
        self.note_duration = note_duration
        self.volume = volume

    # --------------------------------------------------------------------- #
    def _load(self, note: str) -> pygame.mixer.Sound:
        file_path = self.sound_folder / f"{note}.mp3"
        if not file_path.exists():
            raise FileNotFoundError(f"Missing sample: {file_path}")
        return pygame.mixer.Sound(str(file_path))

    # --------------------------------------------------------------------- #
    def play_note(self, note: str, annotate: str | None = None) -> None:
        label = f"{note}{' '+annotate if annotate else ''}"
        print(f"→ {label}")
        sound = self._load(note)
        chan = sound.play(loops=0, maxtime=int(self.note_duration * 1000))
        chan.set_volume(self.volume)
        time.sleep(self.note_duration)     # block until done
        chan.stop()

    # --------------------------------------------------------------------- #
    def play_chord(self, notes: Iterable[str]) -> None:
        notes = list(notes)
        print("→ CHORD:", ", ".join(notes))
        channels: list[pygame.mixer.Channel] = []

        for n in notes:
            snd = self._load(n)
            ch  = snd.play(loops=0, maxtime=int(self.note_duration * 1000))
            ch.set_volume(self.volume)
            channels.append(ch)

        time.sleep(self.note_duration)
        for ch in channels:
            ch.stop()


# ──────────────────────────────────────────────────────────────────────────────
# 4.  CHUNK GENERATOR
# ──────────────────────────────────────────────────────────────────────────────
class ChunkGenerator:
    def __init__(self, key: KeyBuilder) -> None:
        self.key = key
        self.scale = key.expanded

    # --------------------------------------------------------------------- #
    def random_chunk(self) -> list[str]:
        size  = random.randint(1, 7)
        return random.choices(self.scale, k=size)

    # --------------------------------------------------------------------- #
    def scale_chunk(self) -> list[str]:
        size   = random.randint(3, 12)
        start  = random.randrange(len(self.scale))
        step   = 1 if random.choice([True, False]) else -1
        return [self.scale[wrap(start + i * step, len(self.scale))]
                for i in range(size)]

    # --------------------------------------------------------------------- #
    def _arpeggio_like(self, *, block: bool) -> list[str]:
        size   = random.randint(3, 17)
        root_i = random.randrange(len(self.scale))
        intervals = (2, 2, 3)   # 1–3–5 pattern
        notes: list[str] = []
        cursor = root_i
        for i in range(size):
            notes.append(self.scale[cursor])
            cursor = wrap(cursor + intervals[i % 3], len(self.scale))
        if block:    # chord
            return notes
        return notes

    def arpeggio_chunk(self) -> list[str]:
        return self._arpeggio_like(block=False)

    def chord_chunk(self) -> list[str]:
        return self._arpeggio_like(block=True)


# ──────────────────────────────────────────────────────────────────────────────
# 5.  PRACTICE SESSION (the event loop)
# ──────────────────────────────────────────────────────────────────────────────
class PracticeSession:
    CADENCE_FREQ = 5

    def __init__(self, player: SoundPlayer, generator: ChunkGenerator) -> None:
        self.player = player
        self.gen    = generator
        self.start  = time.time()
        self.counter = 0

        # tonic major-triad as cadence I chord
        tonic_idx = [5, 0, 2]   # 3-note voicing: 3 | 1 | 5 (by scale index)
        self.cadence_chord = [self.gen.scale[i] for i in tonic_idx]

    # --------------------------------------------------------------------- #
    def _still_running(self) -> bool:
        return (time.time() - self.start) < SESSION_DURATION_SEC

    # --------------------------------------------------------------------- #
    def _maybe_cadence(self) -> None:
        if self.counter % self.CADENCE_FREQ == 0:
            self.player.play_chord(self.cadence_chord)
            self.player.play_chord(self.cadence_chord)

    # --------------------------------------------------------------------- #
    def run(self) -> None:
        try:
            print("\nPlaying full octave scale before free-play:")
            for i, note in enumerate(self.gen.scale[5:13], start=5):
                self.player.play_note(note, f"({i - 4})")
            print("…and we’re off!\n")

            while self._still_running():
                chunk_type = random.choice(
                    ['random', 'scale', 'arpeggio', 'chord']
                )
                producer = {
                    'random':   self.gen.random_chunk,
                    'scale':    self.gen.scale_chunk,
                    'arpeggio': self.gen.arpeggio_chunk,
                    'chord':    self.gen.chord_chunk,
                }[chunk_type]

                notes = producer()
                if len(notes) < 3:
                    continue
                if random.choice([True, False]):
                    notes.reverse()

                self._maybe_cadence()
                print(f"\nPlaying {chunk_type} of {len(notes)} notes")
                if chunk_type == 'chord':
                    self.player.play_chord(notes)
                    time.sleep(6)
                    self.player.play_chord(notes)
                elif chunk_type == 'arpeggio':
                    for n in notes:
                        self.player.play_note(n, str(self.gen.key.degree(n)+1))
                    time.sleep(6)
                    for n in notes:
                        self.player.play_note(n, str(self.gen.key.degree(n)+1))
                else:   # random / scale
                    for n in notes:
                        self.player.play_note(n, str(self.gen.key.degree(n)+1))

                self.counter += 1

            print("\nSession complete – nice job!")

        except KeyboardInterrupt:
            print("\nSession interrupted by user.")
        finally:
            pygame.mixer.stop()
            pygame.quit()


# ──────────────────────────────────────────────────────────────────────────────
# 6.  ENTRY POINT
# ──────────────────────────────────────────────────────────────────────────────
def main() -> None:
    selected_signature = random.choice(KEY_SIGNATURES)
    key = KeyBuilder(selected_signature)
    print("Selected key :", selected_signature)
    player = SoundPlayer()
    generator = ChunkGenerator(key)
    PracticeSession(player, generator).run()


if __name__ == "__main__":
    main()
