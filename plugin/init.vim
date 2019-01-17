" TODO check for nvim support, error out otherwise
lua << EOF
local setup = require("codestats.setup")
setup.start()
EOF
