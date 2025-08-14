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
    ['D', 'E', 'Gb', 'G', 'A', 'B', 'Db'],         # D major (F# is Gb, C# is Db)
    ['A', 'B', 'Db', 'D', 'E', 'Gb', 'Ab'],        # A major (C# is Db, F# is Gb, G# is Ab)
    ['E', 'Gb', 'Ab', 'A', 'B', 'Db', 'Eb'],       # E major (F# is Gb, G# is Ab, C# is Db, D# is Eb)
    ['B', 'Db', 'Eb', 'E', 'Gb', 'Ab', 'Bb'],      # B major (C# is Db, D# is Eb, F# is Gb, G# is Ab, A# is Bb)
    ['Gb', 'Ab', 'Bb', 'B', 'Db', 'Eb', 'F'],      # F# major (F# is Gb, G# is Ab, A# is Bb, C# is Db, D# is Eb, E# is F)
    ['F', 'G', 'A', 'Bb', 'C', 'D', 'E'],          # F major
    ['Bb', 'C', 'D', 'Eb', 'F', 'G', 'A'],         # Bb major
    ['Eb', 'F', 'G', 'Ab', 'Bb', 'C', 'D'],        # Eb major
    ['Ab', 'Bb', 'C', 'Db', 'Eb', 'F', 'G'],       # Ab major
    ['Db', 'Eb', 'F', 'Gb', 'Ab', 'Bb', 'C'],      # Db major
    ['Gb', 'Ab', 'Bb', 'B', 'Db', 'Eb', 'F'],      # Gb major
    ['B', 'Db', 'Eb', 'E', 'Gb', 'Ab', 'Bb'],      # Cb major
]

keys = all_keys[:2]

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

        # Optional: Add a short pause between notes
        time.sleep(0.5)
    else:
        print(f"File not found: {file_path}")

# Play the scale before starting random notes
print("Playing the scale:")
for note in selected_key:
    play_note(note, scale_octave)

# Main loop to play random notes
try:
    while True:
        # Choose a random note from the selected key
        note = random.choice(selected_key)
        # Choose a random octave
        octave = random.randint(min_octave, max_octave)

        play_note(note, octave)
except KeyboardInterrupt:
    # Stop all sounds when the user interrupts the program
    pygame.mixer.stop()
    pygame.quit()
    print("Program terminated by user.")
