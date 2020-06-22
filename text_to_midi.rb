#!/usr/bin/env ruby

require 'midilib/sequence'
require 'midilib/consts'
include MIDI

# hashes { symbol => note offset }
$lowercase_letter_indexes = ('a'..'z').each_with_index.map{|l,i| [l, i+1]}.to_h
$uppercase_letter_indexes = ('A'..'Z').each_with_index.map{|l,i| [l, i+1]}.to_h
$punctuation = { '!' => 30, "?" => 40, "." => -3, "," => -4 }

# note above which we'll find the others
$root_note = 42
$melody_root_note = $root_note + 33

# Volume consts
$high_volume = 127 # for uppercase letters, accent
$normal_volume = 100 # for lowercase letters
$low_volume = 60 # for punctuation

def melody_note_from_symbol(symbol)
	note = 0
	volume = 0
	# check lowercase
	if $lowercase_letter_indexes.key?(symbol) 
		note = $melody_root_note + $lowercase_letter_indexes[symbol]
		volume = $normal_volume
	elsif $uppercase_letter_indexes.key?(symbol)
		note =  $melody_root_note + $uppercase_letter_indexes[symbol]
		volume= $high_volume
	elsif $punctuation.key?(symbol)
		note = $melody_root_note + $punctuation[symbol]
		volume = $low_volume
	end

	return note, volume
end

def harmony_note_from_symbol(symbol)
	note1 = 0
	note2 = 0
	volume = 0
	# check lowercase
	if $lowercase_letter_indexes.key?(symbol) 
		note1 = $root_note + $lowercase_letter_indexes[symbol]
		note2 = note1 + 3
		volume = $high_volume
	elsif $uppercase_letter_indexes.key?(symbol)
		note1 = $root_note + $uppercase_letter_indexes[symbol]
		note2 = note1 + 4
		volume = $high_volume
	elsif $punctuation.key?(symbol)
		note1 = $root_note + $punctuation[symbol]
		note2 = note1 - 1
		volume = $low_volume
	end

	return note1, note2, volume
end


# Text to convert

drum_part = IO.read("drum_part.txt").unpack("B*")[0]
harmony_part = IO.read("harmony_part.txt")
melody_part = IO.read("melody_part.txt")

seq = Sequence.new()

# Create a first track for the sequence. This holds tempo events and stuff
# like that.
track = Track.new(seq)
seq.tracks << track
track.events << Tempo.new(Tempo.bpm_to_mpq(120))
track.events << MetaEvent.new(META_SEQ_NAME, 'GeneratedEvents')

# DRUMS track

# Create a track to hold the notes. Add it to the sequence.
track = Track.new(seq)
seq.tracks << track

# Give the track a name and an instrument name (optional).
track.name = 'DRUMS'
track.instrument = GM_PATCH_NAMES[0]

# Add a volume controller event (optional).
track.events << Controller.new(0, CC_VOLUME, 127)

# Arguments for note on and note off
# constructors are channel, note, velocity, and delta_time. Channel numbers
# start at zero. We use the new Sequence#note_to_delta method to get the
# delta time length of a single quarter note.
track.events << ProgramChange.new(0, 1, 0)
eighth_note_length = seq.note_to_delta('quarter') / 2

drum_part.each_char { |c| 
  offset = (c == "0") ? 1 : 3
  track.events << NoteOn.new(10, GM_DRUM_NOTE_LOWEST + offset, 127, 0)
  track.events << NoteOff.new(10, GM_DRUM_NOTE_LOWEST + offset, 127, eighth_note_length)
}

# MELODY track

# Create a track to hold the notes. Add it to the sequence.
track = Track.new(seq)
seq.tracks << track

# Give the track a name and an instrument name (optional).
track.name = 'Melody'
track.instrument = GM_PATCH_NAMES[0]

# Add a volume controller event (optional).
track.events << Controller.new(0, CC_VOLUME, 127)

# Arguments for note on and note off
# constructors are channel, note, velocity, and delta_time. Channel numbers
# start at zero. We use the new Sequence#note_to_delta method to get the
# delta time length of a single quarter note.
track.events << ProgramChange.new(0, 1, 0)
eighth_note_length = seq.note_to_delta('quarter') / 2

melody_part.each_char { |c|
  note, volume = melody_note_from_symbol(c)
  track.events << NoteOn.new(0, note, volume, 0)
  track.events << NoteOff.new(0, note, volume, eighth_note_length)
}

# HARMONY track

# Create a track to hold the notes. Add it to the sequence.
track = Track.new(seq)
seq.tracks << track

# Give the track a name and an instrument name (optional).
track.name = 'Harmony'
track.instrument = GM_PATCH_NAMES[0]

# Add a volume controller event (optional).
track.events << Controller.new(0, CC_VOLUME, 127)

# Arguments for note on and note off
# constructors are channel, note, velocity, and delta_time. Channel numbers
# start at zero. We use the new Sequence#note_to_delta method to get the
# delta time length of a single quarter note.
track.events << ProgramChange.new(0, 1, 0)
quarter_note_length = seq.note_to_delta('quarter')

harmony_part.each_char { |c|
  note1, note2, volume = harmony_note_from_symbol(c)
  track.events << NoteOn.new(0, note1, volume, 0)
  track.events << NoteOn.new(0, note2, volume, 0)
  track.events << NoteOff.new(0, note1, volume, quarter_note_length)
  track.events << NoteOff.new(0, note2, volume, 0)
}

# BASS track (duplicates lower part of harmony)

# Create a track to hold the notes. Add it to the sequence.
track = Track.new(seq)
seq.tracks << track

# Give the track a name and an instrument name (optional).
track.name = 'Bass'
track.instrument = GM_PATCH_NAMES[0]

# Add a volume controller event (optional).
track.events << Controller.new(0, CC_VOLUME, 127)

# Arguments for note on and note off
# constructors are channel, note, velocity, and delta_time. Channel numbers
# start at zero. We use the new Sequence#note_to_delta method to get the
# delta time length of a single quarter note.
track.events << ProgramChange.new(0, 1, 0)
quarter_note_length = seq.note_to_delta('quarter')

harmony_part.each_char { |c|
  # no use for note2
  note1, note2, volume = harmony_note_from_symbol(c)
  track.events << NoteOn.new(0, note1, volume, 0)
  track.events << NoteOff.new(0, note1, volume, quarter_note_length)
}

File.open('netlenka.mid', 'wb') { |file| seq.write(file) }
