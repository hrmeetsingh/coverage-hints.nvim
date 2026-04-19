local locate = require("coverage-hints.locate")
local parser = require("coverage-hints.parser")
local render = require("coverage-hints.render")

local uv = vim.uv or vim.loop

local M = {}

--- Per-buffer visibility state: `state[buf] = true` means hints are shown.
local state = {}

--- Cache of parsed coverage data, keyed by project root.
--- `cache[root] = { mtime = number, data = { [abs_path] = { [line] = true } }, file = {path,format,root} }`
local cache = {}

local function buf_path(buf)
  buf = buf or 0
  local name = vim.api.nvim_buf_get_name(buf)
  if name == "" then return nil end
  return vim.fn.fnamemodify(name, ":p")
end

local function load_coverage(start_dir)
  local found = locate.find_coverage_file(start_dir)
  if not found then return nil end

  local stat = uv.fs_stat(found.path)
  if not stat then return nil end

  local entry = cache[found.root]
  if entry and entry.file.path == found.path and entry.mtime == stat.mtime.sec then
    return entry
  end

  local data = parser.parse(found.format, found.path, found.root)
  entry = { mtime = stat.mtime.sec, data = data, file = found }
  cache[found.root] = entry
  return entry
end

local function relpath(target, base)
  if not target or not base then return target end
  if target:sub(1, #base + 1) == base .. "/" then
    return target:sub(#base + 2)
  end
  return target
end

--- Compute uncovered lines for `buf`, plus a hint suffix.
--- Returns `lines_set, hint_suffix, coverage_entry` or `nil, reason`.
local function compute(buf)
  local file = buf_path(buf)
  if not file then return nil, "no file" end

  local start_dir = vim.fn.fnamemodify(file, ":h")
  local entry = load_coverage(start_dir)
  if not entry then return nil, "no coverage file found (looked for coverage.out / lcov.info)" end

  local lines_set = entry.data[file]
  if not lines_set or next(lines_set) == nil then
    return nil, "fully covered (or not in coverage report)"
  end

  local project_root = locate.find_project_root(start_dir) or entry.file.root
  local guess = locate.guess_test_file(file, project_root)
  local hint
  if guess then
    local rel = relpath(guess.path, project_root)
    if guess.exists then
      hint = string.format("add case in %s", rel)
    else
      hint = string.format("add case in %s (missing)", rel)
    end
  else
    hint = "add a covering test case"
  end

  return lines_set, hint, entry
end

function M.show(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local lines_set, hint_or_err = compute(buf)
  if not lines_set then
    vim.notify("coverage-hints: " .. tostring(hint_or_err), vim.log.levels.INFO)
    return false
  end
  render.apply(buf, lines_set, hint_or_err)
  state[buf] = true
  return true
end

function M.hide(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  render.clear(buf)
  state[buf] = false
end

function M.toggle(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if state[buf] then
    M.hide(buf)
  else
    M.show(buf)
  end
end

--- Force re-read of the coverage file and re-render the current buffer.
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local file = buf_path(buf)
  if file then
    local found = locate.find_coverage_file(vim.fn.fnamemodify(file, ":h"))
    if found then cache[found.root] = nil end
  end
  if state[buf] then
    M.show(buf)
  else
    vim.notify("coverage-hints: cache cleared", vim.log.levels.INFO)
  end
end

local function jump(buf, dir)
  buf = buf or vim.api.nvim_get_current_buf()
  local lines_set = compute(buf)
  if not lines_set then return end

  local sorted = {}
  for ln in pairs(lines_set) do table.insert(sorted, ln) end
  table.sort(sorted)
  if #sorted == 0 then return end

  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local target
  if dir > 0 then
    for _, ln in ipairs(sorted) do
      if ln > cur then target = ln break end
    end
    if not target then target = sorted[1] end
  else
    for i = #sorted, 1, -1 do
      if sorted[i] < cur then target = sorted[i] break end
    end
    if not target then target = sorted[#sorted] end
  end

  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zz")
end

function M.next(buf) jump(buf, 1) end
function M.prev(buf) jump(buf, -1) end

local function dispatch(action)
  if action == "toggle" then M.toggle()
  elseif action == "show" then M.show()
  elseif action == "hide" then M.hide()
  elseif action == "refresh" then M.refresh()
  elseif action == "next" then M.next()
  elseif action == "prev" then M.prev()
  else
    vim.notify("coverage-hints: unknown action '" .. tostring(action) .. "'", vim.log.levels.WARN)
  end
end

function M.setup(opts)
  opts = opts or {}

  vim.api.nvim_create_user_command("CoverageHints", function(args)
    dispatch(args.args ~= "" and args.args or "toggle")
  end, {
    nargs = "?",
    complete = function() return { "toggle", "show", "hide", "refresh", "next", "prev" } end,
    desc = "Coverage hints: toggle/show/hide/refresh/next/prev",
  })

  local group = vim.api.nvim_create_augroup("CoverageHints", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(ev)
      if state[ev.buf] then
        vim.schedule(function() M.show(ev.buf) end)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(ev) state[ev.buf] = nil end,
  })
end

return M
