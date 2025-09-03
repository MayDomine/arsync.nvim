-- Lua plugin to handle async rsync synchronization between hosts
-- Title: vimarsync
-- Author: Ken Hasselmann (converted to Lua)
-- License: MIT

local Backend = require("arsync.backend.init")
local conf = require("arsync.conf")

local M = {}
local NOTIFY_TITLE = "arsync"
local NOTIFY_ID = "arsync"
local current_notify = nil

local backends = {
	rsync = require("arsync.backend.rsync"),
	sftp = require("arsync.backend.sftp"),
	scp = require("arsync.backend.scp"),
}

local FRAMES = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local frame_index = 0
vim.g.timer_id = nil
vim.g.notify_running = false
vim.g.arsync_disable = false
local function update_icon(msg)
	if not vim.g.notify_running then
		if vim.g.timer_id then
			vim.fn.timer_stop(vim.g.timer_id)
		end
		return
	end

	frame_index = (frame_index + 1) % #FRAMES
	local current_frame = FRAMES[frame_index + 1]

	current_notify = vim.notify(msg, "info", {
		title = NOTIFY_TITLE,
		id = NOTIFY_ID,
		replace = current_notify,
		animate = true,
		icon = current_frame,
	})
end

local function toggle(disable)
	assert(disable == nil or disable == true or disable == false, "disable must be nil, true, or false")
	vim.g.arsync_disable = disable ~= nil and disable or not vim.g.arsync_disable
end

local function start_animation(msg)
	vim.g.notify_running = true
	frame_index = 0

	if vim.g.timer_id then
		vim.fn.timer_stop(vim.g.timer_id)
	end

	vim.g.timer_id = vim.fn.timer_start(150, function()
		update_icon(msg)
	end, { ["repeat"] = -1 })
end

local function stop_animation()
	vim.g.notify_running = false
	if vim.g.timer_id then
		vim.fn.timer_stop(vim.g.timer_id)
		vim.g.timer_id = nil
	end
end

local function get_backend(conf)
	local backend_type = conf.backend or "rsync"
	local backend_impl = backends[backend_type]

	if not backend_impl then
		error("Unsupported backend: " .. backend_type)
	end

	return backend_impl
end

-- 验证配置并应用默认值
local function validate_config(conf)
	local backend_type = conf.backend or "rsync"
	local backend_impl = backends[backend_type]

	if not backend_impl then
		error("Unsupported backend: " .. backend_type)
	end

	for key, schema in pairs(Backend.CONFIG_SCHEMA.common) do
		if type(schema) == "string" then
			if conf[key] == nil then
				error("Missing required config: " .. key)
			end
		else
			if conf[key] == nil then
				conf[key] = schema.default
			end
		end
	end

	local backend_schema = Backend.CONFIG_SCHEMA[backend_type]
	if backend_schema then
		for key, schema in pairs(backend_schema) do
			if conf[key] == nil then
				conf[key] = schema.default
			end
		end
	end

	return conf
end

local function get_backend_info(config)
	local backend_type = config.backend or "rsync"
	local info = backend_type .. ":"
	if backend_type == "rsync" then
		local remote_prefix = config.remote_user and (config.remote_user .. "@" .. config.remote_host)
			or config.remote_host
		info = info .. remote_prefix
		if config.remote_port and config.remote_port ~= 0 then
			info = info .. ":" .. config.remote_port
		end
	end
	return info
end

local function cleanup()
	local config = conf.load_conf()
	if not config then
		return
	end

	local backend = get_backend(config)
	backend.cleanup()
end

local function arsync(direction, single_file)
	single_file = single_file == nil and true or single_file
	local config = conf.load_conf()
	if not config then
		vim.notify("Could not locate a .arsync configuration file", "error", {
			title = NOTIFY_TITLE,
			id = NOTIFY_ID,
			replace = current_notify,
		})
		return
	end

	if vim.g.arsync_disable then
		return
	end

	config = validate_config(config)
	local backend = get_backend(config)

	local curr_path = vim.fn.expand("%:p")
	if not curr_path:find("^" .. vim.pesc(config.local_path)) then
		return
	end
	local file_path = single_file and curr_path:sub(#config.local_path + 2) or ""
	if file_path == "" or vim.fn.isdirectory(config.local_path .. "/" .. file_path) == 1 then
		config.backend = "rsync"
		backend = get_backend(config)
	end

	local backend_info = get_backend_info(config)
	local msg_direction = direction == "down" and "Downloading" or "Uploading"
	start_animation(string.format("[%s] %s...", backend_info, msg_direction))
	local cmd = backend.transfer(direction, config, file_path)

	if type(cmd) == "table" and #cmd == 0 then
		return
	end

	if type(cmd) ~= "table" or #cmd == 0 then
		stop_animation()
		vim.notify("Invalid command returned from backend", "error", {
			title = NOTIFY_TITLE,
			id = NOTIFY_ID,
			replace = current_notify,
		})
		return
	end

	vim.g.rsync_cmd = cmd
	vim.fn.jobstart(cmd, {
		on_stdout = function(_, data)
			-- if data and #data > 1 then
			--   update_icon(string.format("[%s]\n%s", backend_info, table.concat(data, "\n")))
			-- end
		end,
		on_stderr = function(_, data)
			if data and #data > 1 then
				stop_animation()
				-- Format the error message
				local error_message = string.format("[%s]\n%s", backend_info, table.concat(data, "\n"))

				-- Populate the quickfix list with the error message
				vim.fn.setqflist({}, "a", { title = NOTIFY_TITLE, lines = vim.split(error_message, "\n") })

				-- Open the quickfix window to show the errors
				vim.cmd("copen")
			end
		end,
		on_exit = function(_, code)
			stop_animation()
			local msg_direction = direction == "down" and "Download" or "Upload"
			local msg = code == 0 and string.format("[%s] %s completed successfully", backend_info, msg_direction)
				or string.format("[%s] %s failed with code: %d", backend_info, msg_direction, code)

			current_notify = vim.notify(msg, code == 0 and "info" or "error", {
				title = NOTIFY_TITLE,
				id = NOTIFY_ID,
				replace = current_notify,
				animate = true,
			})
		end,
	})
end

M.get_global_conf_path = function()
	return conf.global_conf_file
end
M.arsync = arsync
M.cleanup = cleanup
M.arsync_up = function()
	arsync("up")
end
M.arsync_down = function()
	arsync("down")
end
M.arsync_up_delete = function()
	arsync("upDelete")
end
M.register_cmp = function(cmp)
  if cmp == "blink" then
    require('arsync.cmp.blink-cmp').register_cmp()
  elseif cmp == "nvim-cmp" then
    require('arsync.cmp.nvim-cmp').register_cmp()
  else
    vim.notify("Set arsync.opts.completion_plugin to 'nvim-cmp' or 'blink'", vim.log.levels.WARN, { title = NOTIFY_ID })
  end
end

M.create_conf_file = function(opts)
	local local_conf_path = vim.loop.cwd() .. "/.arsync"
	if not vim.loop.fs_stat(local_conf_path) then
		local conf_dict = conf.create_project_conf({
			remote_host = "unknown",
			remote_port = 0,
			auto_sync_up = 0,
			remote_path = "unknown",
			rsync_flags = { "--max-size=100m" },
			backend = "rsync",
			transmit_deltas = false,
		})
		vim.notify("Create local configuration\n", vim.log.levels.INFO, { title = NOTIFY_ID })
	end
end

M.edit_conf = function(opts)
	local local_conf_path_arsync = vim.loop.cwd() .. "/.arsync"
	local local_conf_path_vimarsync = vim.loop.cwd() .. "/.vim-arsync"

	if vim.fn.filereadable(local_conf_path_arsync) == 1 then
		vim.cmd("edit " .. local_conf_path_arsync)
	elseif vim.fn.filereadable(local_conf_path_vimarsync) == 1 then
		vim.cmd("edit " .. local_conf_path_vimarsync)
	else
		M.create_conf_file()
	end
end

M.setup = function(opts)
  opts = opts or {
    completion_plugin = "nvim-cmp"
  }
	M.register_cmp(opts.completion_plugin)
	local search_conf = require("arsync.tele").json_picker


	M.search_conf = search_conf

  vim.api.nvim_create_autocmd("BufRead", {
    pattern={".arsync", ".vim-arsync"},
    callback = function()
      vim.api.nvim_set_option_value("filetype", "arsync", { buf = vim.api.nvim_get_current_buf() })
    end,
  })

	vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
		callback = function()
			local config = conf.load_conf()
			if config then
				local auto_sync_up = config.auto_sync_up and config.auto_sync_up ~= 0
				if auto_sync_up then
					arsync("up")
				end
			end
		end,
	})

	vim.api.nvim_create_user_command("ARSyncShow", function(opts)
		local config = conf.load_conf()
		vim.notify(vim.inspect(config), vim.log.levels.INFO, { title = NOTIFY_TITLE })
	end, { desc = "Show current configuration" })

	vim.api.nvim_create_user_command("ARSyncToggle", function(opts)
		toggle()
	end, { desc = "Sync Toggle" })
	vim.api.nvim_create_user_command("ARSyncEnable", function(opts)
		toggle(false)
	end, { desc = "Sync Enable" })
	vim.api.nvim_create_user_command("ARSyncDisable", function(opts)
		toggle(true)
	end, { desc = "Sync Disable" })
	vim.api.nvim_create_user_command("ARSync", function(opts)
		arsync("up")
	end, { desc = "Sync current file to remote" })

	vim.api.nvim_create_user_command("ARSyncProj", function(opts)
		arsync("up", false)
	end, { desc = "Sync current Proj to remote" })

	vim.api.nvim_create_user_command("ARSyncDown", function(opts)
		arsync("down")
	end, { desc = "Sync current file from remote" })

	vim.api.nvim_create_user_command("ARSyncDownProj", function(opts)
		arsync("down", false)
	end, { desc = "Sync current proj from remote" })

	vim.api.nvim_create_user_command("ARSyncCleanSftp", function(opts)
    vim.notify("Clean sftp connection")
		M.cleanup()
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("ARSyncCMP", function(opts)
    vim.g.arsync_cmp_enabled = not vim.g.arsync_cmp_enabled
	end, { nargs = 0 })

	vim.api.nvim_create_user_command("ARClear", function(opts)
		local conf_file = conf.global_conf_file
		os.remove(conf_file)
		vim.notify("Delete global configuration:\n" .. conf_file, vim.log.levels.INFO, { title = NOTIFY_ID })
	end, { nargs = 0 })

	-- vim.keymap.set("n", "<leader>ar", "<cmd>ARSyncProj<CR>", { desc = "ARSyncUpProj To Remote" })
	-- vim.keymap.set("n", "<leader>aw", "<cmd>ARSync<CR>", { desc = "ARSyncUpProj To Remote" })
	-- vim.keymap.set("n", "<leader>as", "<cmd>ARSyncShow<CR>", { desc = "ARSyncShow" })
	-- vim.keymap.set("n", "<leader>ad", "<cmd>ARSyncDownProj<CR>", { desc = "ARSyncDownProj From Remote" })
	-- vim.keymap.set("n", "<leader>ac", "<cmd>ARCreate<CR>", { desc = "ARSyncUp Config Create" })
	vim.api.nvim_create_user_command("ARCreate", M.create_conf_file, { nargs = 0 })
	vim.api.nvim_create_user_command("AREdit", M.edit_conf, { nargs = 0 })
end

return M
