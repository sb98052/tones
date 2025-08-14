#!/usr/bin/env python3
"""
Modular practice-session player.
– Chooses a random major key
– Plays the full octave once (names + degrees)
– Then free-plays random chunks, scales, arpeggios, and chords
   while printing **only scale degrees** during that free play.
"""

from __future__ import annotations

import os
import random
import time
from pathlib import Path
from dataclasses import dataclass, field
from typing import Iterable, List, Sequence

import pygame

# ──────────────────────────────
# 1.  CONSTANTS & HELPERS
# ──────────────────────────────
SOUND_FOLDER = Path("notes")
MIN_OCTAVE   = 3
MAX_OCTAVE   = 5
NOTE_DURATION_SEC     = 1.0
SESSION_DURATION_SEC  = 40 * 60   # 40 min

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
    ['C','D','E','F','G','A','B'],            # C
    ['G','A','B','C','D','E','Gb'],           # G
    ['F','G','A','Bb','C','D','E'],           # F
    ['D','E','Gb','G','A','B','Db'],          # D
    ['A','B','Db','D','E','Gb','Ab'],         # A
    ['E','Gb','Ab','A','B','Db','Eb'],        # E
    ['B','Db','Eb','E','Gb','Ab','Bb'],       # B
    ['Gb','Ab','Bb','B','Db','Eb','F'],       # F♯
    ['Bb','C','D','Eb','F','G','A'],          # B♭
    ['Eb','F','G','Ab','Bb','C','D'],         # E♭
    ['Ab','Bb','C','Db','Eb','F','G'],        # A♭
    ['Db','Eb','F','Gb','Ab','Bb','C'],       # D♭
    ['Gb','Ab','Bb','B','Db','Eb','F'],       # G♭
    ['B','Db','Eb','E','Gb','Ab','Bb'],       # C♭
]

def wrap(idx: int, mod: int) -> int:
    return (idx + mod) % mod


# ──────────────────────────────
# 2.  KEY BUILDER
# ──────────────────────────────
@dataclass(frozen=True)
class KeyBuilder:
    signature: Sequence[str]
    min_octave: int = MIN_OCTAVE
    max_octave: int = MAX_OCTAVE
    expanded: list[str] = field(init=False)

    def __post_init__(self) -> None:
        object.__setattr__(self, "expanded", self._expand())

    def _expand(self) -> list[str]:
        out: list[str] = []
        octave = self.min_octave
        prev: str | None = None
        while octave <= self.max_octave:
            for note in self.signature:
                if prev and NOTE_TO_SEMITONE[prev] > NOTE_TO_SEMITONE[note]:
                    octave += 1
                    if octave > self.max_octave:
                        break
                out.append(f"{note}{octave}")
                prev = note
            else:
                continue
            break
        return out

    def degree(self, note: str) -> int:
        return self.signature.index(note[:-1])  # 0-based


# ──────────────────────────────
# 3.  SOUND PLAYER
# ──────────────────────────────
class SoundPlayer:
    def __init__(self,
                 sound_folder: Path = SOUND_FOLDER,
                 channels: int = 32,
                 note_duration: float = NOTE_DURATION_SEC,
                 volume: float = 1.0) -> None:

        pygame.mixer.init()
        pygame.mixer.set_num_channels(channels)
        self.folder = sound_folder
        self.duration = note_duration
        self.volume   = volume

    # internal loader
    def _snd(self, name: str) -> pygame.mixer.Sound:
        path = self.folder / f"{name}.mp3"
        if not path.exists():
            raise FileNotFoundError(path)
        return pygame.mixer.Sound(str(path))

    # SINGLE NOTE ----------------------------------------------------------
    def play_note(self,
                  note: str,
                  *,
                  show_name: bool,
                  degree: int | None = None) -> None:
        if show_name:
            label = f"{note}{f' ({degree+1})' if degree is not None else ''}"
        else:  # degree-only
            label = f"({degree+1 if degree is not None else '-'})"
        print("→", label)
        ch = self._snd(note).play(loops=0, maxtime=int(self.duration*1000))
        ch.set_volume(self.volume)
        time.sleep(self.duration)
        ch.stop()

    # CHORD ---------------------------------------------------------------
    def play_chord(self,
                   notes: Iterable[str],
                   *,
                   show_names: bool,
                   degrees: Iterable[int]) -> None:
        deg_lst = list(degrees)
        if show_names:
            deg_text = ", ".join(f"{n}({d+1})" for n, d in zip(notes, deg_lst))
        else:
            deg_text = ", ".join(f"({d+1})" for d in deg_lst)
        print("→ CHORD", deg_text)
        chans = [self._snd(n).play(loops=0,
                                   maxtime=int(self.duration*1000))
                 for n in notes]
        for ch in chans:
            ch.set_volume(self.volume)
        time.sleep(self.duration)
        for ch in chans:
            ch.stop()


# ──────────────────────────────
# 4.  CHUNK GENERATOR
# ──────────────────────────────
class ChunkGenerator:
    def __init__(self, key: KeyBuilder) -> None:
        self.key = key
        self.scale = key.expanded

    def random_chunk(self) -> list[str]:
        return random.choices(self.scale, k=random.randint(1, 7))

    def scale_chunk(self) -> list[str]:
        size  = random.randint(3, 12)
        start = random.randrange(len(self.scale))
        step  = 1 if random.choice([True, False]) else -1
        return [self.scale[wrap(start + i*step, len(self.scale))]
                for i in range(size)]

    def _arp_like(self, block: bool) -> list[str]:
        size = random.randint(3, 17)
        root = random.randrange(len(self.scale))
        out, cur = [], root
        intervals = (2, 2, 3)   # 1-3-5 cycle
        for i in range(size):
            out.append(self.scale[cur])
            cur = wrap(cur + intervals[i % 3], len(self.scale))
        return out

    def arpeggio_chunk(self) -> list[str]:
        return self._arp_like(False)

    def chord_chunk(self) -> list[str]:
        return self._arp_like(True)


# ──────────────────────────────
# 5.  PRACTICE SESSION
# ──────────────────────────────
class PracticeSession:
    CADENCE_FREQ = 5

    def __init__(self, player: SoundPlayer, gen: ChunkGenerator) -> None:
        self.p   = player
        self.gen = gen
        self.start = time.time()
        self.count = 0

        tonic_idx = [5, 0, 2]  # 3-note I-chord voicing by degree index
        self.cadence_notes = [self.gen.scale[i] for i in tonic_idx]
        self.cadence_degs  = [self.gen.key.degree(n) for n in
                              self.cadence_notes]

    # helper --------------------------------------------------------------
    def _time_left(self) -> bool:
        return (time.time() - self.start) < SESSION_DURATION_SEC

    def _cadence_if_needed(self) -> None:
        if self.count % self.CADENCE_FREQ == 0:
            self.p.play_chord(self.cadence_notes,
                              show_names=False,
                              degrees=self.cadence_degs)
            self.p.play_chord(self.cadence_notes,
                              show_names=False,
                              degrees=self.cadence_degs)

    # main loop -----------------------------------------------------------
    def run(self) -> None:
        try:
            print("\n▶ Initial scale walk:")
            for i, n in enumerate(self.gen.scale[5:13], start=5):
                self.p.play_note(n, show_name=True, degree=i-5)

            print("\n▶ Free play:")
            while self._time_left():
                ctype = random.choice(
                    ['random', 'scale', 'arpeggio', 'chord'])
                notes = getattr(self.gen, f"{ctype}_chunk")()
                if len(notes) < 3:
                    continue
                if random.choice([True, False]):
                    notes.reverse()

                self._cadence_if_needed()
                degs = [self.gen.key.degree(n) for n in notes]

                if ctype == 'chord':
                    self.p.play_chord(notes, show_names=False, degrees=degs)
                    time.sleep(6)
                    self.p.play_chord(notes, show_names=False, degrees=degs)

                elif ctype == 'arpeggio':
                    for n, d in zip(notes, degs):
                        self.p.play_note(n, show_name=False, degree=d)
                    time.sleep(6)
                    for n, d in zip(notes, degs):
                        self.p.play_note(n, show_name=False, degree=d)

                else:  # random / scale
                    for n, d in zip(notes, degs):
                        self.p.play_note(n, show_name=False, degree=d)

                self.count += 1

            print("\nSession complete—nice job!")

        except KeyboardInterrupt:
            print("\nSession interrupted.")
        finally:
            pygame.mixer.stop()
            pygame.quit()


# ──────────────────────────────
# 6.  ENTRY POINT
# ──────────────────────────────
def main() -> None:
    sig = random.choice(KEY_SIGNATURES)
    key = KeyBuilder(sig)
    print("Selected key:", " ".join(sig))
    player = SoundPlayer()
    PracticeSession(player, ChunkGenerator(key)).run()

if __name__ == "__main__":
    main()
