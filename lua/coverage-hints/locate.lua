local M = {}

local uv = vim.uv or vim.loop

local function exists(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil
end

local function is_dir(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

local function dirname(path)
  return vim.fn.fnamemodify(path, ":h")
end

local function join(...)
  return table.concat({ ... }, "/")
end

--- Walk up from `start_dir` until any of `markers` exists, returning that directory.
local function walk_up(start_dir, markers)
  local dir = start_dir
  while dir and dir ~= "" and dir ~= "/" do
    for _, marker in ipairs(markers) do
      if exists(join(dir, marker)) then
        return dir
      end
    end
    local parent = dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return nil
end

--- Find the project root by walking up looking for known markers.
function M.find_project_root(start_dir)
  return walk_up(start_dir, { "go.mod", "package.json", "pyproject.toml", "Cargo.toml", ".git" })
end

--- Coverage file candidates in priority order. The format is inferred from filename.
local COVERAGE_CANDIDATES = {
  { name = "coverage.out", format = "go" },
  { name = "cover.out", format = "go" },
  { name = "coverage/lcov.info", format = "lcov" },
  { name = "lcov.info", format = "lcov" },
}

--- Walk up from `start_dir` looking for a coverage file.
--- Returns `{ path = abs_path, format = "go"|"lcov", root = dir }` or nil.
function M.find_coverage_file(start_dir)
  local dir = start_dir
  while dir and dir ~= "" and dir ~= "/" do
    for _, cand in ipairs(COVERAGE_CANDIDATES) do
      local p = join(dir, cand.name)
      if exists(p) then
        return { path = p, format = cand.format, root = dir }
      end
    end
    local parent = dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return nil
end

--- Map a source file to its conventional test file.
--- Returns `{ path = abs_path, exists = bool }` or nil if no convention applies.
function M.guess_test_file(src_abs, project_root)
  local dir = dirname(src_abs)
  local name = vim.fn.fnamemodify(src_abs, ":t")
  local stem = vim.fn.fnamemodify(name, ":r")
  local ext = vim.fn.fnamemodify(name, ":e")

  if ext == "go" then
    local p = join(dir, stem .. "_test.go")
    return { path = p, exists = exists(p) }
  end

  if ext == "ts" or ext == "tsx" or ext == "js" or ext == "jsx" or ext == "mjs" or ext == "cjs" then
    local candidates = {
      join(dir, stem .. ".test." .. ext),
      join(dir, stem .. ".spec." .. ext),
      join(dir, "__tests__", stem .. ".test." .. ext),
      join(dir, "__tests__", stem .. ".spec." .. ext),
    }
    for _, c in ipairs(candidates) do
      if exists(c) then return { path = c, exists = true } end
    end
    return { path = candidates[1], exists = false }
  end

  if ext == "py" then
    local sibling = join(dir, "test_" .. stem .. ".py")
    if exists(sibling) then return { path = sibling, exists = true } end
    if project_root then
      local in_tests = join(project_root, "tests", "test_" .. stem .. ".py")
      if exists(in_tests) then return { path = in_tests, exists = true } end
      return { path = in_tests, exists = false }
    end
    return { path = sibling, exists = false }
  end

  if ext == "rs" then
    return { path = src_abs, exists = true }
  end

  return nil
end

M._exists = exists
M._is_dir = is_dir
M._dirname = dirname
M._join = join

return M
