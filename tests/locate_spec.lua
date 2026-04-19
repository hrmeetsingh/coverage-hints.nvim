dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/minimal_init.lua")

local locate = require("coverage-hints.locate")

local go_root = T.fixture("go_project")
local lcov_root = T.fixture("lcov_project")

T.run("find_coverage_file: finds coverage.out at project root", function()
  local found = locate.find_coverage_file(go_root)
  T.assert_true(found ~= nil, "expected to find a coverage file")
  T.assert_eq(found.path, go_root .. "/coverage.out")
  T.assert_eq(found.format, "go")
  T.assert_eq(found.root, go_root)
end)

T.run("find_coverage_file: walks up from a nested dir", function()
  -- Create a nested dir under go_root; coverage.out lives at go_root.
  local nested = go_root .. "/cmd/inner"
  vim.fn.mkdir(nested, "p")
  local found = locate.find_coverage_file(nested)
  T.assert_true(found ~= nil, "expected walk-up to find coverage.out")
  T.assert_eq(found.path, go_root .. "/coverage.out")
  vim.fn.delete(go_root .. "/cmd", "rf")
end)

T.run("find_coverage_file: finds lcov.info when no coverage.out present", function()
  local found = locate.find_coverage_file(lcov_root .. "/src")
  T.assert_true(found ~= nil, "expected to find lcov.info via walk-up")
  T.assert_eq(found.path, lcov_root .. "/lcov.info")
  T.assert_eq(found.format, "lcov")
end)

T.run("find_coverage_file: returns nil outside any project", function()
  local found = locate.find_coverage_file("/tmp")
  -- /tmp may legitimately have no coverage file; result should be nil or
  -- something unrelated. We assert it is not pointing inside our fixtures.
  if found then
    T.assert_true(not found.path:find("fixtures", 1, true),
      "unexpected fixture coverage matched from /tmp: " .. found.path)
  end
end)

T.run("find_project_root: finds go.mod", function()
  local root = locate.find_project_root(go_root)
  T.assert_eq(root, go_root)
end)

T.run("find_project_root: walks up from subdir", function()
  local nested = go_root .. "/sub/deep"
  vim.fn.mkdir(nested, "p")
  T.assert_eq(locate.find_project_root(nested), go_root)
  vim.fn.delete(go_root .. "/sub", "rf")
end)

T.run("guess_test_file: Go .go -> sibling _test.go (exists)", function()
  local g = locate.guess_test_file(go_root .. "/sample.go", go_root)
  T.assert_true(g ~= nil)
  T.assert_eq(g.path, go_root .. "/sample_test.go")
  T.assert_eq(g.exists, true)
end)

T.run("guess_test_file: Go .go -> _test.go (missing)", function()
  local g = locate.guess_test_file(go_root .. "/nonexistent.go", go_root)
  T.assert_eq(g.path, go_root .. "/nonexistent_test.go")
  T.assert_eq(g.exists, false)
end)

T.run("guess_test_file: TS -> .test.ts (missing returns canonical)", function()
  local g = locate.guess_test_file("/tmp/foo.ts", "/tmp")
  T.assert_eq(g.path, "/tmp/foo.test.ts")
  T.assert_eq(g.exists, false)
end)

T.run("guess_test_file: Python -> sibling test_*.py then tests/", function()
  local proj = vim.fn.tempname()
  vim.fn.mkdir(proj, "p")
  local src = proj .. "/mod.py"
  io.open(src, "w"):close()
  -- No sibling test, no tests/ dir → falls back to canonical path under tests/
  local g = locate.guess_test_file(src, proj)
  T.assert_eq(g.path, proj .. "/tests/test_mod.py")
  T.assert_eq(g.exists, false)
  -- Now create sibling test_mod.py — guess should pick it up.
  io.open(proj .. "/test_mod.py", "w"):close()
  local g2 = locate.guess_test_file(src, proj)
  T.assert_eq(g2.path, proj .. "/test_mod.py")
  T.assert_eq(g2.exists, true)
  vim.fn.delete(proj, "rf")
end)

T.run("guess_test_file: unknown extension returns nil", function()
  local g = locate.guess_test_file("/tmp/file.txt", "/tmp")
  T.assert_eq(g, nil)
end)

T.finish()
