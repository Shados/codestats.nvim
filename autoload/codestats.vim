function! codestats#pulse_xp(timer_id) abort
  lua codestats:pulse_xp()
endfunction

function! codestats#pulse_callback(jobid, exit_code, event) dict abort
  call luaeval('codestats:pulse_callback(_A[1], _A[2], _A[3], _A[4])', [self, a:jobid, a:exit_code, a:event])
endfunction
