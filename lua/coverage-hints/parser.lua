local M = {}

local uv = vim.uv or vim.loop

local function read_file(path)
  local fd = uv.fs_open(path, "r", 438)
  if not fd then return nil end
  local stat = uv.fs_fstat(fd)
  if not stat then
    uv.fs_close(fd)
    return nil
  end
  local data = uv.fs_read(fd, stat.size, 0)
  uv.fs_close(fd)
  return data
end

local function read_lines(path)
  local data = read_file(path)
  if not data then return nil end
  local lines = {}
  for line in (data .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(lines, line)
  end
  return lines
end

--- Try to parse a `go.mod` and return the module path.
local function read_module_path(go_mod_path)
  local lines = read_lines(go_mod_path)
  if not lines then return nil end
  for _, line in ipairs(lines) do
    local mod = line:match("^%s*module%s+(%S+)")
    if mod then return mod end
  end
  return nil
end

--- Resolve a Go cover path (typically `<module>/sub/file.go`) to an absolute path.
local function resolve_go_path(cover_path, module_path, project_root)
  if cover_path:sub(1, 1) == "/" then
    return cover_path
  end
  if module_path and cover_path:sub(1, #module_path) == module_path then
    local rel = cover_path:sub(#module_path + 1)
    if rel:sub(1, 1) == "/" then rel = rel:sub(2) end
    return project_root .. "/" .. rel
  end
  return project_root .. "/" .. cover_path
end

--- Parse a Go coverage profile (`go test -coverprofile`) format.
--- Returns `{ [abs_path] = { [lineNr] = true, ... } }` of uncovered lines.
function M.parse_go(path, project_root)
  local lines = read_lines(path)
  if not lines then return {} end

  local module_path = nil
  if project_root then
    module_path = read_module_path(project_root .. "/go.mod")
  end

  local result = {}
  for i, line in ipairs(lines) do
    if i == 1 and line:match("^mode:") then
      -- skip header
    elseif line ~= "" then
      local cover_path, sl, _sc, el, _ec, _stmts, count =
        line:match("^(.-):(%d+)%.(%d+),(%d+)%.(%d+)%s+(%d+)%s+(%d+)$")
      if cover_path and tonumber(count) == 0 then
        local abs = resolve_go_path(cover_path, module_path, project_root or "")
        local start_l = tonumber(sl)
        local end_l = tonumber(el)
        local set = result[abs]
        if not set then
          set = {}
          result[abs] = set
        end
        for l = start_l, end_l do
          set[l] = true
        end
      end
    end
  end
  return result
end

--- Parse an LCOV `lcov.info` file. Returns `{ [abs_path] = { [lineNr] = true } }`.
function M.parse_lcov(path)
  local lines = read_lines(path)
  if not lines then return {} end

  local lcov_dir = vim.fn.fnamemodify(path, ":h")
  local result = {}
  local current_file = nil
  local current_set = nil

  for _, line in ipairs(lines) do
    local sf = line:match("^SF:(.+)$")
    if sf then
      if sf:sub(1, 1) ~= "/" then
        sf = lcov_dir .. "/" .. sf
      end
      current_file = sf
      current_set = result[current_file]
      if not current_set then
        current_set = {}
        result[current_file] = current_set
      end
    elseif line == "end_of_record" then
      current_file = nil
      current_set = nil
    elseif current_set then
      local ln, count = line:match("^DA:(%d+),(%d+)")
      if ln and tonumber(count) == 0 then
        current_set[tonumber(ln)] = true
      end
    end
  end

  -- Drop empty sets (file fully covered)
  for f, set in pairs(result) do
    if next(set) == nil then result[f] = nil end
  end

  return result
end

--- Dispatch parser based on `format` ("go" | "lcov").
function M.parse(format, path, project_root)
  if format == "go" then
    return M.parse_go(path, project_root)
  elseif format == "lcov" then
    return M.parse_lcov(path)
  end
  return {}
end

return M
