local M = {}

-- 配置项定义
M.CONFIG_SCHEMA = {
  -- 通用配置项
  common = {
    -- 必需配置
    remote_host = "string",      -- 远程主机地址
    remote_path = "string",      -- 远程路径
    
    -- 可选配置（带默认值）
    backend = { type = "string", default = "rsync" },  -- 后端类型
    remote_user = { type = "string", default = nil },  -- 远程用户名
    remote_port = { type = "number", default = 0 },    -- 远程端口
    local_path = { type = "string", default = vim.loop.cwd() }, -- 本地路径
    auto_sync_up = { type = "number", default = 0 },   -- 是否自动同步
  },
  
  -- rsync 特有配置项
  rsync = {
    -- 可选配置（带默认值）
    remote_or_local = { type = "string", default = "remote" },  -- 传输模式
    local_options = { type = "string", default = "-var" },      -- rsync 本地选项
    remote_options = { type = "string", default = "-varz" },   -- rsync 远程选项
    rsync_flags = { type = "table", default = {"--max-size=100m"} }, -- rsync 额外标志
  },
  
  -- sftp 特有配置项
  sftp = {
    timeout = { type = "number", default = 10 }  -- 连接超时时间
  }
}

-- 后端接口规范
M.Backend = {
  -- 初始化后端
  init = function(conf) end,
  -- 传输文件
  transfer = function(direction, conf, rel_filepath) end,
  -- 清理资源
  cleanup = function() end,
  -- 获取所需配置项
  get_required_config = function() end,
  toggle = function(disable) end
}

return M
