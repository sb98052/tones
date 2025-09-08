#!/usr/bin/env python3
"""
Create sharp note files by duplicating their enharmonic flat equivalents.
"""

import shutil
from pathlib import Path

# Enharmonic equivalents (sharp -> flat)
SHARP_TO_FLAT = {
    'C#': 'Db',
    'D#': 'Eb',
    'F#': 'Gb',
    'G#': 'Ab',
    'A#': 'Bb'
}

def create_sharp_files():
    notes_dir = Path('notes')
    
    if not notes_dir.exists():
        print(f"Error: {notes_dir} directory not found!")
        return
    
    created_files = []
    
    for sharp, flat in SHARP_TO_FLAT.items():
        # Find all octaves for this flat note
        flat_files = list(notes_dir.glob(f"{flat}*.mp3"))
        
        for flat_file in flat_files:
            # Extract octave number from filename
            octave = flat_file.stem.replace(flat, '')
            
            # Create sharp filename
            sharp_file = notes_dir / f"{sharp}{octave}.mp3"
            
            # Copy the file
            if not sharp_file.exists():
                shutil.copy2(flat_file, sharp_file)
                created_files.append(sharp_file.name)
                print(f"Created: {sharp_file.name} (copy of {flat_file.name})")
            else:
                print(f"Skipped: {sharp_file.name} already exists")
    
    print(f"\nTotal files created: {len(created_files)}")

if __name__ == "__main__":
    create_sharp_files()