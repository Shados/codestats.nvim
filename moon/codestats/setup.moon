-- This is in its own module to avoid having to require() the main
-- functionality in the case that someone is editing a filetype for which they
-- have codestats disabled
nvimw = require('wrapnvim')

start = ->
  -- Skip if already initialized
  if nvimw.g_exists 'codestats_initialized'
    return nil

  -- Initialize unset configuration options with defaults
  nvimw.g_defaults
    codestats_pulse_frequency_ms: 30000
    codestats_api_url: "https://codestats.net"
    codestats_curl_command: "curl"
    codestats_logging: false
    codestats_log_file: "/tmp/codestats.nvim.log"

  if api_key = nvimw.g_get "codestats_api_key"
    -- Load in the codestats global (for state tracking)
    require('codestats')
    codestats\init api_key
    nvimw.g_set 'codestats_initialized', true
  else
    nvimw.exec "echom 'You need to set g:codestats_api_key'"

{ :start }

