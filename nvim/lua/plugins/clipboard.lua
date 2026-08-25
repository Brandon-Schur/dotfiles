-- OSC 52 clipboard provider.
--
-- When Neovim runs inside tmux it auto-selects the `tmux set-buffer` provider,
-- so "+y fills a tmux paste buffer but never reaches the system clipboard.
-- Forcing OSC 52 here makes yanks emit an escape sequence that tmux forwards
-- out to the outer terminal, which writes the system clipboard.
--
-- Paste reads Neovim's own register (terminal clipboard *reads* via OSC 52 are
-- blocked by most terminals for security; pasting from the system clipboard
-- still works via the terminal's normal paste key).
--
-- On macOS/Linux without tmux: OSC 52 is supported by most modern terminals
-- (Alacritty, Kitty, WezTerm, iTerm2, Windows Terminal). If it causes issues
-- on your terminal, remove this file — Neovim will fall back to pbcopy/xclip.

---@type LazySpec
return {
  "AstroNvim/astrocore",
  init = function()
    local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
    if not ok then return end
    local function paste()
      return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
      name  = "OSC 52",
      copy  = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste,           ["*"] = paste },
    }
  end,
}
