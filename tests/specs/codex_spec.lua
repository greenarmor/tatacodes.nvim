-- tests/tatacodes_spec.lua
-- luacheck: globals describe it assert eq
-- luacheck: ignore a            -- “a” is imported but unused
local a = require 'plenary.async.tests'
local eq = assert.equals

describe('tatacodes.nvim', function()
  before_each(function()
    vim.cmd 'set noswapfile' -- prevent side effects
    vim.cmd 'silent! bwipeout!' -- close any open Tatacodes windows
  end)

  it('loads the module', function()
    local ok, tatacodes = pcall(require, 'tatacodes')
    assert(ok, 'tatacodes module failed to load')
    assert(tatacodes.open, 'tatacodes.open missing')
    assert(tatacodes.close, 'tatacodes.close missing')
    assert(tatacodes.toggle, 'tatacodes.toggle missing')
  end)

  it('provides legacy codex alias', function()
    local tatacodes = require 'tatacodes'
    local ok, legacy = pcall(require, 'codex')
    assert(ok, 'legacy tata alias failed to load')
    eq(legacy, tatacodes)
  end)

  it('creates Codex commands', function()
    require('tatacodes').setup { keymaps = {} }

    local cmds = vim.api.nvim_get_commands {}
    assert(cmds['Tatacodes'], 'Tatacodes command not found')
    assert(cmds['TatacodesToggle'], 'TatacodesToggle command not found')
  end)

  it('opens a floating terminal window', function()
    require('tatacodes').setup { cmd = { 'echo', 'test' } }
    require('tatacodes').open()

    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
    eq(ft, 'tatacodes')

    require('tatacodes').close()
  end)

  it('toggles the window', function()
    require('tatacodes').setup { cmd = { 'echo', 'test' } }

    require('tatacodes').toggle()
    local win1 = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win1)

    assert(vim.api.nvim_win_is_valid(win1), 'Tatacodes window should be open')

    -- Optional: manually mark it clean
    vim.api.nvim_buf_set_option(buf, 'modified', false)

    require('tatacodes').toggle()

    local ok, _ = pcall(vim.api.nvim_win_get_buf, win1)
    assert(not ok, 'Tatacodes window should be closed')
  end)

  it('shows statusline only when job is active but window is not', function()
    require('tatacodes').setup { cmd = { 'sleep', '1000' } }
    require('tatacodes').open()

    vim.defer_fn(function()
      require('tatacodes').close()
      local status = require('tatacodes').statusline()
      eq(status, '[Tata]')
    end, 100)
  end)

  it('passes -m <model> to termopen when configured', function()
    local original_fn = vim.fn
    local termopen_called = false
    local received_cmd = {}

    -- Mock vim.fn with proxy
    vim.fn = setmetatable({
      termopen = function(cmd, opts)
        termopen_called = true
        received_cmd = cmd
        if type(opts.on_exit) == 'function' then
          vim.defer_fn(function()
            opts.on_exit(0)
          end, 10)
        end
        return 123
      end,
    }, { __index = original_fn })

    -- Reload module fresh
    package.loaded['tatacodes'] = nil
    package.loaded['tatacodes.state'] = nil
    package.loaded['codex'] = nil
    package.loaded['codex.state'] = nil
    package.loaded['tata'] = nil
    package.loaded['tata.state'] = nil
    local tatacodes = require 'tatacodes'

    tatacodes.setup {
      cmd = 'tata',
      model = 'o3-mini',
    }

    tatacodes.open()

    vim.wait(500, function()
      return termopen_called
    end, 10)

    assert(termopen_called, 'termopen should be called')
    if type(received_cmd) == 'table' then
      assert(vim.tbl_contains(received_cmd, '-m'), 'should include -m flag')
      assert(vim.tbl_contains(received_cmd, 'o3-mini'), 'should include specified model name')
    elseif type(received_cmd) == 'string' then
      assert(received_cmd:find('%-m'), 'should include -m flag in command string')
      assert(received_cmd:find('o3%-mini'), 'should include specified model name in command string')
    else
      error('termopen command should be a list or string')
    end

    -- Restore original
    vim.fn = original_fn
  end)

  it('stays on cloud when Ollama orchestrator is unavailable', function()
    local original_notify = vim.notify
    local original_fn = vim.fn
    local notifications = {}
    local shell_error = 1

    vim.notify = function(msg, level)
      table.insert(notifications, { msg = msg, level = level })
    end

    vim.fn = setmetatable({
      executable = function(_, exe)
        if exe == 'ollama' then
          return 1
        end
        return original_fn.executable(exe)
      end,
      system = function(_, _)
        vim.v.shell_error = shell_error
        if shell_error ~= 0 then
          return 'Ollama orchestrator not running'
        end
        return ''
      end,
    }, { __index = original_fn })

    local function restore()
      vim.notify = original_notify
      vim.fn = original_fn
    end

    local ok, err = pcall(function()
      package.loaded['tatacodes'] = nil
      package.loaded['tatacodes.state'] = nil
      package.loaded['codex'] = nil
      package.loaded['codex.state'] = nil
      package.loaded['tata'] = nil
      package.loaded['tata.state'] = nil

      local tatacodes = require 'tatacodes'

      tatacodes.setup {
        cmd = { 'echo', 'test' },
        use_oss = false,
        local_provider = 'ollama',
      }

      tatacodes.toggle_provider()

      eq(#notifications, 1)
      local warn = notifications[#notifications]
      eq(warn.level, vim.log.levels.WARN)
      assert(warn.msg:find('Unable to switch to local provider'), 'expected warning about staying on cloud')

      shell_error = 0
      tatacodes.toggle_provider()

      eq(#notifications, 2)
      local info = notifications[#notifications]
      eq(info.level, vim.log.levels.INFO)
      assert(info.msg:find('Switched Tata Coding Agent to local provider'), 'expected success notification')
    end)

    restore()

    if not ok then
      error(err)
    end
  end)
end)
