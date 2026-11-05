local conf = require("arsync.conf")

local M = {}

---Whether the current buffer is an arsync configuration file.
---@return boolean
function M.is_conf_buffer()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype == "arsync" then
		return true
	end
	local name = vim.api.nvim_buf_get_name(buf)
	return name:match("%.arsync$") ~= nil or name:match("%.vim%-arsync$") ~= nil
end

---Completion items for every key accepted in a `.arsync` file.
---@return table[]
function M.key_items()
	local items = {}
	for _, entry in ipairs(conf.get_conf_keys()) do
		table.insert(items, {
			label = entry.key,
			detail = "arsync config key",
			documentation = {
				kind = "markdown",
				value = string.format("**%s** from Arsync\n\n%s", entry.key, entry.description),
			},
			insertText = entry.key,
		})
	end
	return items
end

return M
