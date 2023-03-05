local Vault = require "obs.vault"

local M = {}

---This functions creates module filesds that hold API tables.
---@param opts obs.VaultOpts
function M.setup(opts)
    M.vault = Vault:new(opts)
end

return M
