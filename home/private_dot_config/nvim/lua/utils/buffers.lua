local M = {}

function M.is_valid(bufnr)
  if not bufnr then
    bufnr = 0
  end
  return vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted
end

function M.smart_quit(write)
  write = write or false
  if write then
    vim.cmd("write")
  end
  local valid_bufs = vim.tbl_filter(M.is_valid, vim.api.nvim_list_bufs())
  if #valid_bufs > 1 then
    vim.api.nvim_command("bdelete")
  else
    vim.api.nvim_command("quit")
  end
end

function M.list_valid_buffers()
  local valid_bufs = vim.tbl_filter(M.is_valid, vim.api.nvim_list_bufs())
  print(vim.inspect(valid_bufs))
end

return M
