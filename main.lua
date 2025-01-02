do
  local current_file_path = debug.getinfo(1, "S").source:sub(2)
  local current_dir = current_file_path:match("(.*/)")

  -- Add the current directory to the Lua package path
  if current_dir then
    package.path = package.path .. ";" .. current_dir .. "?.lua"
  end
end

local rpc = require("utils.rpc")
local logger = require("utils.logger")
local server = require("utils.server")
local find_pos = require("utils.find_pos")

---@type table<string, string>
local documents = {}
local current_uri = ""
local current_file_content = ""
local current_file_path = ""
---@type string
local root_path = io.popen("git rev-parse --show-toplevel 2>&1"):read("l")

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
      local root_path_not_found =
        root_path:match("fatal: not a git repository %(or any of the parent directories%): %.git")

      if root_path_not_found then
        root_path = current_uri:sub(#"file:///"):gsub("/[^/]+%.nelua", "")
      end

      current_file_content = request.params.textDocument.text
      documents[current_uri] = current_file_content
    elseif request.method == "textDocument/didChange" then
      ---@type string[]
      local lines = {}
      for line in string.gmatch(current_file_content .. "\n", "([^\n]-)\n") do
        table.insert(lines, line)
      end

      for _, change in ipairs(request.params.contentChanges) do
        local start_line = change.range.start.line + 1
        local start_char = change.range.start.character + 1
        local end_line = change.range["end"].line + 1
        local end_char = change.range["end"].character + 1
        local text = change.text

        if lines[start_line] and start_line == end_line then
          lines[start_line] =
            table.concat({ lines[start_line]:sub(1, start_char - 1), text, lines[start_line]:sub(end_char) })
        else
          ---@type string[]
          local change_lines = {}
          for change_line in string.gmatch(text .. "\n", "([^\n]-)\n") do
            table.insert(change_lines, change_line)
          end

          local ci = 1
          local offset = 0
          for i = start_line, end_line do
            local current_line = i + offset
            if ci <= #change_lines then
              if change_lines[ci] then
                if current_line == start_line then
                  lines[current_line] = table.concat({ lines[current_line]:sub(1, start_char - 1), change_lines[ci] })
                else
                  table.insert(lines, current_line, change_lines[ci])
                  offset = offset + 1
                end
              end
            elseif lines[current_line - 1] then
              table.remove(lines, current_line - 1)
              offset = offset - 1
            elseif ci == #lines then
              table.remove(lines, ci)
              offset = offset - 1
            end
            ci = ci + 1
          end
        end
      end

      current_file_content = table.concat(lines, "\n")
      documents[current_uri] = current_file_content
      logger.log(current_file_content)
    elseif request.method == "textDocument/completion" then
      local current_line = request.params.position.line
      local current_char = request.params.position.character

      ---@class CompItem
      ---@field label string
      ---@field kind CompItemKind
      ---@field documentation string
      ---@field insertTextFormat integer

      ---@class Position
      ---@field line integer
      ---@field character integer

      ---@class Range
      ---@field start Position
      ---@field end Position

      ---@class Loc
      ---@field uri string
      ---@field range Range

      ---@param items CompItem[]
      ---@param prefix string
      ---@return CompItem[]
      local function get_prefixed_completions(items, prefix)
        table.sort(items, function(a, b)
          local a_has_prefix = a.label:sub(1, #prefix):lower() == prefix:lower()
          local b_has_prefix = b.label:sub(1, #prefix):lower() == prefix:lower()
          if a_has_prefix and b_has_prefix then
            return a.label < b.label
          end

          return a_has_prefix
        end)

        local prefixed_items = {}

        for i, item in ipairs(items) do
          if i > 10 then
            break
          end
          if item.label:sub(1, #prefix):lower() == prefix:lower() then
            table.insert(prefixed_items, item)
          end
        end

        return prefixed_items
      end

      ---@enum CompItemKind
      local comp_item_kind = {
        Text = 1,
        Method = 2,
        Function = 3,
        Constructor = 4,
        Field = 5,
        Variable = 6,
        Class = 7,
        Interface = 8,
        Module = 9,
        Property = 10,
        Unit = 11,
        Value = 12,
        Enum = 13,
        Keyword = 14,
        Snippet = 15,
        Color = 16,
        File = 17,
        Reference = 18,
        Folder = 19,
        EnumMember = 20,
        Constant = 21,
        Struct = 22,
        Event = 23,
        Operator = 24,
        TypeParameter = 25,
      }

      ---@enum InsertTextFormat
      local insert_text_format = {
        PlainText = 1,
        Snippet = 2,
      }

      ---@param label string
      ---@param kind CompItemKind
      ---@param doc string
      ---@param inser_text string
      ---@param fmt InsertTextFormat
      ---@param comp_list CompItem[]
      local function gen_completion(label, kind, doc, inser_text, fmt, comp_list)
        ---@type CompItem
        local comp = {
          label = label,
          kind = kind,
          documentation = doc,
          insertText = inser_text,
          insertTextFormat = fmt,
        }
        table.insert(comp_list, comp)
      end

      local function gen_text_completions()
        local text_items = {}
        local mark = {}
        for _, doc in pairs(documents) do
          for word in doc:gmatch("[%w_]+") do
            if not mark[word] and not word:sub(1, 1):match("%d") then
              mark[word] = true
              gen_completion(word, comp_item_kind.Text, "", word, insert_text_format.PlainText, text_items)
            end
          end
        end
        return text_items
      end
      local function get_current_prefix()
        local current_prefix = ""
        local prefix_pos = find_pos(current_file_content, current_line, current_char) - 1
        while true do
          local c = current_file_content:sub(prefix_pos, prefix_pos)
          if not c:match("[%w_]") then
            break
          end
          prefix_pos = prefix_pos - 1
          current_prefix = c .. current_prefix
        end
        return current_prefix
      end

      local text_items = gen_text_completions()

      local items = get_prefixed_completions(text_items, get_current_prefix())

      logger.log(#items)

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
