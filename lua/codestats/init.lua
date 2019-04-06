local vimw = require("facade")
local table_ = require("earthshine.table")
local inspect = require("vendor.inspect")
local deque = require("vendor.deque")
local codestats_version, pulse_endpoint, week_in_seconds, xps_metatable, create_pulse, pulse_metatable, normalize_language
codestats_version = "0.0.1"
pulse_endpoint = "api/my/pulses"
week_in_seconds = 604800
codestats = {
  api_key = nil,
  pulse_frequency_ms = nil,
  api_url = nil,
  curl_command = nil,
  pulse_timer = nil,
  logging = nil,
  xps = { },
  previously_added = { },
  pulses = deque.new(),
  pulsing = false,
  log_file = io.open(vimw.g_get('codestats_log_file'), "a"),
  init = function(self, api_key)
    self.api_key = api_key
    self.pulse_frequency_ms = vimw.g_get('codestats_pulse_frequency_ms')
    self.api_url = vimw.g_get('codestats_api_url')
    self.curl_command = vimw.g_get('codestats_curl_command')
    self.logging = vimw.g_get('codestats_logging')
    setmetatable(self.xps, xps_metatable)
    vimw.exec([[      augroup codestats
        au!
        au InsertCharPre * lua codestats:add_xp("InsertCharPre")
        au TextChanged * lua codestats:add_xp("TextChanged")
        au VimLeavePre * lua codestats:cleanup()
      augroup END
      ]])
    self.pulse_timer = vimw.fn("timer_start", {
      self.pulse_frequency_ms,
      "codestats#pulse_xp",
      {
        ["repeat"] = -1
      }
    })
  end,
  add_xp = function(self, event)
    local buffer_handle = vimw.fn("bufnr", {
      "%"
    })
    local modifiable = vimw.b_option_get(buffer_handle, 'modifiable')
    local filetype
    if modifiable then
      filetype = vimw.b_option_get(buffer_handle, 'filetype')
      local _update_0 = filetype
      self.xps[_update_0] = self.xps[_update_0] + 1
      return self:log("add_xp() called from " .. tostring(event) .. ", filetype: " .. tostring(filetype))
    end
  end,
  pulse_xp = function(self)
    if table_.size(self.xps) == 0 then
      return 
    end
    self.pulses:push_right(create_pulse(self.xps))
    return self:schedule_pulse()
  end,
  schedule_pulse = function(self)
    if self.pulsing then
      return 
    end
    local pulse = self.pulses:pop_left()
    if os.difftime(os.time(), pulse.coded_time) > 604800 then
      return 
    end
    local cmd = {
      self.curl_command,
      '--connect-timeout',
      '5',
      '--header',
      'Content-Type: application/json',
      '--header',
      'Accept: */*',
      '--header',
      "User-Agent: codestats.nvim/" .. tostring(codestats_version),
      '--header',
      "X-API-Token: " .. tostring(self.api_key),
      '--request',
      'POST',
      '--data',
      tostring(pulse),
      tostring(self.api_url) .. "/" .. tostring(pulse_endpoint)
    }
    self:log("Pulsing, curl job cmd:\n" .. tostring(inspect(cmd)))
    local opts = {
      on_exit = "codestats#pulse_callback",
      stdout_buffered = true,
      pulse = pulse
    }
    local args = {
      cmd,
      opts
    }
    local jobid = vimw.fn("jobstart", args)
    if jobid == 0 then
      self:log("Failed to start job, invalid arguments:\n" .. tostring(inspect(args)))
      print("codestats.nvim: Unrecoverable error - disabling pulses")
      return vimw.fn("timer_stop", {
        self.pulse_timer
      })
    elseif jobid == -1 then
      self:log("Failed to start job, `" .. tostring(self.curl_command) .. "` is not executable:\n")
      print("codestats.nvim: `" .. tostring(self.curl_command) .. "` is not executable -- either fix that, or set g:codestats_curl_command to the path to a working curl executable")
      return self.pulses:push_left(pulse)
    else
      self.pulsing = true
    end
  end,
  pulse_callback = function(self, opts, jobid, exit_code, _event)
    self.pulsing = false
    local pulse = opts.pulse
    local data = opts.stdout
    local response = vimw.fn("json_decode", {
      data
    })
    do
      local error = response['error']
      if error then
        self:log("Pulse job ID " .. tostring(jobid) .. " failed with '" .. tostring(error) .. "'! Re-scheduling pulse:\n" .. tostring(inspect(pulse)))
        self.pulses:push_left(pulse)
      end
    end
    if self.pulses:length() > 0 then
      return self:schedule_pulse()
    end
  end,
  cleanup = function(self)
    self:pulse_xp()
    return self:log("Launching cleanup pulse; XP will be lost if it fails")
  end,
  log = function(self, msg)
    if self.logging then
      self.log_file:write(tostring(msg) .. "\n")
      return self.log_file:flush()
    end
  end
}
xps_metatable = {
  __index = function(_tbl, _key)
    return 0
  end
}
create_pulse = function(xps)
  local pulse = {
    coded_time = os.time(),
    xps = { }
  }
  for language, xp in pairs(xps) do
    pulse.xps[#pulse.xps + 1] = {
      language = normalize_language(language),
      xp = xp
    }
    xps[language] = nil
  end
  setmetatable(pulse, pulse_metatable)
  return pulse
end
pulse_metatable = {
  __tostring = function(tbl)
    local pulse = {
      coded_at = os.date('%Y-%m-%dT%H:%M:%S%z', tbl.coded_time),
      xps = tbl.xps
    }
    return vimw.fn("json_encode", {
      pulse
    })
  end
}
normalize_language = function(language)
  if language == "" then
    return "Plain text"
  else
    return language
  end
end
return codestats
