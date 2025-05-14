---@module 'blink.cmp'

---@class render.md.blink.Source: blink.cmp.Source
local Source = {}
Source.__index = Source

---@return blink.cmp.Source
function Source.new()
	return setmetatable({}, Source)
end

---@return boolean
function Source:enabled()
	return vim.g.arsync_blink_cmp_enabled
end

---@return string[]

---@param context blink.cmp.Context
---@param callback fun(response?: blink.cmp.CompletionResponse)
function Source:get_completions(context, callback)
	local items = {}
	-- 读取 JSON 文件
	local json_file_path = require("arsync").get_global_conf_path()
	local file = io.open(json_file_path, "r")
	if not file then
		callback({ items = items, isIncomplete = false })
		return
	end

	local content = file:read("*all")
	file:close()

	-- 解析 JSON 数据
	local success, json_data = pcall(vim.fn.json_decode, content)
	if not success or type(json_data) ~= "table" then
		callback({ items = items, isIncomplete = false })
		return
	end

	-- 处理每个 JSON 项
	local comp_item = {}
	for _, item in ipairs(json_data) do
		local function add_path_item(items, path, description, tag)
			if path and not vim.tbl_contains(comp_item, path .. tag) then
				table.insert(items, {
					label = path .. " [" .. tag .. "]",
					documentation = {
						kind = "markdown",
						value = string.format("**%s from Arsync**: %s\n\n", description, path),
					},
					insertText = path,
				})
				table.insert(comp_item, path .. tag)
			end
		end
		add_path_item(items, item.remote_host, "Host", item.remote_host .. ":host")
		add_path_item(items, item.local_path, "Local Path", item.remote_host .. ":local")
		add_path_item(items, item.remote_path, "Remote Path", item.remote_host .. ":remote")
	end

	callback({ items = items, is_incomplete_backward = false, is_incomplete_forward = false })
end

---@class render.md.integ.Blink
local M = {}

---@private
---@type boolean
M.initialized = false

---called from manager on buffer attach
function Source.setup()
	if M.initialized then
		return
	end
	M.initialized = true
	local has_blink, blink = pcall(require, "blink.cmp")
	if not has_blink or not blink then
		return
	end
	local id = "arsync"
	blink.add_source_provider(id, {
		name = "Arsync",
		module = "arsync.cmp.blink-cmp",
	})
end

Source.register_cmp = Source.setup
return Source
