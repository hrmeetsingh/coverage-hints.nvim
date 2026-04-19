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
  first line of each contiguous range. Example of how an uncovered Go function
  looks in your buffer:

  ```text
  ▎ func Mul(a, b int) int {                ◌ uncovered — add case in sample_test.go
  ▎     return a * b
  ▎ }
  ```

- Suggests the conventional test file (`foo_test.go`, `foo.test.ts`,
  `test_foo.py`, …) and flags it as `(missing)` when the file does not exist
  yet.
- `]u` / `[u` motions to jump between uncovered lines (mirrors `]d` / `[d`).
- Toggle / show / hide / refresh via keymap or `:CoverageHints` user command.
- Per-buffer state, mtime-cached parsing, no background processes, zero
  external runtime dependencies.

## Requirements

- **Neovim ≥ 0.10** — uses `vim.api.nvim_buf_set_extmark` with `sign_text`
  and `vim.uv` (with a fallback to `vim.loop`). No other Lua libraries are
  required at runtime; the plugin uses only the Neovim standard API.
- A coverage report somewhere up the directory tree from the buffer's file.
  The plugin walks up looking for, in order:
  1. `coverage.out`
  2. `cover.out`
  3. `coverage/lcov.info`
  4. `lcov.info`

  The format is inferred from the filename.

- To run the test suite locally: **Bash 4+** and **Neovim** in `PATH`. No
  plenary, busted, or other test framework required.

## Tested environments

This plugin has been developed and verified on the following stack:

| Component      | Version                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------ |
| OS             | macOS (Apple Silicon)                                                                      |
| Shell          | zsh                                                                                        |
| Neovim         | 0.12.1 (works on any 0.10+)                                                                |
| Plugin manager | [lazy.nvim](https://github.com/folke/lazy.nvim) inside [LazyVim](https://www.lazyvim.org/) |
| Test runner    | `nvim --headless -l` driven by `bash`                                                      |

It should also work on Linux/WSL with Bash and any Neovim ≥ 0.10. It does
not depend on any platform-specific binaries — all parsing and rendering is
pure Lua via the Neovim API.

Per-language **examples** in this README additionally assume:

- **Go** examples — Go 1.18+ (and optionally [Ginkgo](https://github.com/onsi/ginkgo) for the alt example).
- **JS/TS** examples — Node.js 18+ with one of `jest`, `vitest`, or `c8`.
- **Python** examples — Python 3.8+ with [`coverage.py`](https://coverage.readthedocs.io/) and `pytest`.
- **Rust** examples — Rust 1.70+ with [`cargo-llvm-cov`](https://github.com/taiki-e/cargo-llvm-cov).

None of these are required to use the plugin itself — they're only needed to
generate the coverage report for the language you're working in.

## Installation

This plugin is installed via [lazy.nvim](https://github.com/folke/lazy.nvim)
straight from GitHub. The steps below cover both flavours of lazy.nvim:

- **Path A** — you use [LazyVim](https://www.lazyvim.org/) (the distro).
- **Path B** — you use plain lazy.nvim that you bootstrapped yourself.

If you're not sure which one you have, run `ls ~/.config/nvim/lua/`. If you
see a `config/` folder with `lazy.lua` in it and a `plugins/` folder full of
small spec files, you're on LazyVim — follow Path A.

### Prerequisites

1. Neovim ≥ 0.10:

   ```bash
   nvim --version | head -n 1
   ```

2. `git` available on your `$PATH` (lazy.nvim uses it to clone the repo).

3. Internet access on first launch so lazy.nvim can fetch the plugin from
   `https://github.com/hrmeetsingh/coverage-hints.nvim`.

---

### Path A — LazyVim

LazyVim auto-loads every `*.lua` file under `~/.config/nvim/lua/plugins/` as
a plugin spec. You add **one new file** and edit nothing else.

#### Step 1 — Create the spec file

```bash
mkdir -p ~/.config/nvim/lua/plugins
touch ~/.config/nvim/lua/plugins/coverage-hints.lua
```

#### Step 2 — Add the spec

Open `~/.config/nvim/lua/plugins/coverage-hints.lua` in your editor and
paste:

```lua
return {
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
  },
}
```

#### Step 3 — (Optional) Add a which-key group label

So `<leader>tc` shows up as a "coverage" group in the popup. In the **same**
file, change the outer table to:

```lua
return {
  {
    "hrmeetsingh/coverage-hints.nvim",
    -- ...same as above...
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>tc", group = "coverage" },
      },
    },
  },
}
```

#### Step 4 — Install and verify

1. Restart Neovim. LazyVim opens the `:Lazy` UI on first run and fetches
   the plugin. If it doesn't, run `:Lazy sync` manually.
2. Confirm it's loaded:

   ```vim
   :Lazy
   ```

   Look for `coverage-hints.nvim` in the list with a green checkmark.

3. Open any source file in a project that has a coverage report and run:

   ```vim
   :CoverageHints
   ```

---

### Path B — Plain lazy.nvim (no LazyVim)

If you bootstrap lazy.nvim yourself, the spec lives wherever you call
`require("lazy").setup({...})`. Typical locations:

```text
~/.config/nvim/init.lua
~/.config/nvim/lua/plugins.lua
~/.config/nvim/lua/config/lazy.lua
```

#### Step 1 — Find your `lazy.setup` call

Search your config:

```bash
grep -rn "require(\"lazy\").setup" ~/.config/nvim
```

The file that contains the match is the one you'll edit.

#### Step 2 — Add the spec entry

Inside the table you pass to `require("lazy").setup({...})`, add:

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
},
```

For example, the call should now look like:

```lua
require("lazy").setup({
  -- ...your existing plugins...
  {
    "hrmeetsingh/coverage-hints.nvim",
    event = "BufReadPost",
    opts = {},
    keys = { --[[ as above ]] },
  },
})
```

#### Step 3 — Install and verify

1. Restart Neovim.
2. Run:

   ```vim
   :Lazy sync
   ```

   You should see `coverage-hints.nvim` cloned into
   `~/.local/share/nvim/lazy/coverage-hints.nvim`.

3. Open a buffer in a project that has a coverage report and run:

   ```vim
   :CoverageHints
   ```

---

### Sanity checks (both paths)

If `:CoverageHints` works, you're done. If not, these commands narrow the
problem down:

```vim
:lua print(vim.g.loaded_coverage_hints)            " expect: 1
:lua print(vim.inspect(require("coverage-hints"))) " expect: a table with toggle/show/hide/refresh/next/prev
:Lazy log coverage-hints.nvim                      " lazy.nvim's view of the plugin
```

Common gotchas:

- `Not an editor command: CoverageHints` — the plugin hasn't loaded yet.
  Press one of the `keys` mappings (e.g. `<leader>tch`) to trigger it, or
  remove `event` / `keys` temporarily to load eagerly while debugging.
- `module 'coverage-hints' not found` — lazy.nvim couldn't clone the repo.
  Re-run `:Lazy sync` and check the `:Lazy log` output for git errors.
- Hints don't appear in your buffer — there's no `coverage.out`,
  `cover.out`, `coverage/lcov.info`, or `lcov.info` at or above the
  buffer's directory. Generate one (see [Per-language quickstart](#per-language-quickstart))
  and run `:CoverageHints refresh`.

## Usage

End-to-end example for a Go project (the same flow applies to any language —
just swap step 1 for the matching command from the per-language section):

```bash
cd ~/code/my-go-project
go test -coverprofile=coverage.out ./...
nvim ./pkg/foo/foo.go
```

Inside Neovim:

```vim
" Toggle the hint overlay on the current buffer
<leader>tch
" or, equivalently
:CoverageHints toggle

" Jump between uncovered lines
]u
[u

" After re-running `go test`, refresh the cached report
<leader>tcr
```

What you'll see:

- Sign-column markers appear on uncovered lines.
- A hint at the end of the first line of each contiguous uncovered range
  tells you which test file to extend (and `(missing)` when the test file
  doesn't exist yet).
- `<leader>tcs` shows hints, `<leader>tcx` hides them, `<leader>tcr` refreshes
  after a fresh test run.

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

| Mapping       | Action                                  |
| ------------- | --------------------------------------- |
| `<leader>tch` | Toggle coverage hints in current buffer |
| `<leader>tcs` | Show hints                              |
| `<leader>tcx` | Hide hints                              |
| `<leader>tcr` | Refresh (clear cache and re-render)     |
| `]u`          | Jump to next uncovered line             |
| `[u`          | Jump to previous uncovered line         |

User command:

```vim
:CoverageHints              " same as :CoverageHints toggle
:CoverageHints toggle
:CoverageHints show
:CoverageHints hide
:CoverageHints refresh
:CoverageHints next
:CoverageHints prev
```

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

| Filename             | Format |
| -------------------- | ------ |
| `coverage.out`       | Go     |
| `cover.out`          | Go     |
| `coverage/lcov.info` | LCOV   |
| `lcov.info`          | LCOV   |

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
