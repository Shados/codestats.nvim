-- TODO UTF8, fuck me
-- Splits strings on a given delimiter
split = (str, delimiter) ->
  -- Yes, we really do start the indexes at 0; this is because we're working
  -- with #str and str\sub, *not* indexing a table
  collected = {}
  previous_index = 0

  for current_index = 0, #str
    current_char = str\sub current_index, current_index
    is_delimiter = current_char == delimiter

    -- If we're at a delimiter, we need to append to the list of collected
    -- substrings
    if is_delimiter
      table.insert collected, str\sub previous_index, current_index - 1

      -- Update the previous_index value to point to just after this delimiter
      previous_index = current_index + 1

    -- We're done with the loop and need to return an actual value
    if current_index == #str
      if is_delimiter
        -- In the case of ending on a delimiter, we need a trailing empty
        -- string in order to be able to re-create the original str via a
        -- theoretical join(collected, ".") function - in order to be
        -- reversible, that is
        table.insert collected, ""
      else
        -- Otherwise, just add the current substring
        table.insert collected, str\sub previous_index, current_index
      return collected

-- TODO `strip` or `trim` function to remove leading/trailing whitespace?

keys = (tbl) ->
  i = 0
  key_list = {}
  for key, _val in pairs tbl
    i += 1
    key_list[i] = key
  return key_list

length = (tbl) ->
  i = 0
  for _key, _val in pairs tbl
    i += 1
  return i

{ :split, :keys, :length }
