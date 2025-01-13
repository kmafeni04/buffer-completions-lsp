local find_pos = require("utils.find_pos")
local logger = require("utils.logger")

---@param request_params table
---@param current_file_content string
---@param documents table<string, string>
return function(request_params, current_file_content, documents)
  local current_line = request_params.position.line
  local current_char = request_params.position.character

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
      local prefix_lower = prefix:lower()
      if item.label:sub(1, #prefix):lower() == prefix_lower and prefix_lower ~= item.label:lower() then
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
  return items
end
