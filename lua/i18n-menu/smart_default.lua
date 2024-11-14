local M = {}

function M.smart_default(text)
  local last_segment = string.match(text, "[^.]+$")
  return last_segment:gsub("(%u)", " %1"):gsub("^ ", "")
end

local function assert_equal(actual, expected)
  if actual == expected then
    print(string.format("\27[32m%s == %s\27[0m", actual, expected))
  else
    print(string.format("\27[31m%s != %s\27[0m", actual, expected))
    error("Assertion failed.")
  end
end

if debug.getinfo(3) == nil then
  print("Running smart_default tests...")
  assert_equal(M.smart_default("matchBonuses.Select"), "Select")
  assert_equal(M.smart_default("matchBonuses.SelectAll"), "Select All")
  print("All good.")
else
  return M
end
