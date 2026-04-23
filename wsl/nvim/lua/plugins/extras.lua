-- Extra plugins for shader languages, ML, and quality of life

return {
  -- ─── Shader languages (GLSL / HLSL / WGSL) ──────────────────────
  {
    "tikhomirov/vim-glsl",
    ft = { "glsl", "vert", "frag", "geom", "comp", "tesc", "tese" },
  },

  -- HLSL syntax
  {
    "beyondmarc/hlsl.vim",
    ft = { "hlsl", "fx", "fxh", "cginc" },
  },

  -- WGSL syntax + tree-sitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      if type(opts.ensure_installed) == "table" then
        vim.list_extend(opts.ensure_installed, {
          "wgsl",
          "glsl",
          "hlsl",
          "cuda",
          "python",
          "rust",
          "typescript",
          "tsx",
          "javascript",
          "c",
          "cpp",
          "c_sharp",
          "css",
          "html",
          "json",
          "yaml",
          "toml",
          "lua",
          "bash",
          "dockerfile",
          "markdown",
          "markdown_inline",
        })
      end
    end,
  },

  -- ─── CUDA ────────────────────────────────────────────────────────
  -- .cu and .cuh files treated as cuda/cpp
  {
    "vim-scripts/cuda.vim",
    ft = { "cuda" },
  },

  -- ─── Python ML / Data Science ────────────────────────────────────
  -- Jupyter notebook support in neovim
  {
    "GCBallesteros/jupytext.nvim",
    opts = {
      style = "markdown",
      output_extension = "md",
      force_ft = "markdown",
    },
  },

  -- inline virtual text for Python types
  {
    "linux-cultist/venv-selector.nvim",
    branch = "regexp",
    cmd = "VenvSelect",
    opts = {},
    keys = {
      { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select Python venv" },
    },
  },

  -- ─── Quality of Life ─────────────────────────────────────────────
  -- better diagnostics list
  {
    "folke/trouble.nvim",
    opts = { use_diagnostic_signs = true },
  },

  -- color highlighter (useful for CSS/shaders)
  {
    "NvChad/nvim-colorizer.lua",
    opts = {
      filetypes = {
        "*",
        css = { rgb_fn = true, hsl_fn = true },
        html = { names = true },
        lua = { names = false },
      },
      user_default_options = {
        names = false,
        RGB = true,
        RRGGBB = true,
        RRGGBBAA = true,
      },
    },
  },
}
