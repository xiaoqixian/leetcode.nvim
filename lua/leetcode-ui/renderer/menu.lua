local log = require("leetcode.logger")
local cookie = require("leetcode.cache.cookie")
local config = require("leetcode.config")
local utils = require("leetcode-ui.utils")
local Renderer = require("leetcode-ui.renderer")

---@class lc-menu : lc-ui.Renderer
---@field tabpage integer
---@field cursor lc-menu.cursor
---@field maps table
local Menu = Renderer:extend("LeetMenu")

local function tbl_keys(t)
    local keys = vim.tbl_keys(t)
    if not keys then return end
    table.sort(keys)
    return keys
end

function Menu:draw()
    self:clear_keymaps()
    Menu.super.draw(self, self)
    self:apply_btn_keymaps()

    return self
end

function Menu:clear_keymaps()
    for _, map in ipairs(self.maps) do
        vim.keymap.del(map.mode, map.lhs, { buffer = self.bufnr })
    end

    self.maps = {}
end

function Menu:apply_btn_keymaps()
    local opts = { noremap = false, silent = true, buffer = self.bufnr, nowait = true }

    for _, btn in pairs(self._.buttons) do
        local bopts = btn._.opts
        if not bopts.sc then return end

        local mode = { "n" }
        vim.keymap.set(mode, bopts.sc, bopts.on_press, opts)
        table.insert(self.maps, { mode = mode, lhs = bopts.sc })
    end
end

---@private
function Menu:autocmds()
    local group_id = vim.api.nvim_create_augroup("leetcode_menu", { clear = true })

    vim.api.nvim_create_autocmd("WinResized", {
        group = group_id,
        buffer = self.bufnr,
        callback = function() self:draw() end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group_id,
        buffer = self.bufnr,
        callback = function() self:cursor_move() end,
    })
end

function Menu:cursor_move()
    if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then return end

    local curr = vim.api.nvim_win_get_cursor(self.winid)
    local prev = self.cursor.prev

    local keys = tbl_keys(self._.buttons)
    if not keys then return end

    if prev then
        if curr[1] > prev[1] then
            self.cursor.idx = math.min(self.cursor.idx + 1, #keys)
        elseif curr[1] < prev[1] then
            self.cursor.idx = math.max(self.cursor.idx - 1, 1)
        end
    end

    local row = keys[self.cursor.idx]
    local col = #vim.fn.getline(row):match("^%s*")

    self.cursor.prev = { row, col }
    vim.api.nvim_win_set_cursor(self.winid, self.cursor.prev)
end

function Menu:cursor_reset()
    self.cursor.idx = 1
    self.cursor.prev = nil
end

---@param name lc-menu.pages
function Menu:set_page(name)
    self:cursor_reset()

    local ok, page = pcall(require, "leetcode-ui.group.page." .. name)
    if ok then
        self:replace({ page })
    else
        log.error(page)
    end

    return self:draw()
end

---@private
function Menu:keymaps()
    local press_fn = function()
        local row = vim.api.nvim_win_get_cursor(self.winid)[1]
        self:handle_press(row)
    end

    vim.keymap.set("n", "<cr>", press_fn, { buffer = self.bufnr })
    vim.keymap.set("n", "<Tab>", press_fn, { buffer = self.bufnr })
end

function Menu:apply_options()
    vim.api.nvim_buf_set_name(self.bufnr, "")
    pcall(vim.diagnostic.disable, self.bufnr)

    utils.set_buf_opts(self.bufnr, {
        modifiable = false,
        buflisted = false,
        matchpairs = "",
        swapfile = false,
        buftype = "nofile",
        filetype = config.name,
        synmaxcol = 0,
    })
    utils.set_win_opts(self.winid, {
        wrap = false,
        colorcolumn = "",
        foldlevel = 999,
        foldcolumn = "0",
        cursorcolumn = false,
        cursorline = false,
        number = false,
        relativenumber = false,
        list = false,
        spell = false,
        signcolumn = "no",
    })
end

function Menu:mount()
    if cookie.get() then
        self:set_page("loading")

        local auth_api = require("leetcode.api.auth")
        auth_api.user(function(_, err)
            if err then
                self:set_page("signin")
                log.err(err)
            else
                self:set_page("menu")
            end
        end)
    else
        self:set_page("signin")
    end

    self:apply_options()
    self:keymaps()
    self:autocmds()
    self:draw()

    return self
end

function Menu:init()
    Menu.super.init(self, {}, {
        position = "center",
    })

    self.cursor = {
        idx = 1,
        prev = nil,
    }
    self.maps = {}

    self.bufnr = vim.api.nvim_get_current_buf()
    self.winid = vim.api.nvim_get_current_win()

    _Lc_Menu = self
end

---@type fun(): lc-menu
local LeetMenu = Menu

return LeetMenu