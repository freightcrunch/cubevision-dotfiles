-- LSP server configuration
-- Languages: Node.js, Python, TailwindCSS, Rust, C++, C#

return {
  -- mason: manage LSP servers, DAP, linters, formatters
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- Node.js / TypeScript
        "typescript-language-server",
        "eslint-lsp",
        "prettier",
        -- Python
        "pyright",
        "ruff",
        "debugpy",
        -- TailwindCSS
        "tailwindcss-language-server",
        -- Rust (rust-analyzer managed by rustup, not mason)
        -- C / C++
        "clangd",
        "cmake-language-server",
        "codelldb",
        -- C#
        "omnisharp",
        -- Docker
        "dockerfile-language-server",
        "docker-compose-language-service",
        -- Lua (for neovim config)
        "lua-language-server",
        "stylua",
        -- JSON / YAML / TOML
        "json-lsp",
        "yaml-language-server",
        "taplo",
        -- HTML / CSS
        "html-lsp",
        "css-lsp",
        -- Shell
        "shellcheck",
        "shfmt",
        -- WGSL
        "wgsl-analyzer",
      },
    },
  },

  -- lspconfig overrides
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Python
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoImportCompletions = true,
                diagnosticMode = "workspace",
              },
            },
          },
        },
        -- C# (OmniSharp)
        omnisharp = {
          cmd = { "omnisharp" },
          enable_roslyn_analyzers = true,
          organize_imports_on_format = true,
          enable_import_completion = true,
        },
        -- TailwindCSS
        tailwindcss = {
          filetypes = {
            "html", "css", "scss", "javascript", "javascriptreact",
            "typescript", "typescriptreact", "svelte", "vue", "astro",
          },
        },
        -- WGSL
        wgsl_analyzer = {},
        -- Clangd (C/C++ with CUDA support)
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=llvm",
            -- CUDA file extensions
            "--cuda-gpu-arch=sm_50",
          },
          filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
        },
      },
    },
  },
}
