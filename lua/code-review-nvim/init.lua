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
    local handle = io.popen("git diff")
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
        prompt = "Review the following code changes and provide specific comments with line numbers in the format {review: [{file: 'filename', lineNum: number, comment: 'comment'}]}. Here are the changes:\n" .. diff_data.changes,
        stream = false,
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

-- Function to parse Ollama response
local function parse_ollama_response(response)
    local data = vim.json.decode(response)
    if data and data.review then
        return data.review
    else
        error("Invalid response format from Ollama")
    end
end

-- Function to display review comments in Neovim
local function display_review(comments)
    vim.api.nvim_command("new") -- Open new buffer
    local buf = vim.api.nvim_get_current_buf()
    local lines = {}
    for _, comment in ipairs(comments) do
        table.insert(lines, string.format("%s:%d: %s", comment.file, comment.lineNum, comment.comment))
    end
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "filetype", "codereview")
    vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
    vim.api.nvim_buf_set_name(buf, "Code Review")
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
        local comments = parse_ollama_response(response)
        display_review(comments)
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
