local backend = require("arsync.backend.init")
local M = setmetatable({}, { __index = backend.Backend })

function M.join_path(base_path, file_path)
	-- Remove trailing slash from base_path if it exists
	if base_path:sub(-1) == "/" then
		base_path = base_path:sub(1, -2)
	end

	return base_path .. "/" .. file_path
end

function M.init(conf)
	if not vim.fn.executable("scp") then
		error("scp is not installed")
	end
end

function M.transfer(direction, config, rel_path)
	local local_path = M.join_path(config.local_path, rel_path)
	local remote_path = M.join_path(config.remote_path, rel_path)

	-- Check if it's a directory
	local is_dir = vim.fn.isdirectory(local_path) == 1
  local socket_path = vim.fn.stdpath("data") .. "/arsync/scp_socket_" .. config.remote_host
	local cmd = { "scp -vvv -o \"ControlPath=scp_socket\"" }
	if is_dir then
		-- Use SCP's -r option to transfer directories
		table.insert(cmd, "-r")
	end

	-- Build SCP command

	-- Add SSH options
	if config.ssh_port then
		table.insert(cmd, "-P")
		table.insert(cmd, config.ssh_port)
	end

	if config.identity_file then
		table.insert(cmd, "-i")
		table.insert(cmd, config.identity_file)
	end

	-- Set source and destination based on transfer direction
	local src, dst
	local remote_prefix

	if config.remote_user then
		remote_prefix = config.remote_user .. "@" .. config.remote_host
	else
		remote_prefix = config.remote_host
	end
	if config.remote_port and config.remote_port ~= "0" and config.remote_port ~= 0 then
		remote_prefix = remote_prefix .. ":" .. config.remote_port
	end

	if direction == "up" then
		src = local_path
		dst = remote_prefix .. ":" .. remote_path
	elseif direction == "down" then
		src = remote_prefix .. ":" .. remote_path
		dst = local_path
	else
		return {}
	end

	table.insert(cmd, src)
	table.insert(cmd, dst)

	return cmd
end

function M.cleanup()
	-- SCP doesn't need connection cleanup
	return true
end

function M.get_required_config()
	return {
		"remote_host",
		"remote_path",
		"local_path",
	}
end

return M
