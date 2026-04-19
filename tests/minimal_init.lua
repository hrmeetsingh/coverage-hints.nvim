-- Shared test bootstrap. Each *_spec.lua dofiles this at its top.
-- Sets package.path so require("coverage-hints.*") resolves to the repo's lua/
-- and exposes a tiny `T` test helper (T.run, T.assert_eq, T.fixture).

local function script_dir()
  local src = debug.getinfo(2, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return vim.fn.fnamemodify(src, ":p:h")
end

local tests_dir = script_dir()
local repo_root = vim.fn.fnamemodify(tests_dir, ":h")

package.path = repo_root .. "/lua/?.lua;" .. repo_root .. "/lua/?/init.lua;" .. package.path

_G.T = {}
T.repo_root = repo_root
T.tests_dir = tests_dir

function T.fixture(rel)
  return tests_dir .. "/fixtures/" .. rel
end

local failures = 0
local total = 0

function T.run(name, fn)
  total = total + 1
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    io.stdout:write("PASS: " .. name .. "\n")
  else
    failures = failures + 1
    io.stdout:write("FAIL: " .. name .. "\n" .. tostring(err) .. "\n")
  end
end

function T.assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format("%s: expected %s, got %s", msg or "assert_eq",
      vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

function T.assert_true(cond, msg)
  if not cond then error(msg or "expected true", 2) end
end

function T.finish()
  io.stdout:write(string.format("--- %d run, %d failed ---\n", total, failures))
  if failures > 0 then os.exit(1) end
  os.exit(0)
end

return T
