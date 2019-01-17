local snlib = require('snlib')
local nvimw
do
  local _with_0 = { }
  _with_0.g_get = function(key, default)
    do
      local var = vim.api.nvim_get_var(key)
      if var then
        return var
      else
        return default
      end
    end
  end
  _with_0.g_set = function(key, val)
    return vim.api.nvim_set_var(key, val)
  end
  _with_0.g_exists = function(key)
    if pcall(vim.api.nvim_get_var, key) then
      return true
    else
      return false
    end
  end
  _with_0.g_default = function(key, default)
    local val, _ = pcall(vim.api.nvim_get_var, key)
    if not (val) then
      return vim.api.nvim_set_var(key, default)
    end
  end
  _with_0.g_defaults = function(tbl)
    for key, default in pairs(tbl) do
      _with_0.g_default(key, default)
    end
  end
  _with_0.b_set = function(buffer_handle, key, val)
    return vim.api.nvim_buf_set_var(buffer_handle, key, val)
  end
  _with_0.b_get = function(buffer_handle, key, default)
    do
      local var = vim.api.nvim_buf_get_var(buffer_handle, key)
      if var then
        return var
      else
        return default
      end
    end
  end
  _with_0.exec = function(str)
    local str_by_lines = snlib.split(str, "\n")
    for _i, line in ipairs(str_by_lines) do
      vim.api.nvim_command("exec '" .. tostring(line) .. "'")
    end
  end
  _with_0.option_get = function(key, default)
    do
      local var = vim.api.nvim_get_option(key)
      if var then
        return var
      else
        return default
      end
    end
  end
  _with_0.b_option_get = function(buffer_handle, key, default)
    do
      local var = vim.api.nvim_buf_get_option(buffer_handle, key)
      if var then
        return var
      else
        return default
      end
    end
  end
  _with_0.fn = function(fn_str, args)
    if args == nil then
      args = { }
    end
    return vim.api.nvim_call_function(fn_str, args)
  end
  _with_0.empty_dict = function()
    return {
      [vim.type_idx] = vim.types.dictionary
    }
  end
  nvimw = _with_0
end
return nvimw
