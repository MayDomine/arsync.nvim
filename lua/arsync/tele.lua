local telescope = require "telescope.builtin"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"
local previewers = require "telescope.previewers"
local entry_display = require "telescope.pickers.entry_display"
local conf_manager = require "arsync.conf"

local M = {}
local function read_json_file(file_path)
  local file = io.open(file_path, "r")
  if not file then
    print("Failed to open file: " .. file_path)
    return {}
  end
  local content = file:read "*all"
  file:close()
  return vim.fn.json_decode(content)
end

local function create_picker(json_data)
  local finder = finders.new_table {
    results = json_data,
    entry_maker = function(entry)
      local value = entry
      vim.g.test = value
      local url = conf_manager.get_url(entry)
      return {
        value = value,
        display = url,
        ordinal = url,
      }
    end,
  }
  pickers
    .new({}, {
      prompt_title = "Rsync Host Config Choose",
      finder = finder,
      sorter = sorters.get_generic_fuzzy_sorter(),
      previewer = previewers.new_buffer_previewer {
        define_preview = function(self, entry, status)
          local hash8 = string.sub(entry.value['hash'], 1, 8)
          local entry_str = vim.fn.json_encode(entry.value)
          entry_str = string.gsub(entry_str, entry.value['hash'], hash8)
          local lines = vim.split(entry_str, ",")
          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          if selection then
            vim.notify("Selected: " .. selection.key .. " = " .. vim.inspect(selection.value))
          else
            vim.notify "No selection made"
          end
        end)

        map({"i", "n"}, "<CR>", function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          actions.close(prompt_bufnr)
          if selection then
            conf_manager.update_project_conf(selection.value)
            vim.notify("Apply conf: " .. selection.display, vim.log.levels.INFO, { title = "arsync" })
          else
            print "No selection made"
          end
        end)
        map({"i", "n"}, "<c-x>", function()
          local selection = action_state.get_selected_entry(prompt_bufnr)
          conf_manager.delete_project_conf(selection.value)
          if selection then
            local current_picker = action_state.get_current_picker(prompt_bufnr)
            current_picker:delete_selection(function(sele)
            vim.notify("Delete conf: " .. selection.display, vim.log.levels.INFO, { title = "arsync" })
            end)
          else
            print "No selection made"
          end
        end)

        return true
      end,
    })
    :find()
end

local function json_picker()
  local conf_file = vim.fn.stdpath "data" .. "/arsync/global_conf.json"
  local local_path = vim.loop.cwd()
  local json_data = read_json_file(conf_file)
  local remote_data = {}
  for _, v in pairs(json_data) do
    if v["local_path"]:gsub("/$", "") == local_path then
      table.insert(remote_data, v)
    end
  end
  if json_data then
    create_picker(remote_data)
  else
    print "Failed to read JSON data"
  end
end

M.json_picker = json_picker
return M
