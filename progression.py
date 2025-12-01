#!/usr/bin/env python3
"""
Chord Progression Ear Training with Harmonic Labeling
- Plays chord progressions with melody notes
- Labels each note with its harmonic function (e.g., "La/5 minor")
- Randomizes keys for each session
"""

from __future__ import annotations
import argparse, random, time, subprocess, sys, threading, select, fcntl, os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Sequence, Dict, List, Tuple, Set
import pygame

# ── CONFIG ──────────────────────────────────────────────────────────
SOUND_FOLDER = Path("notes")
CHORD_OCTAVE_RANGE = (3, 4)  # Lower register for chords
MELODY_OCTAVE_RANGE = (5, 6)  # Higher register for melody (5th and 6th octaves)
TEMPO = 120  # BPM
BEAT_DURATION = 60.0 / TEMPO  # Duration of one beat in seconds
CHORD_DURATION = 4 * BEAT_DURATION  # 4 beats per chord
WAIT_TIME = 3  # Configurable delay between segments (was 0.1)

# Solfege to semitone mapping (relative to Do)
SOLFEGE_TO_SEMI = {
    'do': 0, 'di': 1, 'ra': 1, 're': 2, 'ri': 3, 'me': 3, 'mi': 4, 'fa': 5,
    'fi': 6, 'se': 6, 'sol': 7, 'si': 8, 'le': 8, 'la': 9, 'li': 10, 'te': 10, 'ti': 11
}

# Solfege pronunciation mapping for speech
SOLFEGE_PRONUNCIATION = {
    'do': 'doe', 're': 'ray', 'mi': 'me', 'fa': 'far', 'sol': 'so', 'la': 'la', 'ti': 'tea',
    'di': 'dee', 'ra': 'rah', 'ri': 'ree', 'me': 'may', 'fi': 'fee', 'se': 'say', 
    'si': 'see', 'le': 'lay', 'li': 'lee', 'te': 'tay'
}

# Natural minor mode: La is tonic
MINOR_MODE_OFFSET = 9  # La to Do

NOTE_TO_SEMI = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'Fb':4,'E#':5,
                'F':5,'F#':6,'Gb':6,'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,
                'B':11,'Cb':11}

KEY_SIGS = [
    ['C','D','E','F','G','A','B'],  ['G','A','B','C','D','E','F#'],
    ['F','G','A','Bb','C','D','E'], ['D','E','F#','G','A','B','C#'],
    ['A','B','C#','D','E','F#','G#'],['E','F#','G#','A','B','C#','D#'],
    ['B','C#','D#','E','F#','G#','A#'],['F#','G#','A#','B','C#','D#','E#'],
    ['Bb','C','D','Eb','F','G','A'],  ['Eb','F','G','Ab','Bb','C','D'],
    ['Ab','Bb','C','Db','Eb','F','G'],['Db','Eb','F','Gb','Ab','Bb','C'],
    ['Gb','Ab','Bb','Cb','Db','Eb','F'],
]

# ── CHORD DEFINITIONS ───────────────────────────────────────────────
# Define chord types with solfege degrees and their positions
CHORD_DEFS = {
    # Minor chords
    'la_minor': {'degrees': ['la', 'do', 'mi'], 'quality': 'minor'},
    're_minor': {'degrees': ['re', 'fa', 'la'], 'quality': 'minor'},
    'mi_minor': {'degrees': ['mi', 'sol', 'ti'], 'quality': 'minor'},
    
    # Major chords  
    'do_major': {'degrees': ['do', 'mi', 'sol'], 'quality': 'major'},
    'fa_major': {'degrees': ['fa', 'la', 'do'], 'quality': 'major'},
    'sol_major': {'degrees': ['sol', 'ti', 're'], 'quality': 'major'},
    
    # Dominant chords (7th chords)
    'mi_dominant': {'degrees': ['mi', 'si', 'ti', 're'], 'quality': 'dominant'},
    're_dominant': {'degrees': ['re', 'fi', 'la', 'do'], 'quality': 'dominant'},
    
    # For Dark Eyes - Gypsy jazz chords
    'mi7_dominant': {'degrees': ['mi', 'si', 'ti', 're'], 'quality': 'dominant'},  # A7 in Dm
    'la_minor_dm': {'degrees': ['la', 'do', 'mi'], 'quality': 'minor'},  # Dm
    're_minor_gm': {'degrees': ['re', 'fa', 'la'], 'quality': 'minor'},  # Gm in Dm
    'fa_major_bb': {'degrees': ['fa', 'la', 'do'], 'quality': 'major'},  # Bb in Dm

    # Additional dominant 7th chords for All of Me
    'la7_dominant': {'degrees': ['la', 'di', 'mi', 'sol'], 'quality': 'dominant'},  # A7
    're7_dominant': {'degrees': ['re', 'fi', 'la', 'do'], 'quality': 'dominant'},  # D7
    'sol7_dominant': {'degrees': ['sol', 'ti', 're', 'fa'], 'quality': 'dominant'},  # G7

    # Additional minor chord
    'fa_minor': {'degrees': ['fa', 'le', 'do'], 'quality': 'minor'},  # Fm

    # Chords for Autumn Leaves
    're_minor7': {'degrees': ['re', 'fa', 'la', 'do'], 'quality': 'minor7'},  # Dm7
    'sol7_dominant': {'degrees': ['sol', 'ti', 're', 'fa'], 'quality': 'dominant'},  # G7 (already exists as sol7_dominant)
    'do_major7': {'degrees': ['do', 'mi', 'sol', 'ti'], 'quality': 'major7'},  # Cmaj7
    'fa_major7': {'degrees': ['fa', 'la', 'do', 'mi'], 'quality': 'major7'},  # Fmaj7
}

# ── PROGRESSIONS ────────────────────────────────────────────────────
PROGRESSIONS = {
    'dark_eyes': {
        'chords': ['mi7_dominant', 'la_minor_dm', 'mi7_dominant', 'fa_major_bb',
                   're_minor_gm', 'la_minor_dm', 'mi7_dominant', 'la_minor_dm'],
        'mode': 'minor'  # Natural minor (La-based)
    },
    'minor_swing': {
        'chords': ['la_minor', 'la_minor', 're_minor', 're_minor',
                   'mi_dominant', 'mi_dominant', 'la_minor', 'la_minor', 
                   're_minor', 're_minor', 'la_minor', 'la_minor',
                   'mi_dominant', 'mi_dominant', 'la_minor', 'mi_dominant'],
        'mode': 'minor'
    },
    'superpop': {
        'chords': ['do_major', 'sol_major', 'la_minor', 'fa_major'],
        'mode': 'major'  # Major mode (Do-based)
    },
    'primary': {
        'chords': ['do_major', 'fa_major', 'la_minor', 're_minor', 'sol_major', 'do_major'],
        'mode': 'major'  # Major mode (Do-based)
    },
    'primary_minor': {
        'chords': ['la_minor', 're_minor', 'sol_major', 'do_major', 'mi_dominant', 'la_minor'],
        'mode': 'minor'  # Minor mode (La-based) - uses 5 diatonic chords: i, iv, VII, III, V7, i
    },
    'all_of_me': {
        'chords': ['do_major', 'do_major', 'mi7_dominant', 'mi7_dominant',
                   'la7_dominant', 'la7_dominant', 're_minor', 're_minor',
                   'mi7_dominant', 'mi7_dominant', 'la_minor', 'la_minor',
                   're7_dominant', 're7_dominant', 'sol7_dominant', 'sol7_dominant',
                   'do_major', 'do_major', 'mi7_dominant', 'mi7_dominant',
                   'la7_dominant', 'la7_dominant', 're_minor', 're_minor',
                   'fa_major', 'fa_minor', 'do_major', 'la7_dominant',
                   're_minor', 'sol7_dominant', 'do_major', 'sol7_dominant'],
        'mode': 'major'  # Major mode (Do-based)
    },
    'autumn_leaves_start': {
        'chords': ['re_minor7', 'sol7_dominant', 'do_major7', 'fa_major7',
                   're_minor7', 'sol7_dominant', 'do_major7', 'fa_major7'],
        'mode': 'major'  # Major mode (Do-based) - starts on ii-V-I in C major
    }
}

# ── KEY / SCALE ─────────────────────────────────────────────────────
@dataclass(frozen=True)
class Key:
    sig: Sequence[str]
    mode: str = 'minor'  # 'minor' or 'major'
    
    def get_tonic_note(self) -> str:
        """Get the tonic note based on mode"""
        if self.mode == 'minor':
            # In minor, La is tonic (6th degree of major scale)
            return self.sig[5]  # 6th note is index 5
        else:
            return self.sig[0]  # Do is tonic in major
    
    def solfege_to_note(self, solfege: str, octave: int) -> str:
        """Convert solfege degree to actual note"""
        # Get semitone offset from Do
        semi_offset = SOLFEGE_TO_SEMI.get(solfege, 0)
        
        # Find Do in the key signature
        do_index = 0  # C in C major, etc.
        
        # Calculate the actual note
        note_index = (do_index + semi_offset) % 12
        
        # Map to actual note in this key
        # This is simplified - in practice would need proper key mapping
        base_note = self.sig[0]  # Start from tonic
        base_semi = NOTE_TO_SEMI[base_note]
        
        if self.mode == 'minor':
            # Adjust for minor mode - La is tonic
            base_note = self.sig[5]
            base_semi = NOTE_TO_SEMI[base_note]
            # Adjust semitone calculation for minor mode
            target_semi = (base_semi + semi_offset - MINOR_MODE_OFFSET) % 12
        else:
            target_semi = (base_semi + semi_offset) % 12
        
        # Find the note name that matches this semitone
        for note, semi in NOTE_TO_SEMI.items():
            if semi == target_semi and '#' not in note and 'b' not in note:
                return f"{note}{octave}"
        
        # Fallback to sharp/flat notes
        for note, semi in NOTE_TO_SEMI.items():
            if semi == target_semi:
                return f"{note}{octave}"
        
        return f"C{octave}"  # Default fallback

# ── KEYBOARD INPUT ──────────────────────────────────────────────────
class KeyboardListener:
    """Non-blocking keyboard input listener for pause/resume functionality"""
    def __init__(self):
        self.paused = False
        self.stop_requested = False
        self._lock = threading.Lock()
        self._thread = None

    def start(self):
        """Start listening for keyboard input in a separate thread"""
        self._thread = threading.Thread(target=self._listen, daemon=True)
        self._thread.start()

    def _listen(self):
        """Listen for keyboard input (runs in separate thread)"""
        import termios, tty

        # Save terminal settings
        fd = sys.stdin.fileno()
        old_settings = termios.tcgetattr(fd)
        old_flags = fcntl.fcntl(fd, fcntl.F_GETFL)

        try:
            # Set terminal to cbreak mode (not raw mode) for better output handling
            tty.setcbreak(fd)
            # Set non-blocking mode
            fcntl.fcntl(fd, fcntl.F_SETFL, old_flags | os.O_NONBLOCK)

            while not self.stop_requested:
                try:
                    # Try to read a character (non-blocking)
                    key = sys.stdin.read(1)

                    if key:
                        # Space key to toggle pause
                        if key == ' ':
                            with self._lock:
                                self.paused = not self.paused
                                if self.paused:
                                    print("\n>>> PAUSED (press space to resume) <<<\n", flush=True)
                                else:
                                    print("\n>>> RESUMED <<<\n", flush=True)

                        # 'q' or ESC to quit
                        elif key in ['q', 'Q', '\x1b', '\x03']:  # q, Q, ESC, or Ctrl+C
                            with self._lock:
                                self.stop_requested = True

                except IOError:
                    # No input available, continue
                    pass

                # Small sleep to prevent CPU spinning
                time.sleep(0.05)

        finally:
            # Restore terminal settings
            fcntl.fcntl(fd, fcntl.F_SETFL, old_flags)
            termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)

    def is_paused(self):
        """Check if currently paused"""
        with self._lock:
            return self.paused

    def should_stop(self):
        """Check if stop was requested"""
        with self._lock:
            return self.stop_requested

    def stop(self):
        """Stop the listener thread"""
        with self._lock:
            self.stop_requested = True

# ── AUDIO & SPEECH ──────────────────────────────────────────────────
class Player:
    def __init__(self, folder=SOUND_FOLDER, vol=5.0, chans=32, speech_vol=0.7, chord_vol=0.15, melody_vol=1.0):
        pygame.mixer.init()
        pygame.mixer.set_num_channels(chans)
        self.folder = folder
        self.vol = vol
        self.speech_vol = speech_vol  # 0.0-1.0 scale (converted to 0-100 for macOS)
        self.chord_vol = chord_vol  # Volume multiplier for chord notes
        self.melody_vol = melody_vol  # Volume multiplier for melody notes
    
    def _snd(self, note):
        return pygame.mixer.Sound(str(self.folder / f"{note}.mp3"))
    
    def _say(self, text):
        """Speak text synchronously (macOS only)"""
        if not sys.platform.startswith("darwin"):
            return
        
        # Save current volume
        try:
            result = subprocess.run(["osascript", "-e", "output volume of (get volume settings)"], 
                                  capture_output=True, text=True, check=True)
            output = result.stdout.strip()
            if output == "missing value" or not output:
                saved_vol = 50  # Default to middle volume if can't get current
            else:
                saved_vol = int(output)
        except (ValueError, subprocess.CalledProcessError):
            saved_vol = 50  # Default fallback
        
        # Set speech volume (convert 0.0-1.0 to 0-100)
        try:
            volume_percent = int(self.speech_vol * 100)
            subprocess.run(["osascript", "-e", f"set volume output volume {volume_percent}"], check=True)
        except subprocess.CalledProcessError:
            pass  # Continue even if we can't set volume
        
        # Blocking call
        subprocess.run(["say", text], check=True)
        
        # Restore volume
        try:
            subprocess.run(["osascript", "-e", f"set volume output volume {saved_vol}"], check=True)
        except subprocess.CalledProcessError:
            pass  # Don't fail if we can't restore volume
    
    def play_chord_and_melody(self, chord_notes: List[str], melody_note: str, duration: float, session=None):
        """Play chord with melody note on top - returns channels to stop later"""
        print(f"  Chord: {chord_notes}, Melody: {melody_note}")

        # Play chord
        chord_channels = []
        for note in chord_notes:
            ch = self._snd(note).play(loops=0)
            if ch:
                ch.set_volume(self.vol * self.chord_vol)  # Configurable chord volume
                chord_channels.append(ch)
            else:
                print(f"Warning: Could not play chord note {note}")

        # Play melody note (full volume) - find available channel
        melody_ch = pygame.mixer.find_channel(True)  # Force get a channel
        if melody_ch:
            melody_sound = self._snd(melody_note)
            melody_ch.play(melody_sound)
            melody_ch.set_volume(self.vol * self.melody_vol)  # Configurable melody volume
        else:
            print(f"Warning: No channel available for melody {melody_note}")
            melody_ch = None

        # Note: duration is now handled by the session's wait_with_pause method

        # Return channels so they can be stopped later
        return chord_channels, melody_ch
    
    def play_melody_only(self, melody_note: str, duration: float):
        """Play just the melody note"""
        print(f"  Melody only: {melody_note}")
        ch = self._snd(melody_note).play(loops=0)
        if ch:
            ch.set_volume(self.vol * self.melody_vol)  # Configurable melody volume
        # Note: duration is now handled by the session's wait_with_pause method
        # Let the note ring out naturally, don't stop it
        return ch
    
    def say_label(self, label: str):
        """Speak the harmonic label"""
        print(f"  Label: {label}")
        self._say(label)

# ── PROGRESSION PLAYER ──────────────────────────────────────────────
class ProgressionSession:
    def __init__(self, player: Player, key: Key, progression_name: str, only_harmony: bool = False, chord_octaves: Tuple[int, int] = CHORD_OCTAVE_RANGE, no_voice: bool = False, audiate: bool = False):
        self.player = player
        self.key = key
        self.progression = PROGRESSIONS[progression_name]
        self.chord_sequence = self.progression['chords']
        self.only_harmony = only_harmony
        self.chord_octaves = chord_octaves
        self.no_voice = no_voice
        self.audiate = audiate
        self.label_ambiguities = self._analyze_label_ambiguities()
        self.keyboard_listener = KeyboardListener()
    
    def _analyze_label_ambiguities(self) -> Dict[str, set]:
        """Analyze which harmonic labels appear with multiple chord qualities"""
        label_to_qualities = {}
        
        # Go through all chords in the progression
        for chord_name in set(self.chord_sequence):  # Use set to avoid duplicates
            chord_def = CHORD_DEFS[chord_name]
            degrees = chord_def['degrees']
            quality = chord_def['quality']
            
            # For each degree in the chord
            for i, degree in enumerate(degrees):
                position = ['1', '3', '5', '7'][i] if i < 4 else '1'
                label_key = f"{degree}_{position}"
                
                if label_key not in label_to_qualities:
                    label_to_qualities[label_key] = set()
                label_to_qualities[label_key].add(quality)
        
        # Return dict indicating which labels have multiple qualities
        return {k: v for k, v in label_to_qualities.items() if len(v) > 1}
    
    def get_chord_notes(self, chord_name: str) -> Tuple[List[str], List[str]]:
        """Get actual notes for a chord in the current key"""
        chord_def = CHORD_DEFS[chord_name]
        degrees = chord_def['degrees']
        
        # Convert solfege to actual notes
        chord_notes = []
        for deg in degrees[:3]:  # Take first 3 for triad
            note = self.key.solfege_to_note(deg, random.choice(self.chord_octaves))
            chord_notes.append(note)
        
        return chord_notes, degrees
    
    def wait_with_pause(self, duration: float):
        """Wait for a duration while checking for pause/resume"""
        start_time = time.time()
        while time.time() - start_time < duration:
            if self.keyboard_listener.should_stop():
                return False  # Signal to stop

            if self.keyboard_listener.is_paused():
                # Pause all sounds
                pygame.mixer.pause()
                while self.keyboard_listener.is_paused():
                    time.sleep(0.1)
                    if self.keyboard_listener.should_stop():
                        return False
                # Resume all sounds
                pygame.mixer.unpause()

            time.sleep(0.05)  # Check every 50ms
        return True  # Continue normally

    def get_random_melody_note(self, chord_name: str) -> Tuple[str, str]:
        """Pick a random chord tone as melody"""
        chord_def = CHORD_DEFS[chord_name]
        degrees = chord_def['degrees']
        quality = chord_def['quality']

        # Pick random chord tone
        chosen_degree = random.choice(degrees)
        melody_note = self.key.solfege_to_note(chosen_degree, random.choice(MELODY_OCTAVE_RANGE))

        # Determine position (1, 3, 5, or 7)
        position_map = {0: '1', 1: '3', 2: '5', 3: '7'}
        position = position_map.get(degrees.index(chosen_degree), '1')

        # Create label with proper pronunciation
        degree_pronunciation = SOLFEGE_PRONUNCIATION.get(chosen_degree, chosen_degree)

        # Check if this label needs the quality qualifier
        label_key = f"{chosen_degree}_{position}"
        if label_key in self.label_ambiguities:
            # This label appears with multiple qualities, so include the quality
            label = f"{degree_pronunciation}, {position}, {quality}"
        else:
            # This label is unique, skip the quality
            label = f"{degree_pronunciation}, {position}"

        return melody_note, label
    
    def play_chord_only(self, chord_notes: List[str], duration: float):
        """Play just the chord (for harmony-only mode)"""
        print(f"  Chord: {chord_notes}")
        
        chord_channels = []
        for note in chord_notes:
            ch = self.player._snd(note).play(loops=0)
            if ch:
                ch.set_volume(self.player.vol * 0.5)
                chord_channels.append(ch)
        
        time.sleep(duration)
        
        for ch in chord_channels:
            if ch:
                ch.stop()
        
        # Clean up to prevent channel buildup
        pygame.mixer.stop()
    
    def play_scale(self):
        """Play the scale based on the mode (minor starts with La, major starts with Do)"""
        scale_notes = []

        if self.key.mode == 'minor':
            # Natural minor scale starting from La
            scale_degrees = ['la', 'ti', 'do', 're', 'mi', 'fa', 'sol', 'la']
        else:
            # Major scale starting from Do
            scale_degrees = ['do', 're', 'mi', 'fa', 'sol', 'la', 'ti', 'do']

        # Convert to actual notes
        octave = 4  # Middle octave for scale
        for i, degree in enumerate(scale_degrees[:-1]):  # Skip the last note for now
            note = self.key.solfege_to_note(degree, octave)
            scale_notes.append(note)

        # Add the octave (last note one octave higher)
        last_note = self.key.solfege_to_note(scale_degrees[-1], octave + 1)
        scale_notes.append(last_note)

        print(f"Playing {self.key.mode} scale...")

        # Play each note of the scale
        for note in scale_notes:
            ch = self.player._snd(note).play(loops=0)
            if ch:
                ch.set_volume(self.player.vol * self.player.melody_vol)
            time.sleep(0.4)  # Duration for each scale note

        time.sleep(0.5)  # Pause after scale
        pygame.mixer.stop()  # Clear channels

    def run(self):
        """Run the progression loop"""
        print(f"\nStarting progression: {self.progression}")
        print(f"Key: {self.key.sig[0] if self.key.mode == 'major' else self.key.sig[5]} {self.key.mode}")
        if self.only_harmony:
            print("Mode: Harmony only")
        elif self.no_voice:
            print("Mode: No voice (harmony and melody only)")
        elif self.audiate:
            print("Mode: Audiation (announce first, then play)")
        print("Controls: [Space] = Pause/Resume | [Q] or [Ctrl+C] = Quit\n")

        # Start keyboard listener
        self.keyboard_listener.start()

        # Play the scale to establish the key
        self.play_scale()
        
        try:
            while not self.keyboard_listener.should_stop():
                for chord_name in self.chord_sequence:
                    if self.keyboard_listener.should_stop():
                        break

                    print(f"Chord: {chord_name}")

                    # Get chord notes
                    chord_notes, degrees = self.get_chord_notes(chord_name)
                    
                    if self.only_harmony:
                        # Just play the chord for the full duration
                        self.play_chord_only(chord_notes, CHORD_DURATION)
                    else:
                        # Full training mode with melody and labels
                        melody_note, label = self.get_random_melody_note(chord_name)

                        # Timing breakdown (total = CHORD_DURATION)
                        chord_melody_dur = CHORD_DURATION * 0.35
                        melody_only_dur = CHORD_DURATION * 0.25
                        # Remaining time for speech and pauses

                        if self.audiate:
                            # Audiation mode: announce first, then play melody alone, then with chord

                            # 1. Say/print label FIRST
                            if not self.no_voice:
                                self.player.say_label(label)
                            else:
                                # Print the label instead of speaking it
                                print(f"  >>> {label}")
                                if not self.wait_with_pause(0.5):  # Brief pause for readability
                                    break

                            # 2. Wait (time for anticipation/audiation)
                            if not self.wait_with_pause(WAIT_TIME):
                                break

                            # 3. Play melody only FIRST
                            melody_ch1 = self.player.play_melody_only(melody_note, melody_only_dur)

                            # Check for pause during melody play
                            if not self.wait_with_pause(melody_only_dur):
                                break

                            # 4. Wait
                            if not self.wait_with_pause(WAIT_TIME):
                                break

                            # 5. Play chord + melody together
                            chord_channels, melody_ch = self.player.play_chord_and_melody(chord_notes, melody_note, chord_melody_dur)

                            # Check for pause during chord play
                            if not self.wait_with_pause(chord_melody_dur):
                                break

                            # 6. Wait after chord+melody
                            if not self.wait_with_pause(WAIT_TIME):
                                break

                            # Store melody channel for cleanup
                            melody_ch2 = melody_ch1

                        else:
                            # Standard recognition mode: play first, then announce

                            # 1. Play chord + melody (keep chord ringing)
                            chord_channels, melody_ch = self.player.play_chord_and_melody(chord_notes, melody_note, chord_melody_dur)

                            # Check for pause during chord play
                            if not self.wait_with_pause(chord_melody_dur):
                                break

                            # 2. Wait (chord still ringing)
                            if not self.wait_with_pause(WAIT_TIME):
                                break

                            # 3. Say label (chord still ringing) - print if no_voice flag is set
                            if not self.no_voice:
                                self.player.say_label(label)
                            else:
                                # Print the label instead of speaking it
                                print(f"  >>> {label}")
                                if not self.wait_with_pause(0.5):  # Brief pause for readability
                                    break

                            # 4. Wait (chord still ringing)
                            if not self.wait_with_pause(WAIT_TIME):
                                break

                            # 5. Play melody only
                            melody_ch2 = self.player.play_melody_only(melody_note, melody_only_dur)

                            # Check for pause during melody play
                            if not self.wait_with_pause(melody_only_dur):
                                break

                            # 6. Wait after melody
                            if not self.wait_with_pause(WAIT_TIME):
                                break
                        
                        # 7. Stop the chord channels after everything is done
                        for ch in chord_channels:
                            if ch:
                                ch.stop()
                        if melody_ch:
                            melody_ch.stop()
                        if melody_ch2:
                            melody_ch2.stop()
                        
                        # Clean up all channels to prevent buildup
                        pygame.mixer.stop()
                    
                    print()
        
        except (KeyboardInterrupt, Exception) as e:
            if isinstance(e, KeyboardInterrupt):
                print("\nStopping progression...")
            self.keyboard_listener.stop()
            pygame.mixer.stop()
            pygame.quit()

# ── MAIN ────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(description="Chord progression ear training")
    parser.add_argument('--progression', choices=list(PROGRESSIONS.keys()),
                       default='minor_swing', help='Progression to practice')
    parser.add_argument('--tempo', type=int, default=120,
                       help='Tempo in BPM (default: 120)')
    parser.add_argument('--speech-volume', type=float, default=0.3,
                       help='Volume for speech (0.0-1.0, default: 0.3)')
    parser.add_argument('--only-harmony', action='store_true',
                       help='Play only the chord progression without melody and labels')
    parser.add_argument('--key', type=str, default=None,
                       help='Key to use (e.g., C, G, Dm, Am). If not specified, random key is chosen')
    parser.add_argument('--chord-volume', type=float, default=0.07,
                       help='Volume for chord notes (0.0-1.0, default: 0.07)')
    parser.add_argument('--melody-volume', type=float, default=1.0,
                       help='Volume for melody notes (0.0-1.0, default: 1.0)')
    parser.add_argument('--chord-octaves', type=str, default='3,4',
                       help='Octaves for chord notes (e.g., "3,4" for 3rd and 4th octaves)')
    parser.add_argument('--no-voice', action='store_true',
                       help='Skip voice-based instructions, only play harmony and melody')
    parser.add_argument('--audiate', action='store_true',
                       help='Audiation mode: announce the note first, then play it (for anticipation practice)')

    args = parser.parse_args()
    
    # Update tempo
    global TEMPO, BEAT_DURATION, CHORD_DURATION
    TEMPO = args.tempo
    BEAT_DURATION = 60.0 / TEMPO
    CHORD_DURATION = 4 * BEAT_DURATION
    
    # Select key
    if args.key:
        # Parse the key argument
        key_name = args.key.upper()
        
        # Map common key names to key signatures
        key_map = {
            'C': ['C','D','E','F','G','A','B'],
            'G': ['G','A','B','C','D','E','F#'],
            'D': ['D','E','F#','G','A','B','C#'],
            'A': ['A','B','C#','D','E','F#','G#'],
            'E': ['E','F#','G#','A','B','C#','D#'],
            'B': ['B','C#','D#','E','F#','G#','A#'],
            'F': ['F','G','A','Bb','C','D','E'],
            'BB': ['Bb','C','D','Eb','F','G','A'],
            'EB': ['Eb','F','G','Ab','Bb','C','D'],
            'AB': ['Ab','Bb','C','Db','Eb','F','G'],
            'DB': ['Db','Eb','F','Gb','Ab','Bb','C'],
            'GB': ['Gb','Ab','Bb','Cb','Db','Eb','F'],
            'F#': ['F#','G#','A#','B','C#','D#','E#'],
            # Minor keys (relative major signatures)
            'AM': ['C','D','E','F','G','A','B'],  # A minor = C major
            'EM': ['G','A','B','C','D','E','F#'],  # E minor = G major
            'BM': ['D','E','F#','G','A','B','C#'],  # B minor = D major
            'F#M': ['A','B','C#','D','E','F#','G#'],  # F# minor = A major
            'C#M': ['E','F#','G#','A','B','C#','D#'],  # C# minor = E major
            'G#M': ['B','C#','D#','E','F#','G#','A#'],  # G# minor = B major
            'DM': ['F','G','A','Bb','C','D','E'],  # D minor = F major
            'GM': ['Bb','C','D','Eb','F','G','A'],  # G minor = Bb major
            'CM': ['Eb','F','G','Ab','Bb','C','D'],  # C minor = Eb major
            'FM': ['Ab','Bb','C','Db','Eb','F','G'],  # F minor = Ab major
            'BBM': ['Db','Eb','F','Gb','Ab','Bb','C'],  # Bb minor = Db major
            'EBM': ['Gb','Ab','Bb','Cb','Db','Eb','F'],  # Eb minor = Gb major
        }
        
        if key_name in key_map:
            key_sig = key_map[key_name]
        else:
            print(f"Warning: Unknown key '{args.key}', using random key instead")
            key_sig = random.choice(KEY_SIGS)
    else:
        # Random key
        key_sig = random.choice(KEY_SIGS)
    
    mode = PROGRESSIONS[args.progression]['mode']
    key = Key(key_sig, mode)
    
    # Parse chord octaves
    chord_octaves = tuple(int(x.strip()) for x in args.chord_octaves.split(','))
    if len(chord_octaves) != 2:
        print("Warning: chord-octaves should be two numbers separated by comma (e.g., '3,4'). Using default.")
        chord_octaves = CHORD_OCTAVE_RANGE
    
    # Create player and session
    player = Player(speech_vol=args.speech_volume, chord_vol=args.chord_volume, melody_vol=args.melody_volume)
    session = ProgressionSession(player, key, args.progression, args.only_harmony, chord_octaves, args.no_voice, args.audiate)

    # Run
    session.run()

if __name__ == '__main__':
    main()
