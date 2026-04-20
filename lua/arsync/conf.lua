-- File: lua/conf.lua
local M = {}

local KEY_ORDER_META = "__key_order"
local KEY_ALIASES = {
	ignore_paths = "ignore_path",
}
local DEFAULT_WRITE_ORDER = {
	"auto_sync_up",
	"local_options",
	"local_path",
	"remote_host",
	"remote_user",
	"remote_options",
	"remote_or_local",
	"remote_path",
	"remote_port",
	"rsync_flags",
	"ignore_path",
	"backend",
	"remote_execute_host",
	"tmux_cmd",
	"entrypoint",
	"session_name",
}

M.global_conf_file = vim.fn.stdpath("data") .. "/arsync/global_conf.json"
M.replace_key = {
	"remote_host",
	"remote_execute_host",
	"remote_port",
	"remote_path",
	"local_path",
	"ignore_path",
	"backend",
	"auto_sync_up",
	"rsync_flags",
	"tmux_cmd",
	"entrypoint",
	"session_name",
}
M.init_key = { "remote_host", "remote_port", "remote_path", "local_path", "rsync_flags", "auto_sync_up" }

local function canonicalize_key(key)
	return KEY_ALIASES[key] or key
end

local function is_meta_key(key)
	return key == "hash" or key == KEY_ORDER_META
end

local function push_order_key(order, seen, key)
	key = canonicalize_key(key)
	if key and key ~= "" and not seen[key] and not is_meta_key(key) then
		table.insert(order, key)
		seen[key] = true
	end
end

local function clean_key_order(order)
	local cleaned = {}
	local seen = {}
	if type(order) ~= "table" then
		return cleaned
	end
	for _, key in ipairs(order) do
		push_order_key(cleaned, seen, key)
	end
	return cleaned
end

local function get_project_conf_path(local_path)
	local root = local_path or vim.loop.cwd()
	local local_conf_path_arsync = root .. "/.arsync"
	if vim.loop.fs_stat(local_conf_path_arsync) then
		return local_conf_path_arsync
	end

	local local_conf_path_vimarsync = root .. "/.vim-arsync"
	if vim.loop.fs_stat(local_conf_path_vimarsync) then
		return local_conf_path_vimarsync
	end

	return local_conf_path_arsync
end

if not vim.loop.fs_stat(vim.fn.fnamemodify(M.global_conf_file, ":h")) then
	vim.fn.mkdir(vim.fn.fnamemodify(M.global_conf_file, ":h"), "p")
end

local function write_conf_file(file_path, data)
	local file = io.open(file_path, "w")
	if not file then
		error("Cannot write to file: " .. file_path)
	end
	file:write(vim.json.encode(data))
	file:close()
end

local function read_conf_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return {}
	end

	local content = file:read("*a")
	file:close()
	if content == "" then
		return {}
	end

	local ok, result = pcall(vim.json.decode, content)
	return ok and result or {}
end

local function parse_arsync_config(content)
	local config = {}
	local order = {}
	local seen = {}

	for _, line in ipairs(vim.split(content, "\n", { plain = true, trimempty = false })) do
		local key, value = line:match("^(%S+)%s+(.+)$")
		if key and value then
			key = canonicalize_key(key)
			if key == "rsync_flags" then
				local ok, flags = pcall(vim.json.decode, value)
				config[key] = ok and flags or value
			elseif key == "remote_port" or key == "auto_sync_up" then
				config[key] = tonumber(value)
			elseif key == "local_path" or key == "remote_path" then
				config[key] = value:gsub("/+$", "")
			else
				config[key] = value
			end
			push_order_key(order, seen, key)
		end
	end

	config[KEY_ORDER_META] = order
	return config
end

local function normalize_conf(conf)
	if not conf then
		return nil
	end

	if conf.ignore_path == nil and conf.ignore_paths ~= nil then
		conf.ignore_path = conf.ignore_paths
	end
	conf.ignore_paths = nil

	if conf.local_path then
		conf.local_path = conf.local_path:gsub("/+$", "")
	end
	if conf.remote_path then
		conf.remote_path = conf.remote_path:gsub("/+$", "")
	end
	for _, numeric_key in ipairs({ "remote_port", "auto_sync_up" }) do
		if type(conf[numeric_key]) == "string" and conf[numeric_key]:match("^%-?%d+$") then
			conf[numeric_key] = tonumber(conf[numeric_key])
		end
	end
	if type(conf.rsync_flags) == "string" then
		local ok, flags = pcall(vim.json.decode, conf.rsync_flags)
		if ok then
			conf.rsync_flags = flags
		end
	end

	conf[KEY_ORDER_META] = clean_key_order(conf[KEY_ORDER_META])

	if conf.remote_execute_host == nil or conf.remote_execute_host == "" then
		conf.remote_execute_host = conf.remote_host
	end
	return conf
end

local function prepare_conf_for_write(conf_dict, local_path)
	local conf = normalize_conf(vim.deepcopy(conf_dict or {})) or {}
	conf.local_path = (local_path or conf.local_path or vim.loop.cwd()):gsub("/+$", "")
	conf.auto_sync_up = conf.auto_sync_up == nil and 0 or conf.auto_sync_up
	conf.local_options = conf.local_options or "-var"
	conf.remote_host = conf.remote_host or "unknown"
	conf.remote_options = conf.remote_options or "-var"
	conf.remote_or_local = conf.remote_or_local or "remote"
	conf.remote_path = conf.remote_path or "unknown"
	conf.remote_port = conf.remote_port == nil and 0 or conf.remote_port
	conf.rsync_flags = conf.rsync_flags or { "--max-size=100m" }
	if conf.remote_execute_host == conf.remote_host then
		conf.remote_execute_host = nil
	end
	if conf.ignore_path == "" then
		conf.ignore_path = nil
	end
	conf.hash = nil
	return conf
end

local function format_conf_line(key, value)
	if key == "rsync_flags" then
		local encoded = type(value) == "table" and vim.json.encode(value) or tostring(value)
		return string.format("%s %s", key, encoded)
	end
	if key == "remote_port" or key == "auto_sync_up" then
		return string.format("%s %d", key, tonumber(value) or 0)
	end
	if key == "local_path" or key == "remote_path" then
		return string.format("%s %s", key, tostring(value):gsub("/+$", ""))
	end
	return string.format("%s %s", key, tostring(value))
end

local function get_order_for_write(conf_dict, preferred_order)
	local order = {}
	local seen = {}

	for _, source in ipairs({ preferred_order, conf_dict[KEY_ORDER_META], DEFAULT_WRITE_ORDER }) do
		if type(source) == "table" then
			for _, key in ipairs(source) do
				key = canonicalize_key(key)
				if conf_dict[key] ~= nil then
					push_order_key(order, seen, key)
				end
			end
		end
	end

	local extra_keys = {}
	for key, value in pairs(conf_dict) do
		key = canonicalize_key(key)
		if value ~= nil and not seen[key] and not is_meta_key(key) then
			table.insert(extra_keys, key)
		end
	end
	table.sort(extra_keys)
	for _, key in ipairs(extra_keys) do
		push_order_key(order, seen, key)
	end

	return order
end

local function render_conf_lines(conf_dict, preferred_order, local_path)
	local conf = prepare_conf_for_write(conf_dict, local_path)
	local order = get_order_for_write(conf, preferred_order)
	conf[KEY_ORDER_META] = order

	local lines = {}
	for _, key in ipairs(order) do
		if conf[key] ~= nil then
			table.insert(lines, format_conf_line(key, conf[key]))
		end
	end

	return lines, conf
end

local function parse_conf_lines(content)
	local parsed_lines = {}
	local order = {}
	local seen = {}

	for _, line in ipairs(vim.split(content, "\n", { plain = true, trimempty = false })) do
		local key = line:match("^(%S+)%s+.+$")
		if key then
			key = canonicalize_key(key)
			table.insert(parsed_lines, { kind = "kv", key = key })
			push_order_key(order, seen, key)
		else
			table.insert(parsed_lines, { kind = "raw", text = line })
		end
	end

	return parsed_lines, order
end

local function read_project_conf(local_path)
	local project_conf_path = get_project_conf_path(local_path)
	local file = io.open(project_conf_path, "r")
	if not file then
		return nil
	end

	local content = file:read("*a")
	file:close()

	return normalize_conf(parse_arsync_config(content))
end

local function generate_hash(entry)
	local unique_string = entry.remote_host .. entry.remote_path
	return vim.fn.sha256(unique_string)
end

function M.load_conf()
	local local_conf = read_project_conf(vim.loop.cwd())
	if not local_conf then
		return nil
	end
	M.write_global_conf(local_conf)
	return local_conf
end

function M.write_global_conf(conf_dict)
	local global_conf = read_conf_file(M.global_conf_file)
	local global_entry = prepare_conf_for_write(conf_dict, conf_dict.local_path)
	global_entry[KEY_ORDER_META] = get_order_for_write(global_entry, conf_dict[KEY_ORDER_META])
	global_entry.hash = generate_hash(global_entry)

	for i, entry in ipairs(global_conf) do
		entry = normalize_conf(entry)
		if generate_hash(entry) == global_entry.hash then
			table.remove(global_conf, i)
			break
		end
	end

	if global_entry.remote_host == "unknown" then
		return
	end

	table.insert(global_conf, global_entry)
	write_conf_file(M.global_conf_file, global_conf)
end

function M.create_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = get_project_conf_path(local_path)
	local lines, conf_to_write = render_conf_lines(conf_dict, conf_dict[KEY_ORDER_META], local_path)

	local file = io.open(project_conf_path, "w")
	if not file then
		error("Cannot write to file: " .. project_conf_path)
	end
	file:write(table.concat(lines, "\n"))
	file:close()

	return normalize_conf(conf_to_write)
end

function M.update_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = get_project_conf_path(local_path)
	local current_file = io.open(project_conf_path, "r")
	if not current_file then
		local created_conf = M.create_project_conf(conf_dict)
		vim.cmd([[e!]])
		return created_conf
	end

	local current_content = current_file:read("*a")
	current_file:close()

	local _, target_conf = render_conf_lines(conf_dict, conf_dict[KEY_ORDER_META], local_path)
	local parsed_lines, current_order = parse_conf_lines(current_content)
	local final_order = get_order_for_write(target_conf, current_order)
	target_conf[KEY_ORDER_META] = final_order

	local pending_keys = {}
	local written_keys = {}
	for _, key in ipairs(final_order) do
		pending_keys[key] = true
	end

	local next_lines = {}
	for _, line in ipairs(parsed_lines) do
		if line.kind == "kv" then
			if target_conf[line.key] ~= nil and not written_keys[line.key] then
				table.insert(next_lines, format_conf_line(line.key, target_conf[line.key]))
				written_keys[line.key] = true
				pending_keys[line.key] = nil
			end
		else
			table.insert(next_lines, line.text)
		end
	end

	for _, key in ipairs(final_order) do
		if pending_keys[key] then
			table.insert(next_lines, format_conf_line(key, target_conf[key]))
		end
	end

	local file = io.open(project_conf_path, "w")
	if not file then
		error("Cannot write to file: " .. project_conf_path)
	end
	file:write(table.concat(next_lines, "\n"))
	file:close()

	vim.cmd([[e!]])
	return normalize_conf(target_conf)
end

function M.get_remote_execute_host(conf_dict)
	local conf = normalize_conf(conf_dict)
	return conf and conf.remote_execute_host or nil
end

function M.normalize_conf(conf_dict)
	return normalize_conf(conf_dict)
end

function M.delete_project_conf(conf_dict)
	local local_path = conf_dict["local_path"] or vim.loop.cwd()
	local project_conf_path = get_project_conf_path(local_path)

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

function M.get_url(entry)
	return entry.remote_host .. ":" .. entry.remote_path
end

return M
