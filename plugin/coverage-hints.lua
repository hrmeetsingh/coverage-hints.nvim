if vim.g.loaded_coverage_hints == 1 then return end
vim.g.loaded_coverage_hints = 1

require("coverage-hints").setup()
