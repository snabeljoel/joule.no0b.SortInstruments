
-- remove empty slots

function instrument_is_empty(instrument)
 local inst = renoise.song():instrument(instrument)
 local has_sample_data = false
 for _, sample in ipairs(inst.samples) do
  has_sample_data = has_sample_data or sample.sample_buffer.has_sample_data
 end
 if inst.name ~= "" or inst.plugin_properties.plugin_loaded or inst.midi_output_properties.device_name ~= "" or has_sample_data then return false else return true end
end
function remove_empty_slots()
 for instrument in ripairs(renoise.song().instruments) do
  if instrument_is_empty(instrument) and #renoise.song().instruments > 1 then
   renoise.song().delete_instrument_at(renoise.song(),instrument)
  end 
 end
end

-- generic instrument list manipulation used by the sorting methods below

function sort_instruments(new_mapping)
 renoise.app():show_status("Remapping instruments ...")
 table.sort(new_mapping, function(a, b) return a.original_position < b.original_position end)
 local doing_pos = 1
 while doing_pos < table.count(new_mapping) do
  while new_mapping[doing_pos].new_position == doing_pos and doing_pos < table.count(new_mapping) do
   doing_pos = doing_pos + 1
  end
 renoise.song().swap_instruments_at(renoise.song(), doing_pos, new_mapping[doing_pos].new_position)
 new_mapping[doing_pos], new_mapping[new_mapping[doing_pos].new_position] = new_mapping[new_mapping[doing_pos].new_position], new_mapping[doing_pos]
 end
 renoise.app():show_status("")
end

-- returns a mapping definition sorted alphabetically by instrument name

function map_alphabetic()
 local map_table = { }
 for i, instrument in ipairs(renoise.song().instruments) do table.insert(map_table, { name = instrument.name, original_position = i }) end
 table.sort(map_table, function(a, b)
  if a.name == b.name then return a.original_position < b.original_position
  else return string.upper(a.name) < string.upper(b.name) end  
  end) 
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 return map_table
end

-- returns a reversed mapping definition

function map_reverse()
 local map_table = { }
 for _, instrument in ipairs(renoise.song().instruments) do
  table.insert(map_table, 1, { name = instrument.name, original_position = _ })
 end
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 return map_table
end

-- returns a mapping definition sorted by sample(s) size in instrument

function size_of_instrument(instrument)
 local bitsize = 0
 for _, sample in ipairs(renoise.song():instrument(instrument).samples) do
  if sample.sample_buffer.has_sample_data then
  bitsize = bitsize + sample.sample_buffer.bit_depth * sample.sample_buffer.number_of_frames * sample.sample_buffer.number_of_channels
  end
 end
 return bitsize
end

function map_size()
 local map_table = { }
 for _, instrument in ipairs(renoise.song().instruments) do
  table.insert(map_table, { name = instrument.name, original_position = _, size = size_of_instrument(_) })
 end
 table.sort(map_table, function(b, a)
  if a.size == b.size then return a.original_position > b.original_position
  else return a.size < b.size
  end  
  end)
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 return map_table
end

-- returns a mapping definition sorted by appearance in song (scanned horizonally)

function map_appearance_song()
 local first_hit = { }
 local note_cell = 0
 local map_table = { } 
 for _, instrument in ipairs(renoise.song().instruments) do table.insert(map_table, { name = instrument.name, original_position = _ }) end
 renoise.app():show_status("Scanning song ...")
 for sequence, pattern_index in ipairs(renoise.song().sequencer.pattern_sequence) do
  local pattern = renoise.song():pattern(pattern_index)
  for line = 1, pattern.number_of_lines do
   for track = 1, renoise.song().sequencer_track_count do
    if not pattern:track(track).is_empty then
    if not pattern:track(track):line(line).is_empty then
    for note_column = 1, renoise.song():track(track).visible_note_columns do
     note_cell = note_cell + 1
     local n_column = pattern:track(track):line(line):note_column(note_column)
     if not n_column.is_empty then
      if map_table[n_column.instrument_value+1] then -- lots of stuff here for avoiding "trying to index nil.." error
       if map_table[n_column.instrument_value+1].note_cell then
       map_table[n_column.instrument_value+1].note_cell = math.min(note_cell, map_table[n_column.instrument_value+1].note_cell)
       else 
        map_table[n_column.instrument_value+1].note_cell = note_cell
       end
      end
     end
    end end end end end end
 for pos in ipairs(map_table) do
  if not map_table[pos].note_cell then map_table[pos].note_cell = math.huge end
 end
  table.sort(map_table, function(a, b)
  if a.note_cell == b.note_cell then return a.original_position < b.original_position
  else return a.note_cell < b.note_cell end
  end)
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 renoise.app():show_status("")
 return map_table
end

-- returns a mapping definition sorted by appearance in song (scanned track by track)

function map_appearance_track()
 local first_hit = { }
 local hit_order = 0
 local map_table = { }  
 for _, instrument in ipairs(renoise.song().instruments) do table.insert(map_table, { name = instrument.name, original_position = _, first_hit = math.huge }) end 
renoise.app():show_status("Scanning song ...")
for track_index = 1, renoise.song().sequencer_track_count do
 for seq, pattern_index in ipairs(renoise.song().sequencer.pattern_sequence) do
  local track = renoise.song():pattern(pattern_index):track(track_index)
  if not track.is_empty and renoise.song():track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
   for line_index, line in ipairs(track.lines) do
    if not line.is_empty then
     for note_column_index = 1, renoise.song():track(track_index).visible_note_columns do
      local val = line:note_column(note_column_index)    
      if not val.is_empty then
      if val.instrument_value ~= 255 then
      if map_table[val.instrument_value+1] then
      if map_table[val.instrument_value+1].first_hit > hit_order then 
       hit_order = hit_order + 1
       map_table[val.instrument_value+1].first_hit = hit_order
end end end end end end end end end end
 table.sort(map_table, function(a, b)
  if a.first_hit == b.first_hit then return a.original_position < b.original_position
  else return a.first_hit < b.first_hit end  
  end)
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 renoise.app():show_status("")
 return map_table 
end

-- returns a randomized mapping definition

function map_randomize()
 local map_table = { }
 for _, instrument in ipairs(renoise.song().instruments) do table.insert(map_table, { name = instrument.name, original_position = _, random = math.random() }) end
 table.sort(map_table, function(a, b) return a.random < b.random end)
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 return map_table
end

-- returns a mapping definition sorted by most used instrument

function map_most_used()
 local map_table = { }
 for _, instrument in ipairs(renoise.song().instruments) do table.insert(map_table, { name = instrument.name, original_position = _, population = 0 }) end
 renoise.app():show_status("Scanning song ...")
for seq, pattern_index in ipairs(renoise.song().sequencer.pattern_sequence) do
 for track_index = 1, renoise.song().sequencer_track_count do
  local track = renoise.song():pattern(pattern_index):track(track_index)
  if not track.is_empty and renoise.song():track(track_index).type == renoise.Track.TRACK_TYPE_SEQUENCER then
   for line_index, line in ipairs(track.lines) do
    if not line.is_empty then
     for note_column_index = 1, renoise.song():track(track_index).visible_note_columns do
      local val = line:note_column(note_column_index)
      if not val.is_empty then
       if val.instrument_value ~= 255 then
        map_table[val.instrument_value + 1].population = map_table[val.instrument_value + 1].population + 1
end end end end end end end end 
 table.sort(map_table, function(a, b)
  if a.population == b.population then return a.original_position < b.original_position
  else return a.population > b.population end  
  end) 
 for instrument = 1, #map_table do
  map_table[instrument].new_position = instrument
 end
 renoise.app():show_status("")
 return map_table
end

-- Menu entries

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Name",
  invoke = function() sort_instruments(map_alphabetic()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Size",
  invoke = function() sort_instruments(map_size()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Most Used",
  invoke = function() sort_instruments(map_most_used()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Appearance (from start)",
  invoke = function() sort_instruments(map_appearance_song()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Appearance (from track)",
  invoke = function() sort_instruments(map_appearance_track()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Randomize",
  invoke = function() sort_instruments(map_randomize()) end
}

renoise.tool():add_menu_entry {
  name = "Instrument Box:Sort Instruments ...:Reverse",
  invoke = function() sort_instruments(map_reverse()) end
}

renoise.tool():add_menu_entry {
  name = "---Instrument Box:Sort Instruments ...:Remove empty slots",
  invoke = function() remove_empty_slots() end
}
