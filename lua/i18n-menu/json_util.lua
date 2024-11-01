local M = {}

function M.keys_order(filepath)
  local ans = {}

  for line in io.lines(filepath) do
    local indent, key = string.match(line, '( +)"([^"]+)"')
    if type(indent) == "string" then
      local level = math.floor(string.len(indent) / 2)
      if ans[level] then
        table.insert(ans[level], key)
      else
        ans[level] = { key }
      end
    end
  end

  return ans
end

if debug.getinfo(3) == nil then
  print("Running keys_order tests...")
  local order = M.keys_order("example.json")
  assert(order[1][1] == "login")
  assert(order[1][2] == "store")
  print("All good.")
else
  return M
end
