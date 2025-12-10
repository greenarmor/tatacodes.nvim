local vim = vim
local installer = require 'tata.installer'
local state = require 'tata.state'

local M = {}

local config = {
  keymaps = {
    toggle = nil,
    quit = '<C-q>', -- Default: Ctrl+q to quit
    switch_provider = '<leader>ts',
  },
  border = 'single',
  width = 0.8,
  height = 0.8,
  cmd = 'tata',
  model = nil, -- Default to the latest model
  autoinstall = true,
  use_oss = false,
  local_provider = 'ollama',
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

  if config.keymaps.switch_provider then
    local switch_cmd = [[<cmd>lua require('tatacodes').toggle_provider()<CR>]]
    vim.api.nvim_set_keymap('n', config.keymaps.switch_provider, switch_cmd, { noremap = true, silent = true })
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

    if config.keymaps.switch_provider then
      local switch_cmd = [[<cmd>lua require('tatacodes').toggle_provider()<CR>]]
      vim.api.nvim_buf_set_keymap(buf, 't', config.keymaps.switch_provider, [[<C-\><C-n>]] .. switch_cmd, { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(buf, 'n', config.keymaps.switch_provider, switch_cmd, { noremap = true, silent = true })
    end

    return buf
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  local function extract_exec(cmd_opt)
    if type(cmd_opt) == 'string' then
      return cmd_opt:match('^%s*(%S+)')
    elseif type(cmd_opt) == 'table' then
      return cmd_opt[1]
    end
  end

  local check_cmd = extract_exec(config.cmd)

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
        state.buf = create_clean_buf()
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
    local cmd_type = type(config.cmd)
    local cmd_args

    if cmd_type == 'string' then
      cmd_args = config.cmd
      if config.model then
        cmd_args = cmd_args .. ' -m ' .. vim.fn.shellescape(config.model)
      end
      if config.use_oss then
        cmd_args = cmd_args .. ' --oss'
        if config.local_provider then
          cmd_args = cmd_args .. ' --local-provider ' .. vim.fn.shellescape(config.local_provider)
        end
      end
    elseif cmd_type == 'table' then
      cmd_args = vim.deepcopy(config.cmd)
      if config.model then
        table.insert(cmd_args, '-m')
        table.insert(cmd_args, config.model)
      end
      if config.use_oss then
        table.insert(cmd_args, '--oss')
        if config.local_provider then
          table.insert(cmd_args, '--local-provider')
          table.insert(cmd_args, config.local_provider)
        end
      end
    else
      vim.notify('[tatacodes.nvim] Invalid cmd configuration; expected string or list', vim.log.levels.ERROR)
      return
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

function M.toggle_provider()
  config.use_oss = not config.use_oss
  local target = config.use_oss and 'local provider' or 'cloud provider'
  vim.notify('[tatacodes.nvim] Switched Tata Coding Agent to ' .. target, vim.log.levels.INFO)

  if state.job then
    pcall(vim.fn.jobstop, state.job)
    state.job = nil
  end

  local win_active = state.win and vim.api.nvim_win_is_valid(state.win)
  if win_active then
    M.close()
    vim.schedule(M.open)
  end
end

return setmetatable(M, {
  __call = function(_, opts)
    M.setup(opts)
    return M
  end,
})
