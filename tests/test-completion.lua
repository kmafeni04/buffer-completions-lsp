local lester = require("libs.lester")
local describe, it, expect = lester.describe, lester.it, lester.expect
local completion = require("methods.completion")

---@param comp_items CompItem[]
---@param expected string
---@return boolean
local function has_label(comp_items, expected)
  assert(type(comp_items) == "table")
  assert(type(expected) == "string")

  for _, v in ipairs(comp_items) do
    if v.label == expected then
      return true
    end
  end
  return false
end

describe("Completion tests", function()
  it("completions", function()
    local content1 = "hello world"
    local content2 = "bye planet"
    local request_params = {
      position = {
        line = 0,
        character = 0,
      },
    }
    local documents = {
      [1] = content1,
      [2] = content2,
    }
    local completions = completion(request_params, content1, documents)
    expect.truthy(next(completions))
    expect.truthy(has_label(completions, "hello"))
    expect.truthy(has_label(completions, "world"))
    expect.truthy(has_label(completions, "bye"))
    expect.truthy(has_label(completions, "planet"))
  end)
end)

lester.report()
lester.exit()
