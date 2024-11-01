local M = {}

function M.dig(table, path)
  if not table or type(table) == "string" then
    return table
  end

  local head, tail = string.match(path, "([^.]*)%.?(.*)")

  return M.dig(table[head], tail)
end

local translations = {
  login = "Login",
  store = {
    addToCart = "Add to Cart",
    checkout = "Checkout"
  },
  faq = {
    ["0"] = {
      question = "How can I pay?",
      answer = "Only gold coins are accepted."
    }
  }
}

if debug.getinfo(3) == nil then
  print("Running tests...")
  assert(M.dig(translations, "login") == "Login")
  assert(M.dig(translations, "store.addToCart") == "Add to Cart")
  assert(M.dig(translations, "faq.0.question") == "How can I pay?")
  assert(M.dig(translations, "store.orders") == nil)
  print("All good.")
else
  return M
end
