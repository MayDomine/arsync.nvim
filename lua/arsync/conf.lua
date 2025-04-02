-- File: lua/conf.lua
local M = {}

M.global_conf_file = vim.fn.stdpath("data") .. "/arsync/global_conf.json"
M.replace_key = { "remote_host", "remote_port", "remote_path", "local_path", "ignore_path", "backend", "auto_sync_up" }
M.init_key = { "remote_host", "remote_port", "remote_path", "local_path", "rsync_flags", "auto_sync_up" }

if not vim.loop.fs_stat(vim.fn.fnamemodify(M.global_conf_file, ":h")) then
	vim.fn.mkdir(vim.fn.fnamemodify(M.global_conf_file, ":h"), "p")
end
-- Read JSON configuration file
local function write_conf_file(file_path, data)
	local file = io.open(file_path, "w")
	if not file then
		error("Cannot write to file: " .. file_path)
	end
	local entry = vim.json.encode(data)

	file:write(entry)
	file:close()
end
local function read_conf_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		file = io.open(file_path, "w")
		file:close()
		error("Cannot find file: " .. file_path)
		return {}
	end
	local content = file:read("*a")
	file:close()
	local ok, result = pcall(vim.json.decode, content)
	return ok and result or {}
end

-- Parse .arsync configuration file
local function parse_arsync_config(content)
	local config = {}
	for line in content:gmatch("[^\r\n]+") do
		local key, value = line:match("^(%S+)%s+(.+)$")
		if key and value then
-- Special handling of rsync_flags
			if key == "rsync_flags" then
-- Parsing formats like ["--max-size=100m"]
				local flags = vim.json.decode(value)
				config[key] = flags
-- Special handling of numeric values
			elseif key == "remote_port" or key == "auto_sync_up" then
				config[key] = tonumber(value)
-- Special handling of local_path and remote_path, removing trailing \
			elseif key == "local_path" or key == "remote_path" then
				config[key] = value:gsub("/+$", "")
			else
				config[key] = value
			end
		end
	end
	return config
end

-- Add this function definition
local function generate_hash(entry)
	-- Concatenate relevant fields to form a unique string
	local unique_string = entry.remote_host .. entry.remote_path
	-- Generate a simple hash (e.g., using a checksum)
	return vim.fn.sha256(unique_string)
end

-- Load .arsync configuration
function M.load_conf()
	local local_conf_path_arsync = vim.loop.cwd() .. "/.arsync"
	local local_conf_path_vimarsync = vim.loop.cwd() .. "/.vim-arsync"
	local file = io.open(local_conf_path_arsync, "r") or io.open(local_conf_path_vimarsync, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	local local_conf = parse_arsync_config(content)
  M.write_global_conf(local_conf)
	return local_conf
end

function M.write_global_conf(conf_dict)
  	local global_conf = read_conf_file(M.global_conf_file)
  	conf_dict.hash = generate_hash(conf_dict)
  	local found = false
  	for i, entry in ipairs(global_conf) do
  		local entry_hash = generate_hash(entry)
  		if entry_hash == conf_dict.hash then
  			table.remove(global_conf, i)
  			break
  		end
  	end
    if conf_dict.remote_host == "unknown" then
      return
    end
  	table.insert(global_conf, conf_dict)
  	local global_file = io.open(M.global_conf_file, "w")
  	if global_file then
  		global_file:write(vim.json.encode(global_conf))
  		global_file:close()
  	end
end


-- Create configuration file
function M.create_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = local_path .. "/.arsync"

	local lines = {
		string.format("auto_sync_up %d", conf_dict.auto_sync_up or 0),
		string.format("local_options %s", conf_dict.local_options or "-var"),
		string.format("local_path %s", local_path),
		string.format("remote_host %s", conf_dict.remote_host or "unknown"),
		string.format("remote_options %s", conf_dict.remote_options or "-var"),
		string.format("remote_or_local %s", conf_dict.remote_or_local or "remote"),
		string.format("remote_path %s", conf_dict.remote_path or "unknown"),
		string.format("remote_port %d", conf_dict.remote_port or 0),
		string.format("rsync_flags %s", vim.json.encode(conf_dict.rsync_flags or { "--max-size=100m" })),
	}
	local option_lines = {
		{ "ignore_path %s", conf_dict.ignore_path or nil },
		{ "backend %s", conf_dict.backend or nil },
	}
	for _, l in ipairs(option_lines) do
		if l[2] then
			table.insert(lines, string.format(l[1], l[2]))
		end
	end

	local file = io.open(project_conf_path, "w")
	if not file then
		error("Cannot write to file: " .. project_conf_path)
	end
	file:write(table.concat(lines, "\n"))
	file:close()

	return conf_dict
end

-- Update project configuration
function M.update_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = local_path .. "/.arsync"
	local current_conf = {}

	for _, k in ipairs(M.replace_key) do
		if conf_dict[k] ~= nil then
			current_conf[k] = conf_dict[k]
		end
	end
	M.create_project_conf(current_conf)
	vim.cmd([[e!]])
	return current_conf
end

-- Delete project configuration
function M.delete_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = local_path .. "/.arsync"

	os.remove(project_conf_path)

	local global_conf = read_conf_file(M.global_conf_file)
	for i, entry in ipairs(global_conf) do
		if entry.hash == generate_hash(conf_dict) then
			table.remove(global_conf, i)
			write_conf_file(M.global_conf_file, global_conf)
			break
		end
	end
end


-- Define the get_url function
function M.get_url(entry)
	-- Construct a URL or identifier based on the entry
	local url = entry.remote_host .. ":" .. entry.remote_path
	return url
end

return M
