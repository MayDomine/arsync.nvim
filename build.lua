local python = vim.fn.exepath("python3") ~= "" and "python3" or vim.fn.exepath("python") ~= "" and "python" or nil

if not python then
  vim.notify("arsync: python3 not found, sftp backend will not work", vim.log.levels.WARN)
  return
end

local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local requirements = plugin_dir .. "requirements.txt"

local obj = vim.system({ python, "-m", "pip", "install", "-r", requirements }, { text = true }):wait()

if obj.code == 0 then
  vim.notify("arsync: python dependencies installed successfully", vim.log.levels.INFO)
else
  vim.notify("arsync: failed to install python dependencies:\n" .. (obj.stderr or ""), vim.log.levels.ERROR)
end

vim.cmd("UpdateRemotePlugins")
