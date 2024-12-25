-- Lua plugin to handle async rsync synchronization between hosts
-- Title: vimarsync
-- Author: Ken Hasselmann (converted to Lua)
-- License: MIT

local Backend = require("arsync.backend.init")
local notify = require("notify")
local conf = require("arsync.conf")

local M = {}
local NOTIFY_TITLE = "arsync"  -- 通知标题
local NOTIFY_ID = "arsync"     -- 通知ID，用于替换
local current_notify = nil         -- 当前通知的引用ID

-- 加载后端
local backends = {
  rsync = require("arsync.backend.rsync"),
  sftp = require("arsync.backend.sftp")
}

local FRAMES = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
local frame_index = 0
vim.g.timer_id = nil
vim.g.notify_running = false

-- 更新图标的函数
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
    icon = current_frame
  })
end

-- 开始动画
local function start_animation(msg)
  vim.g.notify_running = true
  frame_index = 0
  
  -- 停止现有的定时器（如果有）
  if vim.g.timer_id then
    vim.fn.timer_stop(vim.g.timer_id)
  end
  
  -- 创建新的定时器，每150ms更新一次
  vim.g.timer_id = vim.fn.timer_start(150, function()
    update_icon(msg)
  end, { ['repeat'] = -1 })
end

-- 停止动画
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

  -- 验证通用配置并应用默认值
  for key, schema in pairs(Backend.CONFIG_SCHEMA.common) do
    if type(schema) == "string" then
      -- 必需配置项
      if conf[key] == nil then
        error("Missing required config: " .. key)
      end
    else
      -- 可选配置项（带默认值）
      if conf[key] == nil then
        conf[key] = schema.default
      end
    end
  end

  -- 验证后端特定配置并应用默认值
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

-- 获取后端信息的辅助函数
local function get_backend_info(config)
  local backend_type = config.backend or "rsync"
  local info = backend_type .. ": "
  if backend_type == "rsync" then
    local remote_prefix = config.remote_user and 
      (config.remote_user .. "@" .. config.remote_host) or 
      config.remote_host
    info = info .. remote_prefix
    if config.remote_port and config.remote_port ~= 0 then
      info = info .. ":" .. config.remote_port
    end
  end
  return info
end

-- 实现 arsync 函数
local function arsync(direction, single_file)
  single_file = single_file == nil and true or single_file
  local config = conf.load_conf()
  if not config then
    vim.notify("Could not locate a .arsync configuration file", "error", {
      title = NOTIFY_TITLE,
      id = NOTIFY_ID,
      replace = current_notify
    })
    return
  end

  local backend_info = get_backend_info(config)
  start_animation(string.format("[%s] Transferring...", backend_info))

  -- 验证配置
  config = validate_config(config)
  local backend = get_backend(config)

  -- 获取传输命令
  local file_path = single_file and vim.fn.expand('%:p'):sub(#config.local_path + 2) or ""
  local cmd = backend.transfer(direction, config, file_path)
  
  -- 如果后端返回空表（sftp），说明传输已经在后台进行
  if type(cmd) == "table" and #cmd == 0 then
    -- 停止动画，因为 sftp 后端会处理自己的通知
    return
  end

  -- 确保 cmd 是有效的命令数组
  if type(cmd) ~= "table" or #cmd == 0 then
    stop_animation()
    vim.notify("Invalid command returned from backend", "error", {
      title = NOTIFY_TITLE,
      id = NOTIFY_ID,
      replace = current_notify
    })
    return
  end

  -- 使用 jobstart 执行命令（用于 rsync）
  vim.g.rsync_cmd = cmd
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      if data and #data > 1 then
        update_icon(string.format("[%s]\n%s", backend_info, table.concat(data, "\n")))
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 1 then
        stop_animation()
        -- Format the error message
        local error_message = string.format("[%s]\n%s", backend_info, table.concat(data, "\n"))
        
        -- Populate the quickfix list with the error message
        vim.fn.setqflist({}, 'a', { title = NOTIFY_TITLE, lines = vim.split(error_message, "\n") })
        
        -- Open the quickfix window to show the errors
        vim.cmd("copen")
      end
    end,
    on_exit = function(_, code)
      stop_animation()
      local msg = code == 0 and 
        string.format("[%s] Transfer completed successfully", backend_info) or
        string.format("[%s] Transfer failed with code: %d", backend_info, code)
      
      current_notify = vim.notify(msg, code == 0 and "info" or "error", {
        title = NOTIFY_TITLE,
        id = NOTIFY_ID,
        replace = current_notify,
        animate = true
      })
    end
  })
end

-- 导出 arsync 相关函数
M.arsync = arsync
M.arsync_up = function() arsync('up') end
M.arsync_down = function() arsync('down') end
M.arsync_up_delete = function() arsync('upDelete') end

M.setup = function()
  local search_conf = require("arsync.tele").json_picker
  
  -- 设置快捷键
  vim.api.nvim_set_keymap(
    "n",
    "<leader>jp",
    '<cmd>lua require("arsync").search_conf()<CR>',
    { noremap = true, silent = true }
  )
  
  M.search_conf = search_conf

  -- 设置自动命令
  vim.api.nvim_create_autocmd({ "BufWritePost", "FileWritePost" }, {
    callback = function()
      local config = conf.load_conf()
      local auto_sync_up = config.auto_sync_up ~= nil and config.auto_sync_up ~= 0
      if config and auto_sync_up then
        arsync('up')
      end
    end,
  })
  
  vim.api.nvim_create_user_command("ARSyncShow", function(opts)
    local config = conf.load_conf()
    vim.notify(vim.inspect(config), vim.log.levels.INFO, { title = NOTIFY_TITLE })
  end, { desc = "Show current configuration" })

  -- 创建用户命令
  vim.api.nvim_create_user_command("ARSync", function(opts)
    arsync('up')
  end, { desc = "Sync current file to remote" })

  vim.api.nvim_create_user_command("ARSyncProj", function(opts)
    arsync('up', false)
  end, { desc = "Sync current file to remote" })

  vim.api.nvim_create_user_command("ARSyncDown", function(opts)
    arsync('down')
  end, { desc = "Sync current file from remote" })

  vim.api.nvim_create_user_command("ARSyncDownProj", function(opts)
    arsync('down', false)
  end, { desc = "Sync current file from remote" })

  vim.api.nvim_create_user_command("ARSyncDelete", function(opts)
    arsync('upDelete')
  end, { desc = "Sync and delete current file" })

  vim.api.nvim_create_user_command("ARClear", function(opts)
    local conf_file = vim.fn.stdpath "data" .. "/arsync/global_conf.json"
    os.remove(conf_file)
    vim.notify("Delete global configuration:\n" .. conf_file, vim.log.levels.INFO, { title = NOTIFY_ID })
  end, { nargs = 0 })

  vim.keymap.set("n", "<leader>ar", "<cmd>ARSyncUpProj<CR>", { desc = "ARSyncUpProj To Remote" })
  vim.keymap.set("n", "<leader>as", "<cmd>ARSyncShow<CR>", { desc = "ARSyncShow" })
  vim.keymap.set("n", "<leader>ad", "<cmd>ARSyncDownProj<CR>", { desc = "ARSyncDownProj From Remote" })
  vim.keymap.set("n", "<leader>ac", "<cmd>ARCreate<CR>", { desc = "ARSyncUp Config Create" })
  vim.api.nvim_create_user_command("ARCreate", function(opts)
    local local_conf_path = vim.loop.cwd() .. "/.arsync"
    if not vim.loop.fs_stat(local_conf_path) then
      local conf_dict = conf.create_project_conf({
        remote_host = "unknown",
        remote_port = 0,
        auto_sync_up = 0,
        remote_path = "unknown",
        rsync_flags = {"--max-size=100m"},
        backend = "rsync",
        transmit_deltas = false
      })
      vim.notify(
        "Create local configuration\n",
        vim.log.levels.INFO,
        { title = NOTIFY_ID }
      )
    end
  end, { nargs = 0 })
end

return M
