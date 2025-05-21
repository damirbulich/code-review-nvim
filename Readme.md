# Code Review Neovim Plugin
A Neovim plugin to perform code reviews on git diff changes using an Ollama server.
## Features

Fetches git diff and sends it to an Ollama server for review
Displays review comments with file names and line numbers in a Neovim buffer
Configurable Ollama endpoint and model
Customizable keybinding

# Installation
## Requirements

Neovim 0.5+
LuaSocket (luarocks install luasocket)
dkjson (luarocks install dkjson)
Running Ollama server (default: http://localhost:11434)

## Using Lazy.nvim
Add the following to your Lazy.nvim configuration:
```lua
return {
    {
        "damirbulich/code-review-nvim",
        dependencies = {
            -- Ensure LuaSocket and dkjson are installed via luarocks
        },
        config = function()
            require("code-review-nvim").setup({
                ollama_endpoint = "http://localhost:11434/api/generate",
                ollama_model = "llama3.1",
                keymap = "<C-g>"
            })
        end,
    },
}
```

## Usage

Run :CodeReview or press <C-g> (if using the default keymap) to trigger a code review.
The plugin fetches the current git diff, sends it to the Ollama server, and displays the review comments in a new buffer.

## Configuration
You can customize the plugin by passing options to the setup function:

ollama_endpoint: URL of the Ollama server (default: "http://localhost:11434/api/generate")
ollama_model: Ollama model to use (default: "llama3.1")
keymap: Keybinding for the CodeReview command (default: "cr")

## License
MIT

