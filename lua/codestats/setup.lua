local vimw = require("facade")
local start
start = function()
  if vimw.g_exists('codestats_initialized') then
    return nil
  end
  vimw.g_defaults({
    codestats_pulse_frequency_ms = 30000,
    codestats_api_url = "https://codestats.net",
    codestats_curl_command = "curl",
    codestats_logging = false,
    codestats_log_file = "/tmp/codestats.nvim.log"
  })
  do
    local api_key = vimw.g_get("codestats_api_key")
    if api_key then
      require('codestats')
      codestats:init(api_key)
      return vimw.g_set('codestats_initialized', true)
    else
      return vimw.exec("echom 'You need to set g:codestats_api_key'")
    end
  end
end
return {
  start = start
}
