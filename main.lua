do
  local current_file_path = debug.getinfo(1, "S").source:sub(2)
  local current_dir = current_file_path:match("(.*/)")

  -- Add the current directory to the Lua package path
  if current_dir then
    package.path = package.path .. ";" .. current_dir .. "?.lua"
    package.path = package.path .. ";" .. current_dir .. "?/init.lua"
  end
end

local rpc = require("utils.rpc")
local logger = require("utils.logger")
local server = require("utils.server")

local methods = require("methods")

---@type table<string, string>
local documents = {}
local current_uri = ""
local current_file_content = ""
local current_file_path = ""
---@type string

logger.init()

while true do
  local header = io.read("L")
  local content_length = tonumber(header:match("(%d+)\r\n"))
  _ = io.read("L")
  ---@type string
  local content = io.read(content_length)
  local request, err = rpc.decode(content)
  if request then
    if request.params and request.params.textDocument then
      current_uri = request.params.textDocument.uri
      current_file_path = current_uri:sub(#"file://" + 1)
    end
    logger.log(request.method)
    if request.method == "initialize" then
      local intilaize_result = {
        capabilities = {
          textDocumentSync = 2,
          completionProvider = { resolveProvider = false },
        },
      }
      local sent = server.send_response(request.id, intilaize_result)
      if not sent then
        server.send_error(request.id, server.LspErrorCode.ServerNotInitialized, "Failed to initialize server")
      end
    elseif request.method == "textDocument/didOpen" then
      current_file_content = request.params.textDocument.text
      documents[current_uri] = current_file_content
    elseif request.method == "textDocument/didChange" then
      current_file_content = methods.did_change(request.params, current_file_content)
      documents[current_uri] = current_file_content
    elseif request.method == "textDocument/completion" then
      local items = methods.completion(request.params, current_file_content, documents)
      if next(items) then
        server.send_response(request.id, items)
      else
        server.send_error(request.id, server.LspErrorCode.RequestFailed, "Failed to provide any completions")
      end
    elseif request.method == "textDocument/didSave" then
      local current_file_prog <close> = io.open(current_file_path)
      if current_file_prog then
        current_file_content = current_file_prog:read("a")
        documents[current_uri] = current_file_content
      end
    elseif request.method == "textDocument/didClose" then
      documents[current_uri] = nil
    elseif request.method == "shutdown" then
      server.send_response(nil, {})
    elseif request.method == "exit" then
      os.exit()
    end
  end
end
