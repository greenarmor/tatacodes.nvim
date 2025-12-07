-- tests/init.lua
-- luacheck: globals describe it before_each
-- luacheck: ignore async
local async = require 'plenary.async.tests'

describe('tatacodes.nvim', function()
  require('tatacodes.installer').__test_ignore_path_check = true -- Skip path checks for tests

  it('should load without errors', function()
    require 'tatacodes'
  end)

  it('should respond to basic command', function()
    vim.cmd 'Hello'
    -- Add assertion if it triggers some output or state change
  end)
end)
