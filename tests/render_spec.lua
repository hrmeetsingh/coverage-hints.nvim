dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/minimal_init.lua")

local render = require("coverage-hints.render")

local function make_buf(line_count)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {}
  for i = 1, line_count do lines[i] = "line " .. i end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

T.run("apply: places one sign per uncovered line + one virt_text per range", function()
  local buf = make_buf(30)
  local lines_set = { [5] = true, [6] = true, [7] = true, [15] = true }
  render.apply(buf, lines_set, "add case in foo_test.go")

  local marks = vim.api.nvim_buf_get_extmarks(buf, render.namespace, 0, -1, { details = true })
  local sign_count, virt_count = 0, 0
  local virt_lines = {}
  for _, m in ipairs(marks) do
    local d = m[4] or {}
    if d.sign_text then sign_count = sign_count + 1 end
    if d.virt_text then
      virt_count = virt_count + 1
      table.insert(virt_lines, m[2] + 1)
    end
  end
  T.assert_eq(sign_count, 4, "expected 4 sign extmarks")
  T.assert_eq(virt_count, 2, "expected 2 virt_text extmarks")
  table.sort(virt_lines)
  T.assert_eq(virt_lines[1], 5, "first virt_text on line 5")
  T.assert_eq(virt_lines[2], 15, "second virt_text on line 15")

  vim.api.nvim_buf_delete(buf, { force = true })
end)

T.run("clear: removes all marks in the namespace", function()
  local buf = make_buf(10)
  render.apply(buf, { [3] = true, [4] = true }, "hint")
  local before = vim.api.nvim_buf_get_extmarks(buf, render.namespace, 0, -1, {})
  T.assert_true(#before > 0, "expected marks before clear")
  render.clear(buf)
  local after = vim.api.nvim_buf_get_extmarks(buf, render.namespace, 0, -1, {})
  T.assert_eq(#after, 0, "expected zero marks after clear")
  vim.api.nvim_buf_delete(buf, { force = true })
end)

T.run("apply: defines highlight groups", function()
  local buf = make_buf(5)
  render.apply(buf, { [1] = true }, "hint")
  local sign_hl = vim.api.nvim_get_hl(0, { name = "CoverageHintsSign" })
  local hint_hl = vim.api.nvim_get_hl(0, { name = "CoverageHintsHint" })
  T.assert_true(sign_hl ~= nil, "CoverageHintsSign should be defined")
  T.assert_true(hint_hl ~= nil, "CoverageHintsHint should be defined")
  vim.api.nvim_buf_delete(buf, { force = true })
end)

T.run("apply: tolerates lines beyond buffer length", function()
  local buf = make_buf(3)
  -- Should not error; out-of-range lines are silently skipped.
  render.apply(buf, { [1] = true, [99] = true }, "hint")
  local marks = vim.api.nvim_buf_get_extmarks(buf, render.namespace, 0, -1, {})
  T.assert_true(#marks >= 1, "expected at least one mark for the in-range line")
  vim.api.nvim_buf_delete(buf, { force = true })
end)

T.finish()
