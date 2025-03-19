local did_change = require("methods.did_change")
local completion = require("methods.completion")
local methods = {}

---@param request_params table
---@param current_file_content string
function methods.did_change(request_params, current_file_content)
  return did_change(request_params, current_file_content)
end

---@param request_params table
---@param current_file_content string
---@param documents table<string, string>
function methods.completion(request_params, current_file_content, documents)
  return completion(request_params, current_file_content, documents)
end

return methods
