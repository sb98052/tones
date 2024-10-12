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
note_duration = 2.0  # Duration for which each note is played

# Choose a random key from the list
selected_key = random.choice(keys)
print(f"Selected key: {selected_key}")

# Set the octave for the scale
scale_octave = 4  # You can choose any octave within min_octave and max_octave

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

# Helper function to determine if octave should change between two notes
def adjust_octave(prev_note, next_note, octave, direction):
    if direction == 'ascending':
        # Increase octave when moving from 'B' to 'C'
        if prev_note == 'B' and next_note == 'C':
            return octave + 1
    elif direction == 'descending':
        # Decrease octave when moving from 'C' to 'B'
        if prev_note == 'C' and next_note == 'B':
            return octave - 1
    return octave

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

            # Build the chunk
            prev_note = selected_key[start_index]
            for i in range(chunk_size):
                # Calculate the index of the next note
                if direction == 'ascending':
                    index = (start_index + i) % len(selected_key)
                else:
                    index = (start_index - i) % len(selected_key)

                next_note = selected_key[index]

                # Adjust octave if moving from 'B' to 'C' or 'C' to 'B'
                octave = adjust_octave(prev_note, next_note, octave, direction)

                # Check if octave is within min_octave and max_octave
                if octave < min_octave or octave > max_octave:
                    # Can't add more notes, break out of the loop
                    break

                chunk_notes.append(next_note)
                chunk_octaves.append(octave)

                prev_note = next_note  # Update previous note

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

            while note_count < chunk_size:
                for interval in arpeggio_intervals:
                    # Calculate note index
                    index = (root_index + interval) % len(selected_key)
                    next_note = selected_key[index]

                    # Adjust octave when wrapping from 'B' to 'C'
                    octave = adjust_octave(prev_note, next_note, octave, 'ascending')

                    # Check if octave is within bounds
                    if octave < min_octave or octave > max_octave:
                        # Can't add more notes, break out of loops
                        break

                    chunk_notes.append(next_note)
                    chunk_octaves.append(octave)
                    note_count += 1

                    if note_count >= chunk_size:
                        break  # Reached desired chunk size

                    prev_note = next_note  # Update previous note

                prev_note = root_note  # Reset for next octave
                # Move to next octave
                octave += 1

                # Check if octave is within bounds
                if octave > max_octave:
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
