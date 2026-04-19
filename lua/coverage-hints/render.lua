local M = {}

local NS = vim.api.nvim_create_namespace("coverage_hints")

--- Define highlight groups (linked to diagnostic groups so they follow the colorscheme).
local function ensure_highlights()
  local set_hl = vim.api.nvim_set_hl
  set_hl(0, "CoverageHintsSign", { default = true, link = "DiagnosticSignWarn" })
  set_hl(0, "CoverageHintsHint", { default = true, link = "DiagnosticVirtualTextWarn" })
  set_hl(0, "CoverageHintsLine", { default = true, link = "DiagnosticUnderlineWarn" })
end

--- Collapse a sorted unique line list into contiguous [start, end] ranges.
local function to_ranges(sorted_lines)
  local ranges = {}
  local i = 1
  while i <= #sorted_lines do
    local s = sorted_lines[i]
    local e = s
    while i + 1 <= #sorted_lines and sorted_lines[i + 1] == e + 1 do
      i = i + 1
      e = sorted_lines[i]
    end
    table.insert(ranges, { s, e })
    i = i + 1
  end
  return ranges
end

--- Sort + dedupe a set of line numbers into an ascending list.
local function set_to_sorted_list(set)
  local list = {}
  for ln in pairs(set) do table.insert(list, ln) end
  table.sort(list)
  return list
end

--- Apply sign + virtual text decorations for `lines_set` in `buf`.
--- @param buf integer
--- @param lines_set table<integer, boolean> 1-indexed line numbers
--- @param hint_text string  Suffix appended after the bullet, e.g. "add test in foo_test.go"
function M.apply(buf, lines_set, hint_text)
  ensure_highlights()
  M.clear(buf)

  if not vim.api.nvim_buf_is_valid(buf) then return end
  local line_count = vim.api.nvim_buf_line_count(buf)

  local sorted = set_to_sorted_list(lines_set)
  local ranges = to_ranges(sorted)

  for _, range in ipairs(ranges) do
    local s, e = range[1], range[2]
    for ln = s, e do
      if ln >= 1 and ln <= line_count then
        local ok, err = pcall(vim.api.nvim_buf_set_extmark, buf, NS, ln - 1, 0, {
          sign_text = "▎",
          sign_hl_group = "CoverageHintsSign",
          line_hl_group = nil,
          priority = 100,
        })
        if not ok then
          vim.notify("coverage-hints: extmark failed line " .. ln .. ": " .. tostring(err), vim.log.levels.DEBUG)
        end
      end
    end

    if s >= 1 and s <= line_count then
      local label = string.format(" ◌ uncovered — %s", hint_text)
      pcall(vim.api.nvim_buf_set_extmark, buf, NS, s - 1, 0, {
        virt_text = { { label, "CoverageHintsHint" } },
        virt_text_pos = "eol",
        hl_mode = "combine",
        priority = 100,
      })
    end
  end
end

--- Clear all decorations applied by this plugin in `buf`.
function M.clear(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
end

M.namespace = NS

return M
