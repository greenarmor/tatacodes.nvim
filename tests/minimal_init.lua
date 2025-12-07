vim.cmd 'set rtp+=.'
vim.cmd 'set rtp+=./plenary.nvim' -- if using as a submodule or symlinked
pcall(require, 'plugin.tatacodes')
pcall(require, 'plugin.tata')
pcall(require, 'plugin.codex') -- legacy alias
vim.opt.runtimepath:append(vim.fn.getcwd())
vim.opt.runtimepath:append(vim.fn.stdpath 'data' .. '/site/pack/deps/start/plenary.nvim')
