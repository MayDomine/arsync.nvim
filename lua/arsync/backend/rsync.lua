local backend = require("arsync.backend.init")

local M = setmetatable({}, { __index = backend.Backend })

function M.init(conf)
	if not vim.fn.executable("rsync") then
		error("rsync is not installed")
	end
end

function M.transfer(direction, conf, rel_filepath)
	local cmd = { "rsync" }
	local ignore_path = conf.ignore_path:gsub("^%s*%[%s*", "") -- Remove leading "["
	ignore_path = ignore_path:gsub("%s*%]%s*$", "") -- Remove trailing "]"
	ignore_path = vim.split(ignore_path, ",")
	ignore_path = vim.tbl_map(function(path)
		return path:gsub('^%s*"(.-)"%s*$', "%1")
	end, ignore_path)
	for _, path in ipairs(ignore_path) do
		table.insert(cmd, "--exclude")
		table.insert(cmd, path)
	end
	if conf.remote_or_local == "remote" then
		local ssh_cmd = conf.remote_port ~= 0 and ("ssh -p " .. conf.remote_port) or "ssh"
		local remote_prefix = conf.remote_host
		if conf.remote_user then
			remote_prefix = conf.remote_user .. "@" .. remote_prefix
		end

		if direction == "up" then
			table.insert(cmd, conf.remote_options)
			if not conf.remote_options:match("e") then
				table.insert(cmd, "-e")
				table.insert(cmd, ssh_cmd)
			end
			table.insert(cmd, conf.local_path .. "/" .. rel_filepath)
			table.insert(cmd, remote_prefix .. ":" .. conf.remote_path .. "/" .. rel_filepath)
		elseif direction == "down" then
			table.insert(cmd, conf.remote_options)
			if not conf.remote_options:match("e") then
				table.insert(cmd, "-e")
				table.insert(cmd, ssh_cmd)
			end
			table.insert(cmd, remote_prefix .. ":" .. conf.remote_path .. "/" .. rel_filepath)
			table.insert(cmd, conf.local_path .. "/" .. rel_filepath)
		end
	end

	-- 添加额外的 rsync 标志
	if conf.rsync_flags then
		for _, flag in ipairs(conf.rsync_flags) do
			table.insert(cmd, flag)
		end
	end

	return cmd
end

function M.cleanup()
	-- rsync 不需要清理
end

function M.get_required_config()
	return {
		"remote_host",
		"remote_path",
		"local_path",
		"remote_or_local",
		"ignore_path",
		"remote_options",
		"local_options",
	}
end

return M
