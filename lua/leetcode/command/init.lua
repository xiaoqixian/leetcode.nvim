local log = require("leetcode.logger")
local arguments = require("leetcode.command.arguments")

---@class lc.Commands
local cmd = {}

---@param old_name string
---@param new_name string
function cmd.deprecate(old_name, new_name)
    log.warn(("`%s` is deprecated, use `%s` instead."):format(old_name, new_name))
end

function cmd.cache_update() require("leetcode.cache").update() end

---@param options table<string, string[]>
function cmd.problems(options)
    local async = require("plenary.async")
    local problems = require("leetcode.cache.problemlist")

    async.run(
        function() return problems.get() end,
        function(res) require("leetcode.pickers.question").pick(res, options) end
    )
end

---@param cb? function
function cmd.cookie_prompt(cb)
    local cookie = require("leetcode.cache.cookie")

    local popup_options = {
        relative = "editor",
        position = {
            row = "50%",
            col = "50%",
        },
        size = 100,
        border = {
            style = "rounded",
            text = {
                top = " Enter cookie ",
                top_align = "left",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal",
        },
    }

    local Input = require("nui.input")
    local input = Input(popup_options, {
        prompt = " 󰆘 ",
        on_submit = function(value)
            local c_ok, err = pcall(cookie.update, value)
            if not c_ok then return log.warn(err) end

            cmd.menu_layout("menu")
            log.info("Sign-in successful")
            if cb then cb() end
        end,
    })

    input:map("n", { "<Esc>", "q" }, function() input:unmount() end)
    input:mount()
end

---Sign out
function cmd.delete_cookie()
    log.warn("You're now signed out")
    local cookie = require("leetcode.cache.cookie")
    pcall(cookie.delete)

    cmd.menu_layout("signin")
end

---Merge configurations into default configurations and set it as user configurations.
---
---@return lc.UserStatus | nil
function cmd.authenticate() require("leetcode.api.auth").user() end

---Merge configurations into default configurations and set it as user configurations.
---
--@param theme lc-db.Theme
function cmd.qot()
    local problems = require("leetcode.api.problems")
    local Question = require("leetcode.ui.question")

    problems.question_of_today(function(qot) Question:init(qot) end)
end

function cmd.random_question()
    local problems = require("leetcode.cache.problemlist")
    local question = require("leetcode.api.question")

    local q = question.random()
    if q then
        local item = problems.get_by_title_slug(q.title_slug) or {}
        require("leetcode.ui.question"):init(item)
    end
end

function cmd.menu()
    local ok, tabp = pcall(vim.api.nvim_win_get_tabpage, _Lc_Menu.winid)
    if ok then vim.api.nvim_set_current_tabpage(tabp) end
end

---@param layout layouts
function cmd.menu_layout(layout) _Lc_Menu:set_layout(layout) end

function cmd.question_tabs() require("leetcode.pickers.question-tabs").pick() end

function cmd.change_lang()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.warn("No current question found") end

    require("leetcode.pickers.language").pick(q)
end

function cmd.desc_toggle()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.error("No current question found") end

    q.description:toggle()
end

function cmd.console()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.error("No current question found") end
    q.console:toggle()
end

function cmd.info()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.error("No current question found") end
    q.hints:toggle()
end

function cmd.hints()
    cmd.deprecate("Leet hints", "Leet info")
    cmd.info()
end

function cmd.q_run()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.warn("No current question found") end
    q.console:run()
end

function cmd.q_submit()
    local utils = require("leetcode.utils")
    local q = utils.curr_question()
    if not q then return log.warn("No current question found") end
    q.console:submit()
end

function cmd.skills()
    local skills = require("leetcode.ui.skills")
    skills:show()
end

function cmd.fix()
    require("leetcode.cache.cookie").delete()
    require("leetcode.cache.problemlist").delete()
    vim.cmd("qa!")
end

---@return string[], string[]
function cmd.parse(args)
    local parts = vim.split(vim.trim(args), "%s+")
    if args:sub(-1) == " " then parts[#parts + 1] = "" end

    local options = {}
    for _, part in ipairs(parts) do
        local opt = part:match("(.-)=.-")
        if opt then table.insert(options, opt) end
    end

    return parts, options
end

---@param t table
local function cmds_keys(t)
    return vim.tbl_filter(function(key)
        if type(key) ~= "string" then return false end
        if key:sub(1, 1) == "_" then return false end

        return true
    end, vim.tbl_keys(t))
end

---@param _ string
---@param line string
---
---@return string[]
function cmd.complete(_, line)
    local args, options = cmd.parse(line:gsub("Leet%s", ""))
    return cmd.rec_complete(args, options, cmd.commands)
end

---@param args string[]
---@param options string[]
---@param cmds table<string,any>
---
---@return string[]
function cmd.rec_complete(args, options, cmds)
    if not cmds or vim.tbl_isempty(args) then return {} end

    if not cmds._args and cmds[args[1]] then
        return cmd.rec_complete(args, options, cmds[table.remove(args, 1)])
    end

    local txt, keys = args[#args], cmds_keys(cmds)
    if cmds._args then
        local option_keys = cmds_keys(cmds._args)
        option_keys = vim.tbl_filter(
            function(key) return not vim.tbl_contains(options, key) end,
            option_keys
        )
        option_keys = vim.tbl_map(function(key) return ("%s="):format(key) end, option_keys)
        keys = vim.tbl_extend("force", keys, option_keys)

        local s = vim.split(txt, "=")
        if s[2] and cmds._args[s[1]] then
            local vals = vim.split(s[2], ",")
            return vim.tbl_filter(
                function(key)
                    return not vim.tbl_contains(vals, key) and key:find(vals[#vals], 1, true) == 1
                end,
                cmds._args[s[1]]
            )
        end
    end

    return vim.tbl_filter(
        function(key) return not vim.tbl_contains(args, key) and key:find(txt, 1, true) == 1 end,
        keys
    )
end

function cmd.exec(args)
    local t = cmd.commands

    local options = {}
    for s in vim.gsplit(args.args, "%s+", { trimempty = true }) do
        local opt = vim.split(s, "=")
        if opt[2] then
            options[opt[1]] = vim.split(opt[2], ",", { trimempty = true })
        elseif t then
            t = t[s]
        else
            break
        end
    end

    if t and type(t[1]) == "function" then
        t[1](options) ---@diagnostic disable-line
    else
        log.error(("Invalid command: `%s %s`"):format(args.name, args.args))
    end
end

function cmd.setup()
    vim.api.nvim_create_user_command("Leet", cmd.exec, {
        bar = true,
        bang = true,
        nargs = "?",
        desc = "Leet",
        complete = cmd.complete,
    })
end

cmd.commands = {
    cmd.menu,

    menu = { cmd.menu },
    console = { cmd.console },
    info = { cmd.info },
    tabs = { cmd.question_tabs },
    lang = { cmd.change_lang },
    run = { cmd.q_run },
    test = { cmd.q_run },
    submit = { cmd.q_submit },
    random = { cmd.random_question },
    daily = { cmd.qot },
    fix = { cmd.fix },

    list = {
        cmd.problems,

        _args = arguments.list,
    },

    desc = {
        cmd.desc_toggle,

        toggle = { cmd.desc_toggle },
    },

    cookie = {
        update = { cmd.cookie_prompt },
        delete = { cmd.delete_cookie },
    },

    cache = {
        update = { cmd.cache_update },
    },

    --deprecated
    hints = { cmd.hints },
}

return cmd