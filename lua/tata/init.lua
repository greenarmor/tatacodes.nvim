local vim = vim
local installer = require 'tata.installer'
local state = require 'tata.state'

local M = {}

local config = {
  keymaps = {
    toggle = nil,
    quit = '<C-q>', -- Default: Ctrl+q to quit
  },
  border = 'single',
  width = 0.8,
  height = 0.8,
  cmd = 'tata',
  model = nil, -- Default to the latest model
  autoinstall = true,
}

function M.setup(user_config)
  config = vim.tbl_deep_extend('force', config, user_config or {})

  vim.api.nvim_create_user_command('Tatacodes', function()
    M.toggle()
  end, { desc = 'Toggle Tatacodes popup' })

  vim.api.nvim_create_user_command('TatacodesToggle', function()
    M.toggle()
  end, { desc = 'Toggle Tatacodes popup (alias)' })

  vim.api.nvim_create_user_command('Codex', function()
    M.toggle()
  end, { desc = 'Toggle Tatacodes popup (legacy alias)' })

  vim.api.nvim_create_user_command('CodexToggle', function()
    M.toggle()
  end, { desc = 'Toggle Tatacodes popup (legacy alias)' })

  if config.keymaps.toggle then
    vim.api.nvim_set_keymap('n', config.keymaps.toggle, '<cmd>TatacodesToggle<CR>', { noremap = true, silent = true })
  end
end

local function open_window()
  local width = math.floor(vim.o.columns * config.width)
  local height = math.floor(vim.o.lines * config.height)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local styles = {
    single = {
      { '┌', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '┐', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '┘', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '└', 'FloatBorder' },
      { '│', 'FloatBorder' },
    },
    double = {
      { '╔', 'FloatBorder' },
      { '═', 'FloatBorder' },
      { '╗', 'FloatBorder' },
      { '║', 'FloatBorder' },
      { '╝', 'FloatBorder' },
      { '═', 'FloatBorder' },
      { '╚', 'FloatBorder' },
      { '║', 'FloatBorder' },
    },
    rounded = {
      { '╭', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╮', 'FloatBorder' },
      { '│', 'FloatBorder' },
      { '╯', 'FloatBorder' },
      { '─', 'FloatBorder' },
      { '╰', 'FloatBorder' },
      { '│', 'FloatBorder' },
    },
    none = nil,
  }

  local border = type(config.border) == 'string' and styles[config.border] or config.border

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = border,
  })
end

function M.open()
  local function create_clean_buf()
    local buf = vim.api.nvim_create_buf(false, false)

    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'hide')
    vim.api.nvim_buf_set_option(buf, 'swapfile', false)
    vim.api.nvim_buf_set_option(buf, 'filetype', 'tatacodes')

    -- Apply configured quit keybinding

    if config.keymaps.quit then
      local quit_cmd = [[<cmd>lua require('tatacodes').close()<CR>]]
      vim.api.nvim_buf_set_keymap(buf, 't', config.keymaps.quit, [[<C-\><C-n>]] .. quit_cmd, { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', config.keymaps.quit, quit_cmd, { noremap = true, silent = true })
    end

    return buf
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  local check_cmd = type(config.cmd) == 'string' and not config.cmd:find '%s' and config.cmd or (type(config.cmd) == 'table' and config.cmd[1]) or nil

  if check_cmd and vim.fn.executable(check_cmd) == 0 then
    if config.autoinstall then
      installer.prompt_autoinstall(function(success)
        if success then
          M.open() -- Try again after installing
        else
          -- Show failure message *after* buffer is created
          if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
            state.buf = create_clean_buf()
          end
          vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {
            'Autoinstall cancelled or failed.',
            '',
            'Ensure the Tata Coding Agent executable (`tata`) is installed and available on your PATH.',
          })
          open_window()
        end
      end)
      return
    else
      -- Show fallback message
      if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
        state.buf = vim.api.nvim_create_buf(false, false)
      end
      vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, {
        'Tata Coding Agent not found and autoinstall is disabled.',
        '',
        'Ensure the Tata Coding Agent (`tata`) is installed and available on your PATH.',
        '',
        'Or enable autoinstall in setup: require("tatacodes").setup{ autoinstall = true }',
      })
      open_window()
      return
    end
  end

  local function is_buf_reusable(buf)
    return type(buf) == 'number' and vim.api.nvim_buf_is_valid(buf)
  end

  if not is_buf_reusable(state.buf) then
    state.buf = create_clean_buf()
  end

  open_window()

  if not state.job then
    local cmd_args = type(config.cmd) == 'string' and { config.cmd } or vim.deepcopy(config.cmd)
    if config.model then
      table.insert(cmd_args, '-m')
      table.insert(cmd_args, config.model)
    end

    state.job = vim.fn.termopen(cmd_args, {
      cwd = vim.loop.cwd(),
      on_exit = function()
        state.job = nil
      end,
    })
  end
end

function M.close()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.toggle()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    M.close()
  else
    M.open()
  end
end

function M.statusline()
  if state.job and not (state.win and vim.api.nvim_win_is_valid(state.win)) then
    return '[Tata]'
  end
  return ''
end

function M.status()
  return {
    function()
      return M.statusline()
    end,
    cond = function()
      return M.statusline() ~= ''
    end,
    icon = '',
    color = { fg = '#51afef' },
  }
end

return setmetatable(M, {
  __call = function(_, opts)
    M.setup(opts)
    return M
  end,
})
