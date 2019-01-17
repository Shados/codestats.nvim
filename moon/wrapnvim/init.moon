snlib = require('snlib')

nvimw = with {}
  -- Get a g: variable, or a default value if unset
  .g_get = (key, default) ->
    if var = vim.api.nvim_get_var key
      var
    else
      default

  -- Set a g: variable
  .g_set = (key, val) ->
    vim.api.nvim_set_var key, val

  -- Return true if a g: variable exists; this exists mainly for clarity of intent
  .g_exists = (key) ->
    if pcall vim.api.nvim_get_var, key
      true
    else
      false

  -- Set a g: variable to a default if it is unset, otherwise leave it as-is
  .g_default = (key, default) ->
    val, _ = pcall vim.api.nvim_get_var, key
    unless val
      vim.api.nvim_set_var key, default

  -- Set g: dictionary defaults based on given table
  .g_defaults = (tbl) ->
    for key, default in pairs tbl
      .g_default key, default

  -- Set a b: variable
  .b_set = (buffer_handle, key, val) ->
    vim.api.nvim_buf_set_var buffer_handle, key, val

  -- Get a b: variable, or a default value if unset
  .b_get = (buffer_handle, key, default) ->
    if var = vim.api.nvim_buf_get_var buffer_handle, key
      var
    else
      default

  -- Executes a multi-line string containing Ex commands
  .exec = (str) ->
    str_by_lines = snlib.split(str, "\n")
    for _i, line in ipairs str_by_lines
      -- TODO escape line properly
      vim.api.nvim_command("exec '#{line}'")

  -- Get an option, or a default value if unset
  .option_get = (key, default) ->
    if var = vim.api.nvim_get_option key
      var
    else
      default

  -- Get a buffer option, or a default value if unset
  .b_option_get = (buffer_handle, key, default) ->
    if var = vim.api.nvim_buf_get_option buffer_handle, key
      var
    else
      default

  -- Call a VimL function with the given arguments, return the result
  .fn = (fn_str, args={}) ->
    vim.api.nvim_call_function(fn_str, args)

  -- Empty Lua table is considered a Vim list by default; this results in an
  -- empty Vim dictionary instead
  .empty_dict = () ->
    { [vim.type_idx]: vim.types.dictionary }

return nvimw
