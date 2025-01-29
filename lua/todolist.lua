local M = {}

local function is_todo_file()
  return vim.bo.filetype == "todo" or vim.fn.expand("%:e") == "TODO"
end

local function get_timestamp()
  return os.date("%d-%m-%Y-%H-%M-%S")
end

-- Insert a new task with [ ]
function M.create_task()
  if not is_todo_file() then return end
  vim.api.nvim_put({ "[ ] " }, "c", true, true)
end

-- Start a task, inserting start time
function M.start_task()
  if not is_todo_file() then return end

  local line = vim.api.nvim_get_current_line()

  if line:match("%[ %]") then
    local new_line = line:gsub("%[ %]", "[>]") .. " (Start: " .. get_timestamp() .. ")"
    vim.api.nvim_set_current_line(new_line)
  end
end

-- Complete a task, inserting finish time
function M.complete_task()
  if not is_todo_file() then return end

  local line = vim.api.nvim_get_current_line()

  if line:match("%[>]") then
    local new_line = line:gsub("%[>]", "[x]") .. " (Finish: " .. get_timestamp() .. ")"
    vim.api.nvim_set_current_line(new_line)
  end
end

-- Set key mappings for .TODO files
function M.setup()
  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.TODO",
    callback = function()
      vim.api.nvim_buf_set_keymap(0, "i", "<C-Space>", "<cmd>lua require'todolist'.create_task()<CR>", { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(0, "n", "<C-s>", "<cmd>lua require'todolist'.start_task()<CR>", { noremap = true, silent = true })
      vim.api.nvim_buf_set_keymap(0, "n", "<C-d>", "<cmd>lua require'todolist'.complete_task()<CR>", { noremap = true, silent = true })
    end,
  })
end

return M
