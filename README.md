# tatacodes.nvim

Tatacodes.nvim adds an ergonomic floating terminal inside Neovim that runs the Tata Coding Agent. It ships modern aliases, optional autoinstall of the `tata` CLI, and helpers for surfacing background status in your statusline.

## Requirements
- Neovim 0.8 or newer with Lua 5.1 (standard Neovim runtime).
- Tata Coding Agent executable (`tata`) on your `PATH`. Install it globally with `npm i -g @greenarmor/tatacodes` (or `pnpm add -g @greenarmor/tatacodes`), or ensure one of: `npm`, `pnpm`, `yarn`, `bun`, `deno`, or `corepack` is available so Tatacodes can install it automatically.
- (For contributors) `nvim-lua/plenary.nvim` when executing the included test suite.

## Installation

### Lazy.nvim
```lua
{
  'green/tatacodes.nvim',
  config = function()
    require('tatacodes').setup()
  end,
}
```

Example with lazy-loading commands and keymaps:
```lua
{
  'greenarmor/tatacodes.nvim',
  lazy = true,
  cmd = { 'Tatacodes', 'TatacodesToggle' },
  keys = {
    {
      '<leader>tt',
      function() require('tatacodes').toggle() end,
      desc = 'Toggle Tatacodes popup',
    },
  },
  opts = {
    keymaps = {
      toggle = nil,
      quit = '<C-q>',
    },
    border = 'rounded',
    width = 0.8,
    height = 0.8,
    autoinstall = true,
  },
}
```

### packer.nvim
```lua
use {
  'green/tatacodes.nvim',
  config = function()
    require('tatacodes').setup()
  end,
}
```

## Usage
- Launch the floating terminal with `:Tatacodes` (or `:TatacodesToggle`, `:Codex`, `:CodexToggle`).
- Default quit mapping inside the popup is `<C-q>` in both normal and terminal mode.
- A `<leader>ts` mapping is wired up by default to flip between the cloud agent and a local provider such as Ollama; override `keymaps.switch_provider` (or set it to `nil`) if you want a different key.
- Close or reopen programmatically with `require('tatacodes').close()` and `require('tatacodes').toggle()`.

The buffer exposed to the terminal is of type `tatacodes`, so you can target it in autocommands if needed.

## Configuration
Call `require('tatacodes').setup { ... }` with any of the options below:

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `keymaps.toggle` | string\|nil | `nil` | Normal-mode mapping you want to bind to `TatacodesToggle`. |
| `keymaps.quit` | string\|nil | `<C-q>` | Key used in normal and terminal mode to close the window. |
| `keymaps.switch_provider` | string\|nil | `<leader>ts` | Mapping to toggle between cloud and local providers; set to `nil` to disable. |
| `border` | `'single' \| 'double' \| 'rounded' \| 'none' \| table` | `'single'` | Border style for the floating window. |
| `width` / `height` | number | `0.8` | Editor-relative size (0–1) for the popup. |
| `cmd` | string\|table | `'tata'` | Command executed via `termopen`. Use a table when adding CLI flags, e.g. `{ 'tata', '--telemetry=off' }`. |
| `model` | string\|nil | `nil` | Adds `-m <model>` when launching the agent. |
| `autoinstall` | boolean | `true` | Prompts to install the agent if the executable is missing. |
| `use_oss` | boolean | `false` | When true, appends `--oss` to the Tata CLI launch command. |
| `local_provider` | string\|nil | `'ollama'` | Provider passed as `--local-provider <value>` whenever `use_oss` is enabled. |

## Autoinstall Flow
1. When `cmd` points to an executable that cannot be found and `autoinstall = true`, Tatacodes opens a selector listing detected package managers (enabling `corepack` shims when present).
2. After you choose one, a temporary floating terminal runs the corresponding install command (`@openai/codex`).
3. Success and failure are relayed via `vim.notify`. For managers that need additional `PATH` exports (`pnpm`, `yarn`, `bun`, `deno`), Tatacodes prints tailored follow-up steps.
4. On success the popup reopens automatically with the newly installed CLI.

## Statusline Integration
- `require('tatacodes').statusline()` returns `"[Tata]"` while the background job is active but the window is hidden. You can drop this into any statusline component.
- `require('tatacodes').status()` returns a ready-made lualine component table with icon and colors set.

## Troubleshooting
- When the popup appears but stays empty, confirm the CLI works: `:!tata --version`. If missing, reopen Tatacodes with `autoinstall = true` or install manually.
- Remember to provide `cmd` as a table when including spaces or extra arguments; Neovim does not split plain strings into multiple shell arguments.
- For PATH issues after autoinstall, apply the environment exports shown in the notifications and restart your shell or Neovim.

## Development
- Run the headless test suite with `make test`. Ensure `luarocks --lua-version=5.1` and `plenary.nvim` are available (see `Makefile` for helper targets).
- Generate coverage via `make coverage`, which uses `luacov` and writes `lcov.info`.

Contributions and bug reports are welcome—open an issue or PR with the scenario and expected behavior.
