local M = {}

function M.dig(table, path)
  if not table or type(table) ~= "table" then
    return table
  end

  local head, tail = string.match(path, "([^.]*)%.?(.*)")

  return M.dig(table[head], tail)
end

function M.place(table, path, value)
  local head, tail = string.match(path, "([^.]*)%.?(.*)")

  if tail == "" then
    table[head] = value
    return
  end

  if not table[head] then
    table[head] = {}
  end

  if type(table[head]) ~= "table" then
    error("Attempt to overwrite existing string with an object")
  end

  return M.place(table[head], tail, value)
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
  print("Running dig tests...")
  assert(M.dig(translations, "login") == "Login")
  assert(M.dig(translations, "store.addToCart") == "Add to Cart")
  assert(M.dig(translations, "faq.0.question") == "How can I pay?")
  assert(M.dig(translations, "store.orders") == nil)
  print("Running place tests...")
  M.place(translations, "login", "Sign In")
  assert(M.dig(translations, "login") == "Sign In")
  M.place(translations, "store.checkout", "Checkout Now")
  assert(M.dig(translations, "store.checkout") == "Checkout Now")
  M.place(translations, "guide.greeting", "Hello")
  assert(M.dig(translations, "guide.greeting") == "Hello")
  print("All good.")
else
  return M
end
