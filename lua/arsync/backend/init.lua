local M = {}

-- Configuration item definition
M.CONFIG_SCHEMA = {
	-- General configuration items
	common = {
		-- Required configurations
		remote_host = "string", -- Remote host address
		remote_path = "string", -- Remote path

		-- Optional configurations (with default values)
		backend = { type = "string", default = "rsync" }, -- Backend type
		remote_user = { type = "string", default = nil }, -- Remote username
		remote_port = { type = "number", default = 0 }, -- Remote port
		local_path = { type = "string", default = vim.loop.cwd() }, -- Local path
		auto_sync_up = { type = "number", default = 0 }, -- Whether to auto-sync
	},

	-- rsync specific configuration items
	rsync = {
		-- Optional configurations (with default values)
		remote_or_local = { type = "string", default = "remote" }, -- Transfer mode
		local_options = { type = "string", default = "-var" }, -- rsync local options
		remote_options = { type = "string", default = "-varz" }, -- rsync remote options
		ignore_path = { type = "string", default = "" },
		rsync_flags = { type = "table", default = { "--max-size=100m" } }, -- rsync additional flags
	},

	-- sftp specific configuration items
	sftp = {
		timeout = { type = "number", default = 10 }, -- Connection timeout
	},
}

-- Backend interface specification
M.Backend = {
	-- Initialize backend
	init = function(conf) end,
	-- Transfer files
	transfer = function(direction, conf, rel_filepath) end,
	-- Clean up resources
	cleanup = function() end,
	-- Get required configuration items
	get_required_config = function() end,
	toggle = function(disable) end,
}

return M

