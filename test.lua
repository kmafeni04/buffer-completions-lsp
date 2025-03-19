local did_change = require("methods.did_change")

do
  local content = "local x = 10"
  local request_params = {
    contentChanges = {
      [1] = {
        range = {
          start = {
            line = 0,
            character = #content - 2,
          },
          ["end"] = {
            line = 0,
            character = #content,
          },
        },
        text = "12",
      },
    },
  }
  local new_content = did_change(request_params, content)
  local expected = "local x = 12"
  assert(new_content == expected)
end

do
  local line1 = "local x = 10"
  local line2 = "local y = 12"
  local content = line1 .. "\n" .. line2
  local request_params = {
    contentChanges = {
      [1] = {
        range = {
          start = {
            line = 0,
            character = #line1 - 2,
          },
          ["end"] = {
            line = 0,
            character = #line1,
          },
        },
        text = "12",
      },
      [2] = {
        range = {
          start = {
            line = 1,
            character = #line2 - 2,
          },
          ["end"] = {
            line = 1,
            character = #line2,
          },
        },
        text = "12",
      },
    },
  }
  local new_content = did_change(request_params, content)
  local expected = [[
local x = 12
local y = 12]]
  assert(new_content == expected)
end

do
  local line1 = "local x = 10"
  local line2 = "local y = 12"
  local line3 = "local z = 14"
  local content = line1 .. "\n" .. line2 .. "\n" .. line3
  local request_params = {
    contentChanges = {
      [1] = {
        range = {
          start = {
            line = 0,
            character = #line1 - 5,
          },
          ["end"] = {
            line = 1,
            character = 0,
          },
        },
        text = "",
      },
      [2] = {
        range = {
          start = {
            line = 0,
            character = #line1 - 5,
          },
          ["end"] = {
            line = 0,
            character = #line1 - 5 + #line2,
          },
        },
        text = "",
      },
    },
  }
  local new_content = did_change(request_params, content)
  local expected = "local x\nlocal z = 14"
  assert(new_content == expected)
end

do
  local line1 = "local x = 10"
  local line2 = "local y = 12"
  local line3 = "local z = 14"
  local content = line1 .. "\n" .. line2 .. "\n" .. line3
  local request_params = {
    contentChanges = {
      [1] = {
        range = {
          start = {
            line = 0,
            character = #line1 - 5,
          },
          ["end"] = {
            line = 2,
            character = #line3,
          },
        },
        text = "",
      },
    },
  }
  local new_content = did_change(request_params, content)
  local expected = "local x"
  assert(new_content == expected)
end
