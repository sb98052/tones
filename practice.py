#!/usr/bin/env python3
"""
Practice-session player
  • default minor cadence (vi-ii-iii-vi)
  • --tonality major  → I-IV-V-I
  • Triads appear in random inversions, closed/ascending.
  • Chord-melody: each chord strike is followed one second later
    by the highest note of that voicing.
"""

from __future__ import annotations
import argparse, random, time
from pathlib import Path
from dataclasses import dataclass, field
from typing import Sequence
import pygame

# ── CONFIG ──────────────────────────────────────────────────────────
SOUND_FOLDER          = Path("notes")
MIN_OCTAVE, MAX_OCTAVE = 3, 5
NOTE_DUR              = 1.0
SESSION_DUR           = 40 * 60          # 40 min
NOTE_TO_SEMI = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'Fb':4,'E#':5,
                'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,
                'B':11,'Cb':11}
KEY_SIGS = [
    ['C','D','E','F','G','A','B'],  ['G','A','B','C','D','E','Gb'],
    ['F','G','A','Bb','C','D','E'], ['D','E','Gb','G','A','B','Db'],
    ['A','B','Db','D','E','Gb','Ab'],['E','Gb','Ab','A','B','Db','Eb'],
    ['B','Db','Eb','E','Gb','Ab','Bb'],['Gb','Ab','Bb','B','Db','Eb','F'],
    ['Bb','C','D','Eb','F','G','A'],  ['Eb','F','G','Ab','Bb','C','D'],
    ['Ab','Bb','C','Db','Eb','F','G'],['Db','Eb','F','Gb','Ab','Bb','C'],
    ['Gb','Ab','Bb','B','Db','Eb','F'],['B','Db','Eb','E','Gb','Ab','Bb'],
]
wrap = lambda i,m: (i+m)%m

# ── KEY / SCALE ─────────────────────────────────────────────────────
@dataclass(frozen=True)
class Key:
    sig: Sequence[str]
    min_oct: int = MIN_OCTAVE
    max_oct: int = MAX_OCTAVE
    scale: list[str] = field(init=False)

    def __post_init__(self):
        sc, octv, prev = [], self.min_oct, None
        while octv <= self.max_oct:
            for n in self.sig:
                if prev and NOTE_TO_SEMI[prev] > NOTE_TO_SEMI[n]:
                    octv += 1
                    if octv > self.max_oct: break
                sc.append(f"{n}{octv}")
                prev = n
            else: continue
            break
        object.__setattr__(self, 'scale', sc)

    def degree(self, note: str) -> int:      # 0-based
        return self.sig.index(note[:-1])

# ── AUDIO ───────────────────────────────────────────────────────────
class Player:
    def __init__(self, folder=SOUND_FOLDER, dur=NOTE_DUR, vol=1.0, chans=32):
        pygame.mixer.init(); pygame.mixer.set_num_channels(chans)
        self.f, self.dur, self.vol = folder, dur, vol
    def _snd(self,n): return pygame.mixer.Sound(str(self.f/f"{n}.mp3"))
    def note(self,n,show,deg):
        print("→",f"{n}({deg+1})" if show else f"({deg+1})")
        ch=self._snd(n).play(loops=0,maxtime=int(self.dur*1000))
        ch.set_volume(self.vol); time.sleep(self.dur); ch.stop()
    def chord(self,notes,degs,show):
        label=", ".join(f"{n}({d+1})" for n,d in zip(notes,degs)) if show \
              else ", ".join(f"({d+1})" for d in degs)
        print("→ CHORD",label)
        chs=[self._snd(n).play(loops=0,maxtime=int(self.dur*1000)) for n in notes]
        for c in chs:c.set_volume(self.vol)
        time.sleep(self.dur)
        for c in chs:c.stop()

# ── CHUNK GENERATOR ────────────────────────────────────────────────
class Gen:
    def __init__(self,key:Key):
        self.key,self.scale=key,key.scale; self.len=len(self.scale)
    # closed triad with random inversion
    def triad(self):
        root=random.randrange(0,self.len-9)          # room for 2nd inv.
        inv=random.choice((0,1,2))
        if inv==0: idx=[root,root+2,root+4]          # root
        elif inv==1: idx=[root+2,root+4,root+7]      # 1st
        else: idx=[root+4,root+7,root+9]             # 2nd
        return [self.scale[i] for i in idx]
    # other chunk types
    def random_chunk (self):return random.choices(self.scale,k=random.randint(1,7))
    def scale_chunk  (self):
        size,start=random.randint(3,12),random.randrange(self.len)
        step=1 if random.choice([True,False]) else -1
        return [self.scale[wrap(start+i*step,self.len)] for i in range(size)]
    def arpeggio_chunk(self):
        size,root=random.randint(3,17),random.randrange(self.len)
        ivl,out,cur=(2,2,3),[],root
        for i in range(size):
            out.append(self.scale[cur])
            cur=wrap(cur+ivl[i%3],self.len)
        return out
    chord_chunk        = triad
    chord_melody_chunk = triad

# ── SESSION LOOP ───────────────────────────────────────────────────
class Session:
    CAD_FREQ=5
    def __init__(self,player:Player,gen:Gen,ton:str):
        self.p,self.g,self.ton=player,gen,ton
        self.start,self.count=time.time(),0
        self._cadence()
    # cadence chords (root position)
    def _cadence(self):
        if self.ton=='major': roots=[0,3,4,0]
        else:                 roots=[5,1,2,5]
        self.cad=[]
        for r in roots:
            notes=self.g.triad() if False else [self.g.scale[r],
                                                self.g.scale[r+2],
                                                self.g.scale[r+4]]
            degs=[self.g.key.degree(n) for n in notes]
            self.cad.append((notes,degs))
    # helpers
    def _pitch(self,n): base,octv=n[:-1],int(n[-1]); return octv*12+NOTE_TO_SEMI[base]
    # run
    def run(self):
        try:
            # initial scale walk
            if self.ton=='major':
                for i in range(0,8):
                    n=self.g.scale[i]; self.p.note(n,True,i)
            else:
                for i in range(5,13):
                    n=self.g.scale[i]; self.p.note(n,True,i-5)
            print("\n▶ Free play:")
            kinds=['random','scale','arpeggio','chord','chord-melody']
            while time.time()-self.start<SESSION_DUR:
                kind=random.choice(kinds)
                notes=getattr(self.g,f"{kind.replace('-','_')}_chunk")()
                if len(notes)<3: continue
                # reverse only for non-chord types
                if kind in {'random','scale','arpeggio'} and random.choice([True,False]):
                    notes.reverse()
                degs=[self.g.key.degree(n) for n in notes]
                # cadence every CAD_FREQ chunks
                if self.count%self.CAD_FREQ==0:
                    for n,d in self.cad: self.p.chord(n,d,False)
                # ---------- dispatch ----------
                if kind=='chord':
                    self.p.chord(notes,degs,False); time.sleep(6)
                    self.p.chord(notes,degs,False)
                elif kind=='chord-melody':
                    top=max(notes,key=self._pitch)
                    top_deg=self.g.key.degree(top)
                    for strike in (0,1):
                        self.p.chord(notes,degs,False)
                        time.sleep(1)
                        self.p.note(top,False,top_deg)
                        if strike==0: time.sleep(5)   # 6 s total gap before 2nd strike
                elif kind=='arpeggio':
                    for n,d in zip(notes,degs): self.p.note(n,False,d)
                    time.sleep(6)
                    for n,d in zip(notes,degs): self.p.note(n,False,d)
                else:                                  # random / scale
                    for n,d in zip(notes,degs): self.p.note(n,False,d)
                self.count+=1
            print("\nSession complete — well done!")
        except KeyboardInterrupt: print("\nInterrupted."); \
            pygame.mixer.stop(); pygame.quit()

# ── CLI ────────────────────────────────────────────────────────────
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--tonality',choices=('minor','major'),
                    default='minor',help='minor (default) or major cadence')
    args=ap.parse_args()
    sig=random.choice(KEY_SIGS)
    print("Key:",*sig,"| Tonality:",args.tonality)
    Session(Player(),Gen(Key(sig)),args.tonality).run()

if __name__=='__main__': main()
