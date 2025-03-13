local backend = require("arsync.backend")
local rsync_backend = require("arsync.backend.rsync")
local M = setmetatable({}, { __index = backend.Backend })

function M.transfer(direction, conf, rel_filepath)
	-- Check if rel_filepath is a directory or empty

	-- Call Python function for SFTP transfer
	res = vim.fn.ArsyncSFTPTransfer(direction, conf, rel_filepath)
	return {}
end

function M.cleanup()
	return vim.fn.ArsyncSFTPCleanup()
end

function M.get_required_config()
	return {
		"remote_host",
		"remote_path",
		"local_path",
		"remote_user",
	}
end

return M
