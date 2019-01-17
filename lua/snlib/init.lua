local split
split = function(str, delimiter)
  local collected = { }
  local previous_index = 0
  for current_index = 0, #str do
    local current_char = str:sub(current_index, current_index)
    local is_delimiter = current_char == delimiter
    if is_delimiter then
      table.insert(collected, str:sub(previous_index, current_index - 1))
      previous_index = current_index + 1
    end
    if current_index == #str then
      if is_delimiter then
        table.insert(collected, "")
      else
        table.insert(collected, str:sub(previous_index, current_index))
      end
      return collected
    end
  end
end
local keys
keys = function(tbl)
  local i = 0
  local key_list = { }
  for key, _val in pairs(tbl) do
    i = i + 1
    key_list[i] = key
  end
  return key_list
end
local length
length = function(tbl)
  local i = 0
  for _key, _val in pairs(tbl) do
    i = i + 1
  end
  return i
end
return {
  split = split,
  keys = keys,
  length = length
}
