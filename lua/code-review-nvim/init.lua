local M = {}

-- Default configuration
local defaults = {
    ollama_endpoint = "http://localhost:11434/api/generate",
    ollama_model = "llama3.1",
    keymap = "<leader>cr"
}

-- Plugin configuration
M.config = defaults

-- Function to get git diff
local function get_git_diff()
    local handle = io.popen("git diff --staged")
    local diff = handle:read("*a")
    handle:close()
    return diff
end

-- Function to prepare diff for Ollama
local function prepare_diff_for_ollama(diff)
    return {
        changes = diff
    }
end

-- Function to send request to Ollama using curl
local function send_to_ollama(diff_data)
    local request_body = vim.json.encode({
        model = M.config.ollama_model,
        prompt = "Provided code git diff output, and you are a skillfull code reviewer who is going to review only these changes without knowing the larger context and provide specific comments about bad practices, typos and etc. Importantly be very concise! Here are the changes:\n```\n" .. diff_data.changes .. "\n```",
        stream = false
    })

    -- Escape JSON string for shell command
    local escaped_body = vim.fn.shellescape(request_body)

    -- Run curl command
    local curl_cmd = string.format(
        "curl -s -X POST %s -H 'Content-Type: application/json' -d %s",
        M.config.ollama_endpoint,
        escaped_body
    )
    local result = vim.system({ "bash", "-c", curl_cmd }, { text = true }):wait()

    if result.code ~= 0 then
        error("Ollama request failed: " .. (result.stderr or "Unknown error"))
    end

    return result.stdout
end

-- Function to display raw Ollama response in a floating window
local function display_review(raw_response)
    -- Create a new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    
    -- Split the response into lines
    local lines = vim.split(raw_response, "\n", { trimempty = false })
    
    -- Set buffer contents
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "text")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_name(buf, "Ollama Code Review")

    -- Get current window dimensions
    local win_width = vim.api.nvim_get_option("columns")
    local win_height = vim.api.nvim_get_option("lines")

    -- Calculate floating window size
    local width = math.floor(win_width * 0.8)
    local height = math.floor(win_height * 0.8)
    local col = math.floor((win_width - width) / 2)
    local row = math.floor((win_height - height) / 2)

    -- Configure floating window
    local opts = {
        style = "minimal",
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = "rounded",
        zindex = 50,
    }

    -- Open floating window
    local win = vim.api.nvim_open_win(buf, true, opts)

    -- Set window options
    vim.api.nvim_win_set_option(win, "wrap", true)
    vim.api.nvim_win_set_option(win, "winblend", 0)
end

-- Main function to run code review
local function run_code_review()
    local ok, result = pcall(function()
        local diff = get_git_diff()
        if diff == "" then
            vim.api.nvim_err_writeln("No git changes to review")
            return
        end

        local diff_data = prepare_diff_for_ollama(diff)
        local response = send_to_ollama(diff_data)
        local parsed = vim.json.decode(response)
        display_review(parsed.response)
    end)

    if not ok then
        vim.api.nvim_err_writeln("Error during code review: " .. tostring(result))
    end
end

-- Setup function for plugin configuration
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", defaults, opts or {})
    
    -- Check for curl
    local curl_check = vim.system({ "which", "curl" }, { text = true }):wait()
    if curl_check.code ~= 0 then
        vim.api.nvim_err_writeln("curl not found. Please install curl to use this plugin.")
        return
    end

    -- Register Neovim command
    vim.api.nvim_create_user_command("CodeReview", run_code_review, {})
    
    -- Set up keymap if specified
    if M.config.keymap then
        vim.api.nvim_set_keymap("n", M.config.keymap, ":CodeReview<CR>", { noremap = true, silent = true })
    end
end

return M
