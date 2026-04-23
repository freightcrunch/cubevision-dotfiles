-- Nordic Night colorscheme
-- Based on: https://codeberg.org/ashton314/nordic-night
-- Nord palette on a darker #121212 background for higher contrast

return {
  {
    "AlexvZyl/nordic.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      transparent = { bg = false },
      bright_half = false,
      reduced_blue = false,
      cursorline = {
        bold = false,
        bold_number = true,
        theme = "dark",
        blend = 0.7,
      },
      noice = { style = "classic" },
      telescope = { style = "classic" },
      leap = { dim_backdrop = true },
      override = {
        -- Nordic Night: darker background at #121212
        Normal = { bg = "#121212", fg = "#D8DEE9" },
        NormalFloat = { bg = "#1a1a2e", fg = "#D8DEE9" },
        NormalNC = { bg = "#121212", fg = "#D8DEE9" },
        SignColumn = { bg = "#121212" },
        LineNr = { bg = "#121212", fg = "#4C566A" },
        CursorLineNr = { bg = "#1a1a2e", fg = "#EBCB8B", bold = true },
        CursorLine = { bg = "#1a1a2e" },
        StatusLine = { bg = "#1a1a2e", fg = "#D8DEE9" },
        StatusLineNC = { bg = "#121212", fg = "#4C566A" },
        WinSeparator = { fg = "#3B4252", bg = "#121212" },
        VertSplit = { fg = "#3B4252", bg = "#121212" },
        Pmenu = { bg = "#1a1a2e", fg = "#D8DEE9" },
        PmenuSel = { bg = "#3B4252", fg = "#ECEFF4" },
        FloatBorder = { bg = "#1a1a2e", fg = "#81A1C1" },
        TelescopeNormal = { bg = "#121212" },
        TelescopeBorder = { bg = "#121212", fg = "#81A1C1" },
        TelescopePromptNormal = { bg = "#1a1a2e" },
        TelescopePromptBorder = { bg = "#1a1a2e", fg = "#81A1C1" },
        TelescopeResultsNormal = { bg = "#121212" },
        TelescopePreviewNormal = { bg = "#121212" },
        -- Tree / sidebar
        NeoTreeNormal = { bg = "#121212" },
        NeoTreeNormalNC = { bg = "#121212" },
        -- Notification / noice
        NotifyBackground = { bg = "#121212" },
        -- Which-key
        WhichKeyFloat = { bg = "#1a1a2e" },
        -- Indent lines
        IblIndent = { fg = "#2E3440" },
        IblScope = { fg = "#81A1C1" },
      },
    },
    config = function(_, opts)
      require("nordic").setup(opts)
      vim.cmd.colorscheme("nordic")
    end,
  },

  -- override LazyVim's default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nordic",
    },
  },
}
