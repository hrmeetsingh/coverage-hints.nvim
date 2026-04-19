# coverage-hints.nvim

Inline coverage hints for Neovim. Reads Go `coverage.out` or LCOV `lcov.info`
from the project root and marks uncovered lines in the active buffer with
sign-column glyphs and end-of-line virtual text suggesting which test file to
extend.

## Features

- Parses **Go cover** profile (`go test -coverprofile`) and **LCOV** `lcov.info`
  (works with any tool emitting LCOV: Jest, c8, vitest, pytest-cov,
  cargo-llvm-cov, etc.).
- Sign-column glyph on every uncovered line, plus an end-of-line hint on the
  first line of each contiguous range:
  `▎ func Mul(a, b int) int {                ◌ uncovered — add case in sample_test.go`
- Suggests the conventional test file (`foo_test.go`, `foo.test.ts`,
  `test_foo.py`, …) and flags it as `(missing)` when the file does not exist
  yet.
- `]u` / `[u` motions to jump between uncovered lines (mirrors `]d` / `[d`).
- Toggle / show / hide / refresh via keymap or `:CoverageHints` user command.
- Per-buffer state, mtime-cached parsing, no background processes, zero
  external dependencies.

## Requirements

- Neovim ≥ 0.10 (uses `vim.api.nvim_buf_set_extmark` with `sign_text`).
- A coverage report somewhere up the directory tree from the buffer's file.
  The plugin walks up looking for, in order:
  1. `coverage.out`
  2. `cover.out`
  3. `coverage/lcov.info`
  4. `lcov.info`

  The format is inferred from the filename.

## Installation

### lazy.nvim

```lua
{
  "hrmeetsingh/coverage-hints.nvim",
  event = "BufReadPost",
  opts = {},
  keys = {
    { "<leader>tch", function() require("coverage-hints").toggle()  end, desc = "Coverage: toggle hints" },
    { "<leader>tcs", function() require("coverage-hints").show()    end, desc = "Coverage: show" },
    { "<leader>tcx", function() require("coverage-hints").hide()    end, desc = "Coverage: hide" },
    { "<leader>tcr", function() require("coverage-hints").refresh() end, desc = "Coverage: refresh" },
    { "]u",          function() require("coverage-hints").next()    end, desc = "Next uncovered line" },
    { "[u",          function() require("coverage-hints").prev()    end, desc = "Prev uncovered line" },
  },
}
```

`opts = {}` is enough — `setup()` is called automatically on plugin load.

### packer.nvim

```lua
use({
  "hrmeetsingh/coverage-hints.nvim",
  config = function() require("coverage-hints").setup() end,
})
```

### vim-plug

```vim
Plug 'hrmeetsingh/coverage-hints.nvim'
```

Then in your Lua config: `require("coverage-hints").setup()`.

## Usage

1. Generate a coverage report with your language's test runner (see the
   per-language section below).
2. Open any source file in your project.
3. Press `<leader>tch` (or run `:CoverageHints toggle`).
4. Sign-column markers appear on uncovered lines, with a hint at the end of the
   first line of each contiguous range telling you which test file to extend.
5. Use `]u` / `[u` to jump between uncovered lines.
6. After re-running tests, press `<leader>tcr` to clear the cache and
   re-render with fresh data.

## Per-language quickstart

### Go

```bash
go test -coverprofile=coverage.out ./...
# or with Ginkgo
ginkgo --cover --coverprofile=coverage.out ./...
```

The plugin reads `<module>/sub/file.go` paths from the cover profile and
resolves them to disk via `go.mod`. Test files are guessed as `<file>_test.go`
in the same directory (Go convention).

### JavaScript / TypeScript (Jest)

```bash
jest --coverage --coverageReporters=lcov
```

Produces `coverage/lcov.info`. Test file guess: `foo.test.ts`, then
`foo.spec.ts` if present.

### JavaScript / TypeScript (Vitest / c8)

```bash
vitest run --coverage --coverage.reporter=lcov
# or
c8 --reporter=lcov mocha
```

### Python (coverage.py + pytest)

```bash
coverage run -m pytest
coverage lcov -o lcov.info
```

Test file guess: sibling `test_<name>.py`, then `tests/test_<name>.py` under
the project root.

### Rust

```bash
cargo install cargo-llvm-cov
cargo llvm-cov --lcov --output-path lcov.info
```

## Keymaps and commands

| Mapping             | Action                                  |
| ------------------- | --------------------------------------- |
| `<leader>tch`       | Toggle coverage hints in current buffer |
| `<leader>tcs`       | Show hints                              |
| `<leader>tcx`       | Hide hints                              |
| `<leader>tcr`       | Refresh (clear cache and re-render)     |
| `]u`                | Jump to next uncovered line             |
| `[u`                | Jump to previous uncovered line         |

User command:

```
:CoverageHints {toggle|show|hide|refresh|next|prev}
```

(Defaults to `toggle` when called with no argument.)

## Configuration

```lua
require("coverage-hints").setup({})
```

There are currently no configuration options — the plugin is intentionally
minimal. Customise the look by overriding the highlight groups (after your
colorscheme loads):

```lua
vim.api.nvim_set_hl(0, "CoverageHintsSign", { fg = "#ff5555" })
vim.api.nvim_set_hl(0, "CoverageHintsHint", { fg = "#888888", italic = true })
```

By default they link to `DiagnosticSignWarn` and `DiagnosticVirtualTextWarn`,
so they follow your colorscheme automatically.

## How it finds your coverage file

Starting from the directory of the current buffer, the plugin walks **up**
toward `/`, returning the first match from this list:

| Filename               | Format |
| ---------------------- | ------ |
| `coverage.out`         | Go     |
| `cover.out`            | Go     |
| `coverage/lcov.info`   | LCOV   |
| `lcov.info`            | LCOV   |

The result is cached per-project keyed by mtime; re-parsing only happens when
the file changes (or you call `:CoverageHints refresh`).

## Testing the plugin

```bash
git clone https://github.com/hrmeetsingh/coverage-hints.nvim
cd coverage-hints.nvim
bash tests/run.sh
```

The test suite uses the bare `nvim --headless -l` runner — no plenary or
busted required.

## Limitations / non-goals

- Does not emit LSP-style diagnostics (uses signs + virtual text only).
- Does not generate test stubs — it only suggests the file name.
- Does not auto-rerun your tests; refresh the report manually and call
  `:CoverageHints refresh`.

## License

MIT — see [LICENSE](LICENSE).
