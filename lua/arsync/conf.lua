-- 文件: lua/conf.lua
local M = {}

M.global_conf_file = vim.fn.stdpath "data" .. "/arsync/global_conf.json"
M.replace_key = { "remote_host", "remote_port", "remote_path", "local_path" }
M.init_key = { "remote_host", "remote_port", "remote_path", "local_path", "rsync_flags", "auto_sync_up" }

-- 读取 JSON 配置文件
local function read_conf_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    return {}
  end
  local content = file:read "*a"
  file:close()
  return vim.json.decode(content) or {}
end

-- 解析 .arsync 配置文件
local function parse_arsync_config(content)
  local config = {}
  for line in content:gmatch("[^\r\n]+") do
    local key, value = line:match("^(%S+)%s+(.+)$")
    if key and value then
      -- 特殊处理 rsync_flags
      if key == "rsync_flags" then
        -- 解析类似 ["--max-size=100m"] 的格式
        local flags = vim.json.decode(value)
        config[key] = flags
      -- 特殊处理数字类型的值
      elseif key == "remote_port" or key == "auto_sync_up" then
        config[key] = tonumber(value)
      else
        config[key] = value
      end
    end
  end
  return config
end

-- 加载 .arsync 配置
function M.load_conf()
  local local_conf_path_arsync = vim.loop.cwd() .. "/.arsync"
  local local_conf_path_vimarsync = vim.loop.cwd() .. "/.vim-arsync"
  local file = io.open(local_conf_path_arsync, "r") or io.open(local_conf_path_vimarsync, "r")
  if not file then
    return nil
  end
  
  local content = file:read "*a"
  file:close()
  
  return parse_arsync_config(content)
end

-- 创建配置文件
function M.create_project_conf(conf_dict)
  local local_path = conf_dict["local_path"] or vim.loop.cwd()
  local project_conf_path = local_path .. "/.arsync"
  
  -- 准备配置内容
  local lines = {
    string.format("auto_sync_up %d", conf_dict.auto_sync_up or 0),
    string.format("local_options %s", conf_dict.local_options or "-var"),
    string.format("local_path %s", local_path),
    string.format("remote_host %s", conf_dict.remote_host or "unknown"),
    string.format("remote_options %s", conf_dict.remote_options or "-var"),
    string.format("remote_or_local %s", conf_dict.remote_or_local or "remote"),
    string.format("remote_path %s", conf_dict.remote_path or "unknown"),
    string.format("remote_port %d", conf_dict.remote_port or 0),
    string.format('rsync_flags %s', vim.json.encode(conf_dict.rsync_flags or {"--max-size=100m"}))
  }
  
  -- 写入配置文件
  local file = io.open(project_conf_path, "w")
  if not file then
    error("Cannot write to file: " .. project_conf_path)
  end
  file:write(table.concat(lines, "\n"))
  file:close()
  
  -- 更新全局配置
  local global_conf = read_conf_file(M.global_conf_file)
  table.insert(global_conf, parse_arsync_config(table.concat(lines, "\n")))
  
  local global_file = io.open(M.global_conf_file, "w")
  if global_file then
    global_file:write(vim.json.encode(global_conf))
    global_file:close()
  end
  
  return conf_dict
end

-- 更新项目配置
function M.update_project_conf(conf_dict)
  local local_path = conf_dict["local_path"] or vim.loop.cwd()
  local project_conf_path = local_path .. "/.arsync"
  local current_conf = M.load_conf() or {}
  
  -- 更新配置
  for _, k in ipairs(M.replace_key) do
    if conf_dict[k] ~= nil then
      current_conf[k] = conf_dict[k]
    end
  end
  
  write_conf_file(project_conf_path, current_conf)
  return current_conf
end

-- 删除项目配置
function M.delete_project_conf(conf_dict)
  local local_path = conf_dict["local_path"] or vim.loop.cwd()
  local project_conf_path = local_path .. "/.arsync"
  
  -- 删除本地配置文件
  os.remove(project_conf_path)
  
  -- 从全局配置中删除
  local global_conf = read_conf_file(M.global_conf_file)
  for i, entry in ipairs(global_conf) do
    if entry.local_path == local_path then
      table.remove(global_conf, i)
      write_conf_file(M.global_conf_file, global_conf)
      break
    end
  end
end

-- 添加这个函数定义
local function write_conf_file(file_path, data)
  local file = io.open(file_path, "w")
  if not file then
    error("Cannot write to file: " .. file_path)
  end
  file:write(vim.json.encode(data))
  file:close()
end

return M
