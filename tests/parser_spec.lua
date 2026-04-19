dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/minimal_init.lua")

local parser = require("coverage-hints.parser")

local go_root = T.fixture("go_project")
local go_cov = go_root .. "/coverage.out"
local go_src = go_root .. "/sample.go"

T.run("parse_go: returns empty for missing file", function()
  local data = parser.parse_go("/no/such/file.out", go_root)
  T.assert_eq(next(data), nil, "expected empty table")
end)

T.run("parse_go: resolves <module>/path against go.mod", function()
  local data = parser.parse_go(go_cov, go_root)
  T.assert_true(data[go_src] ~= nil, "expected entry for sample.go (got " .. vim.inspect(data) .. ")")
end)

T.run("parse_go: skips count>0 rows and expands count=0 ranges", function()
  local data = parser.parse_go(go_cov, go_root)
  local lines = data[go_src]
  -- Add (lines 3-5) is covered → must NOT appear
  T.assert_eq(lines[3], nil, "line 3 should be covered")
  T.assert_eq(lines[4], nil, "line 4 should be covered")
  T.assert_eq(lines[5], nil, "line 5 should be covered")
  -- Mul (lines 7-9) uncovered
  for _, ln in ipairs({ 7, 8, 9 }) do
    T.assert_true(lines[ln], "line " .. ln .. " should be uncovered")
  end
  -- IsEven (lines 11-16) uncovered
  for _, ln in ipairs({ 11, 12, 13, 14, 15, 16 }) do
    T.assert_true(lines[ln], "line " .. ln .. " should be uncovered")
  end
end)

T.run("parse_go: skips mode header line", function()
  -- A profile with only the header should yield no entries
  local tmp = vim.fn.tempname() .. ".out"
  local f = io.open(tmp, "w")
  f:write("mode: atomic\n")
  f:close()
  local data = parser.parse_go(tmp, go_root)
  T.assert_eq(next(data), nil, "expected empty result for header-only file")
  os.remove(tmp)
end)

local lcov_root = T.fixture("lcov_project")
local lcov_path = lcov_root .. "/lcov.info"
local lcov_src = lcov_root .. "/src/lib.js"

T.run("parse_lcov: resolves relative SF: against lcov dir", function()
  local data = parser.parse_lcov(lcov_path)
  T.assert_true(data[lcov_src] ~= nil,
    "expected key " .. lcov_src .. " (got " .. vim.inspect(vim.tbl_keys(data)) .. ")")
end)

T.run("parse_lcov: only DA:N,0 lines included", function()
  local data = parser.parse_lcov(lcov_path)
  local lines = data[lcov_src]
  T.assert_eq(lines[1], nil, "DA:1,1 should not be uncovered")
  T.assert_eq(lines[2], nil, "DA:2,1 should not be uncovered")
  T.assert_true(lines[6], "DA:6,0 should be uncovered")
  T.assert_true(lines[10], "DA:10,0 should be uncovered")
  T.assert_true(lines[11], "DA:11,0 should be uncovered")
  T.assert_eq(lines[13], nil, "DA:13,1 should not be uncovered")
end)

T.run("parse_lcov: drops empty file entries on end_of_record", function()
  local tmp_dir = vim.fn.tempname()
  vim.fn.mkdir(tmp_dir, "p")
  local p = tmp_dir .. "/lcov.info"
  local f = io.open(p, "w")
  f:write("SF:foo.js\nDA:1,1\nDA:2,3\nend_of_record\n")
  f:close()
  local data = parser.parse_lcov(p)
  T.assert_eq(next(data), nil, "fully-covered file should be omitted")
  os.remove(p)
  vim.fn.delete(tmp_dir, "rf")
end)

T.run("parse: dispatches by format string", function()
  local d_go = parser.parse("go", go_cov, go_root)
  T.assert_true(d_go[go_src] ~= nil, "go dispatch failed")
  local d_lcov = parser.parse("lcov", lcov_path, nil)
  T.assert_true(d_lcov[lcov_src] ~= nil, "lcov dispatch failed")
  local d_unknown = parser.parse("xml", lcov_path, nil)
  T.assert_eq(next(d_unknown), nil, "unknown format should yield empty table")
end)

T.finish()
