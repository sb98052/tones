import pygame
import random
import time
import os

# Initialize the mixer module
pygame.mixer.init()
pygame.mixer.set_num_channels(32)  # Adjust the number based on your needs

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

# Set minimum and maximum octaves
min_octave = 3
max_octave = 5
fkeys = []

for key in all_keys:
    notes = []
    octave=min_octave
    prev_note = None
    while octave<=max_octave:
        for note in key:
            if prev_note:
                print(f'{octave} {prev_note} {note} {note_semitones[prev_note]} {note_semitones[note]} {note_semitones["C"]}')
            if prev_note and note_semitones[prev_note] > note_semitones[note]:
                octave+=1
            notes.append(f'{note}{octave}')
            prev_note = note
    fkeys.append(notes)

keys = fkeys
# Set note duration in seconds
note_duration = 1.0  # Duration for which each note is played

# Choose a random key from the list
selected_key = random.choice(fkeys)
print(f"Selected key: {selected_key}")

# Set the octave for the scale
scale_octave = 4  # You can choose any octave within min_octave and max_octave

# Function to play multiple notes simultaneously (chord)
def play_notes(notes):
    sound_list = []
    channels = []
    
    # Handle degrees being None or a list
    # For displaying purposes
    notes_display = []
    for note in notes:
        filename = f"{note}.mp3"
        file_path = os.path.join(sound_folder, filename)
        if os.path.exists(file_path):
            notes_display.append(f"{note}{octave}")
            sound = pygame.mixer.Sound(file_path)
            sound_list.append(sound)
        else:
            print(f"File not found: {file_path}")
            return
    
    # Print the chord being played
    print("Playing chord: " + ", ".join(notes_display))
    
    # Play all sounds simultaneously
    for sound in sound_list:
        channel = sound.play(loops=0, maxtime=int(note_duration * 1000))
        channel.set_volume(1.0)  # Adjust volume as needed
        channels.append(channel)
    
    # Wait for the duration
    time.sleep(note_duration)
    
    # Stop all channels (not strictly necessary due to maxtime)
    for channel in channels:
        channel.stop()


# Function to play a note
def play_note(note, degree = None):
    filename = f"{note}.mp3"
    file_path = os.path.join(sound_folder, filename)
    degree = degree % 7
    # Check if the file exists
    if os.path.exists(file_path):
        # Print the note being played
        if degree is not None:
            degree=f"({degree+1})"
        else:
            degree=""

        print(f"Playing {note}{octave} {degree}")

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

for i in range(8):
    play_note(selected_key[i], scale_octave)

print("End of scale")

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


        # Randomly choose chunk type: 'random', 'scale', or 'arpeggio'
        chunk_type = random.choice(['random', 'scale', 'arpeggio', 'chord'])


        chunk_notes = []
        chunk_octaves = []

        if chunk_type == 'random':
            chunk_size = random.randint(1, 7)
            # Generate random chunk
            for _ in range(chunk_size):
                # Choose a random note from the selected key
                note = random.choice(selected_key)
                # Choose a random octave
                octave = random.randint(min_octave, max_octave)
                chunk_notes.append(note)

        elif chunk_type == 'scale':
            chunk_size = random.randint(3, 12)
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

            for i in range(1, chunk_size):
                if direction == 'ascending':
                    index = (start_index + i) % len(selected_key)
                else:
                    index = (start_index - i) % len(selected_key)
                next_note = selected_key[index]

                chunk_notes.append(next_note)

                # Update previous note and octave for next iteration
                prev_note = next_note

        elif chunk_type == 'arpeggio':
            # Generate arpeggio chunk
            # Arpeggio chunk size is between 3 and 7 notes
            chunk_size = random.randint(3, 17)

            # Randomly choose root note index from selected_key
            root_index = random.randint(0, len(selected_key) - 1)
            root_note = selected_key[root_index]

            # Randomly choose an octave
            octave = random.randint(min_octave, max_octave)

            # Arpeggio intervals (relative to root note index): root, 3rd, 5th
            arpeggio_intervals = [2, 2, 3]

            note_count = 0
            prev_note = root_note
            prev_octave = octave

            index = root_index
            for note_count in range(0, chunk_size):
                try:
                    next_note = selected_key[index]
                except IndexError:
                    break

                chunk_notes.append(next_note)

                index+=arpeggio_intervals[note_count%3]
                note_count += 1
            chunk_size = note_count
        elif chunk_type == 'chord':
            # Generate arpeggio chunk
            # Arpeggio chunk size is between 3 and 7 notes
            chunk_size = random.randint(3, 17)

            # Randomly choose root note index from selected_key
            root_index = random.randint(0, len(selected_key) - 1)
            root_note = selected_key[root_index]

            # Randomly choose an octave
            octave = random.randint(min_octave, max_octave)

            # Arpeggio intervals (relative to root note index): root, 3rd, 5th
            arpeggio_intervals = [2, 2, 3]

            note_count = 0
            prev_note = root_note
            prev_octave = octave

            index = root_index
            for note_count in range(0, chunk_size):
                try:
                    next_note = selected_key[index]
                except IndexError:
                    break

                chunk_notes.append(next_note)

                index+=arpeggio_intervals[note_count%3]
                note_count += 1
            chunk_size = note_count
        else:
            print(f"Unknown chunk type: {chunk_type}")
            continue  # Skip to the next iteration
        if random.choice([True, False]):
            chunk_notes.reverse()

        # Play the chunk
        print(f"Playing a {chunk_type} chunk with {len(chunk_notes)} notes.")
        if chunk_type == 'arpeggio':
            for note in chunk_notes:
                play_note(note, selected_key.index(note))
        if chunk_type == 'chord':
            for note in chunk_notes:
                print(f"{selected_key.index(note) % 7 + 1}")
            play_notes(chunk_notes)

        if chunk_type == 'arpeggio':
            time.sleep(6)

            for note in chunk_notes:
                play_note(note, selected_key.index(note))

        if chunk_type == 'chord':
            time.sleep(6)

            play_notes(chunk_notes)

except KeyboardInterrupt:
    print("Program terminated by user.")
finally:
    # Stop all sounds and quit pygame
    pygame.mixer.stop()
    pygame.quit()
