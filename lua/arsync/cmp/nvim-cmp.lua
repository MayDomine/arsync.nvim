M = {}
M.register_cmp = function()
	local ori_cmp = pcall(require, "cmp") and require("cmp") or nil
	if ori_cmp == nil then
		return
	end
	ori_cmp.register_source("arsync", {
		complete = function(self, params, callback)
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
							detail = path,
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

			callback({ items = items, isIncomplete = false })
		end,
	})
end
return M
