import pygame
import random
import time
import os

# Initialize the mixer module
pygame.mixer.init()

# Set the path to your sound files
sound_folder = 'notes/'

# Define the keys with sets of notes
all_keys = [
    ['C', 'D', 'E', 'F', 'G', 'A', 'B'],           # C major
    ['G', 'A', 'B', 'C', 'D', 'E', 'Gb'],          # G major (F# is Gb)
    ['F', 'G', 'A', 'Bb', 'C', 'D', 'E'],          # F major
    ['D', 'E', 'Gb', 'G', 'A', 'B', 'Db'],         # D major (F# is Gb, C# is Db)
    ['A', 'B', 'Db', 'D', 'E', 'Gb', 'Ab'],        # A major (C# is Db, F# is Gb, G# is Ab)
    ['E', 'Gb', 'Ab', 'A', 'B', 'Db', 'Eb'],       # E major (F# is Gb, G# is Ab, C# is Db, D# is Eb)
    ['B', 'Db', 'Eb', 'E', 'Gb', 'Ab', 'Bb'],      # B major (C# is Db, D# is Eb, F# is Gb, G# is Ab, A# is Bb)
    ['Gb', 'Ab', 'Bb', 'B', 'Db', 'Eb', 'F'],      # F# major (F# is Gb, G# is Ab, A# is Bb, C# is Db, D# is Eb, E# is F)
    ['Bb', 'C', 'D', 'Eb', 'F', 'G', 'A'],         # Bb major
    ['Eb', 'F', 'G', 'Ab', 'Bb', 'C', 'D'],        # Eb major
    ['Ab', 'Bb', 'C', 'Db', 'Eb', 'F', 'G'],       # Ab major
    ['Db', 'Eb', 'F', 'Gb', 'Ab', 'Bb', 'C'],      # Db major
    ['Gb', 'Ab', 'Bb', 'B', 'Db', 'Eb', 'F'],      # Gb major
    ['B', 'Db', 'Eb', 'E', 'Gb', 'Ab', 'Bb'],      # Cb major
]

keys = all_keys

# Set minimum and maximum octaves
min_octave = 3
max_octave = 5

# Set note duration in seconds
note_duration = 1.0  # Duration for which each note is played

# Choose a random key from the list
selected_key = random.choice(keys)
print(f"Selected key: {selected_key}")

# Set the octave for the scale
scale_octave = 4  # You can choose any octave within min_octave and max_octave

# Map note names to semitone numbers
note_semitones = {
    'C': 0,
    'C#': 1,
    'Db': 1,
    'D': 2,
    'D#': 3,
    'Eb': 3,
    'E': 4,
    'Fb': 4,
    'E#': 5,
    'F': 5,
    'F#': 6,
    'Gb': 6,
    'G': 7,
    'G#': 8,
    'Ab': 8,
    'A': 9,
    'A#': 10,
    'Bb': 10,
    'B': 11,
    'Cb': 11,
}

# Function to play a note
def play_note(note, octave):
    filename = f"{note}{octave}.mp3"
    file_path = os.path.join(sound_folder, filename)

    # Check if the file exists
    if os.path.exists(file_path):
        # Print the note being played
        print(f"Playing {note}{octave}")

        # Load the note sound
        note_sound = pygame.mixer.Sound(file_path)

        # Play the sound, limit playback to note_duration (in milliseconds)
        note_channel = note_sound.play(loops=0, maxtime=int(note_duration * 1000))
        note_channel.set_volume(1.0)  # Adjust volume as needed

        # Wait for the duration
        time.sleep(note_duration)

        # Stop the sound (not strictly necessary due to maxtime)
        note_channel.stop()
    else:
        print(f"File not found: {file_path}")

# Play the scale before starting random chunks
print("Playing the scale:")
for note in selected_key + [selected_key[0]]:
    play_note(note, scale_octave)
print("End of scale")

# Function to adjust the octave based on pitch comparison
def adjust_octave(prev_note, prev_octave, next_note, next_octave, direction):
    prev_abs_pitch = prev_octave * 12 + note_semitones[prev_note]
    next_abs_pitch = next_octave * 12 + note_semitones[next_note]

    if direction == 'ascending':
        while next_abs_pitch <= prev_abs_pitch and next_octave < max_octave:
            next_octave += 1
            next_abs_pitch = next_octave * 12 + note_semitones[next_note]
    elif direction == 'descending':
        while next_abs_pitch >= prev_abs_pitch and next_octave > min_octave:
            next_octave -= 1
            next_abs_pitch = next_octave * 12 + note_semitones[next_note]
    return next_octave

# Start time to track the duration
start_time = time.time()
duration = 40 * 60  # 40 minutes in seconds

# Main loop to play random chunks
try:
    while True:
        # Check if the duration has passed
        if time.time() - start_time > duration:
            print("40 minutes have passed. Stopping the program.")
            break

        # Randomize the number of notes in the chunk
        chunk_size = random.randint(1, 7)

        # Randomly choose chunk type: 'random', 'scale', or 'arpeggio'
        chunk_type = random.choice(['random', 'scale', 'arpeggio'])

        chunk_notes = []
        chunk_octaves = []

        if chunk_type == 'random':
            # Generate random chunk
            for _ in range(chunk_size):
                # Choose a random note from the selected key
                note = random.choice(selected_key)
                # Choose a random octave
                octave = random.randint(min_octave, max_octave)
                chunk_notes.append(note)
                chunk_octaves.append(octave)

        elif chunk_type == 'scale':
            # Generate scale chunk
            # Randomly choose starting note from selected_key
            start_index = random.randint(0, len(selected_key) - 1)
            # Randomly choose direction: ascending or descending
            direction = random.choice(['ascending', 'descending'])

            # Randomly choose an octave
            octave = random.randint(min_octave, max_octave)

            # Initialize previous note and octave
            prev_note = selected_key[start_index]
            prev_octave = octave
            chunk_notes.append(prev_note)
            chunk_octaves.append(prev_octave)

            for i in range(1, chunk_size):
                if direction == 'ascending':
                    index = (start_index + i) % len(selected_key)
                else:
                    index = (start_index - i) % len(selected_key)
                next_note = selected_key[index]
                next_octave = prev_octave  # Start with previous octave

                # Adjust octave based on pitch comparison
                next_octave = adjust_octave(prev_note, prev_octave, next_note, next_octave, direction)

                # Check if octave is within min_octave and max_octave
                if next_octave < min_octave or next_octave > max_octave:
                    break  # Can't add more notes

                chunk_notes.append(next_note)
                chunk_octaves.append(next_octave)

                # Update previous note and octave for next iteration
                prev_note = next_note
                prev_octave = next_octave

        elif chunk_type == 'arpeggio':
            # Generate arpeggio chunk
            # Arpeggio chunk size is between 3 and 7 notes
            chunk_size = random.randint(3, 7)

            # Randomly choose root note index from selected_key
            root_index = random.randint(0, len(selected_key) - 1)
            root_note = selected_key[root_index]

            # Randomly choose an octave
            octave = random.randint(min_octave, max_octave)

            # Arpeggio intervals (relative to root note index): root, 3rd, 5th
            arpeggio_intervals = [0, 2, 4]  # Offsets in scale degrees

            note_count = 0
            prev_note = root_note
            prev_octave = octave

            while note_count < chunk_size:
                for interval in arpeggio_intervals:
                    index = (root_index + interval) % len(selected_key)
                    next_note = selected_key[index]
                    next_octave = prev_octave  # Start with previous octave

                    # Adjust octave based on pitch comparison
                    next_octave = adjust_octave(prev_note, prev_octave, next_note, next_octave, 'ascending')

                    # Check if octave is within bounds
                    if next_octave < min_octave or next_octave > max_octave:
                        break  # Can't add more notes

                    chunk_notes.append(next_note)
                    chunk_octaves.append(next_octave)
                    note_count += 1

                    if note_count >= chunk_size:
                        break  # Reached desired chunk size

                    # Update previous note and octave
                    prev_note = next_note
                    prev_octave = next_octave

                # Prepare for next iteration
                # Update prev_note and prev_octave to the last note played
                if note_count >= chunk_size:
                    break  # Reached desired chunk size

                # Move to next octave for the next arpeggio sequence
                prev_octave += 1
                if prev_octave > max_octave:
                    break  # Can't go beyond octave limits
        else:
            print(f"Unknown chunk type: {chunk_type}")
            continue  # Skip to the next iteration

        # Play the chunk
        print(f"Playing a {chunk_type} chunk with {len(chunk_notes)} notes.")
        for note, octave in zip(chunk_notes, chunk_octaves):
            play_note(note, octave)
except KeyboardInterrupt:
    print("Program terminated by user.")
finally:
    # Stop all sounds and quit pygame
    pygame.mixer.stop()
    pygame.quit()
