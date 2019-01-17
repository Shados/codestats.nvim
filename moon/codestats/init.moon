-- TODO logging improvements:
-- - configurable on/off
-- - make it multiple-instance-safe
export codestats
nvimw = require 'wrapnvim'
snlib = require 'snlib'
inspect = require 'vendor.inspect'
deque = require 'vendor.deque'

-- Forward-define local helper functions
local *

codestats_version = "0.0.1" -- plugin version
pulse_endpoint = "api/my/pulses"

week_in_seconds = 604800

codestats =
  -- Module configuration, initialized on the vim side in setup.moon
  api_key: nil
  pulse_frequency_ms: nil
  api_url: nil
  curl_command: nil
  pulse_timer: nil
  logging: nil
  xps: {}
  previously_added: {}
  pulses: deque.new!
  pulsing: false
  -- Given use of flush calls, multiple append-mode writers to the log file is
  -- unlikely to result in corruption - if the log messages are larger than the
  -- buffer size, something very strange is going on
  log_file: io.open nvimw.g_get('codestats_log_file'), "a"

  -- Module functions, these largely form the 'public API' for the module
  init: (api_key) =>
    -- Initialize configuration options
    @api_key = api_key
    @pulse_frequency_ms = nvimw.g_get 'codestats_pulse_frequency_ms'
    @api_url = nvimw.g_get 'codestats_api_url'
    @curl_command = nvimw.g_get 'codestats_curl_command'
    @logging = nvimw.g_get 'codestats_logging'

    -- Set up default 0 values for the xps table
    setmetatable @xps, xps_metatable

    -- Set up events to track XP being created
    nvimw.exec [[
      augroup codestats
        au!
        au InsertCharPre * lua codestats:add_xp("InsertCharPre")
        au TextChanged * lua codestats:add_xp("TextChanged")
        au VimLeavePre * lua codestats:cleanup()
      augroup END
      ]]

    -- Add a timer to create and send XP pulses
    @pulse_timer = nvimw.fn "timer_start", {
      @pulse_frequency_ms,
      "codestats#pulse_xp",
      { repeat: -1 }
    }

  add_xp: (event) =>
    buffer_handle = nvimw.fn "bufnr", { "%" }
    -- Plugins can trigger TextChanged on unmodifiable buffers, which we wish
    -- to ignore
    modifiable = nvimw.b_option_get buffer_handle, 'modifiable'
    -- Additionally, we seem to get a TextChanged event fired on opening a
    -- buffer, without any changes made -- so ignore first one per buffer
    local filetype
    if modifiable and @previously_added[buffer_handle]
      filetype = nvimw.b_option_get buffer_handle, 'filetype'
      @xps[filetype] += 1
    unless @previously_added[buffer_handle]
      @previously_added[buffer_handle] = true
    @log "add_xp() called from #{event}, filetype: #{filetype}, buffer modifiable: #{modifiable}, previously added: #{@previously_added[buffer_handle]}"

  pulse_xp: () =>
    if snlib.length(@xps) == 0
      return
    -- Create pulse from current xps (clearing current xps), and schedule a pulse
    @pulses\push_right(create_pulse @xps)
    @schedule_pulse!

  schedule_pulse: () =>
    -- Guard against running more than one pulse process at a time
    if @pulsing
      return

    pulse = @pulses\pop_left!

    -- Check that the pulse is not more than a week old
    if os.difftime(os.time!, pulse.coded_time) > 604800
      return

    -- Creates a neovim job to run curl to push the pulse, returns the job ID
    cmd = {
      @curl_command,
      '--connect-timeout', '5'
      '--header', 'Content-Type: application/json',
      '--header', 'Accept: */*',
      '--header', "User-Agent: codestats.nvim/#{codestats_version}",
      '--header', "X-API-Token: #{@api_key}",
      '--request', 'POST',
      '--data', "#{pulse}",
      "#{@api_url}/#{pulse_endpoint}"
    }
    @log "Pulsing, curl job cmd:\n#{inspect cmd}"
    opts =
      on_exit: "codestats#pulse_callback"
      stdout_buffered: true
      pulse: pulse

    args = { cmd, opts }
    jobid = nvimw.fn "jobstart", args
    if jobid == 0
      @log "Failed to start job, invalid arguments:\n#{inspect args}"
      print "codestats.nvim: Unrecoverable error - disabling pulses"
      nvimw.fn "timer_stop", { @pulse_timer }
    elseif jobid == -1
      @log "Failed to start job, `#{@curl_command}` is not executable:\n"
      print "codestats.nvim: `#{@curl_command}` is not executable -- either fix that, or set g:codestats_curl_command to the path to a working curl executable"
      -- Add the pulse back onto the queue, at the front
      @pulses\push_left pulse
    else
      @pulsing = true

  pulse_callback: (opts, jobid, exit_code, _event) =>
    @pulsing = false
    pulse = opts.pulse
    data = opts.stdout
    response = nvimw.fn "json_decode", { data }
    if error = response['error']
      @log "Pulse job ID #{jobid} failed with '#{error}'! Re-scheduling pulse:\n#{inspect pulse}"
      -- Add the pulse back onto the queue, at the front
      @pulses\push_left pulse
    -- handle exit_code too

    if @pulses\length! > 0
      @schedule_pulse!

  cleanup: () =>
    @pulse_xp!
    @log "Launching cleanup pulse; XP will be lost if it fails"
    -- TODO Possibly serialize pulses to a cache file? Do I care that much?

  log: (msg) =>
    if @logging
      @log_file\write "#{msg}\n"
      @log_file\flush!

xps_metatable =
  __index: (_tbl, _key) -> return 0
create_pulse = (xps) ->
  -- The API expects a pulse as JSON data like:
  -- {
  --   "coded_at": "2016-04-24T01:43:56+12:00",
  --   "xps": [
  --     {"language": "C++",    "xp": 15},
  --     {"language": "Elixir", "xp": 30},
  --     {"language": "EEx",    "xp": 3}
  --   ]
  -- }
  pulse =
    -- We store the actual time for easier comparison with difftime, and rely
    -- on the metatable's __tostring to convert it to an ISO 8601 datetime
    -- while json encoding it
    coded_time: os.time!
    xps: { }

  for language, xp in pairs xps
    pulse.xps[#pulse.xps+1] =
      language: normalize_language(language)
      xp: xp
    -- Remove the XPs from the buffer
    xps[language] = nil

  setmetatable pulse, pulse_metatable

  return pulse

pulse_metatable =
  __tostring: (tbl) ->
    pulse =
      -- ISO 8601 datetime with local timezone offset
      coded_at: os.date '%Y-%m-%dT%H:%M:%S%z', tbl.coded_time
      xps: tbl.xps
    return nvimw.fn "json_encode", { pulse }


normalize_language = (language) ->
  -- NOTE: Could alternatively try to map filetypes to the language names that
  -- C::S uses, but C::S supports aliasing, and neither the list of aliases nor
  -- the list of all language names appear to be public, so doing any aliasing
  -- locally seems pointless
  if language == ""
    return "Plain text"
  else
    return language

return codestats
