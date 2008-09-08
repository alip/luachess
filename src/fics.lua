#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
--- Lua module to interact with the Free Internet Chess Server
-- Requires luasocket.
-- Copyright 2008 Ali Polatel <polatel@itu.edu.tr>
-- Distributed under the terms of the GNU General Public License v2

--{{{ Grab environment we need
local assert = assert
local error = error
local ipairs = ipairs
local pcall = pcall
local setmetatable = setmetatable
local type = type
local unpack = unpack

local io = io
local os = os
local string = string
local table = table
local socket = require("socket")
local timeseal = require("timeseal")

--}}}
--{{{ Variables
module("fics")
_VERSION = 0.1

client = {}

CR = "\r"
LF = "\n"
--{{{ FICS Interface Variables
local IVARS_COUNT = 35
IVARS_PREFIX = "%b"
IV_COMPRESSMOVE = 1
IV_AUDIOCHAT = 2
IV_SEEKREMOVE = 3
IV_DEFPROMPT = 4
IV_LOCK = 5
IV_STARTPOS = 6
IV_BLOCK = 7
IV_GAMEINFO = 8
IV_XDR = 9
IV_PENDINFO = 10
IV_GRAPH = 11
IV_SEEKINFO = 12
IV_EXTASCII = 13
IV_NOHILIGHT = 14
IV_VT_HILIGHT = 15
IV_SHOWSERVER = 16
IV_PIN = 17
IV_MS = 18
IV_PINGINFO = 19
IV_BOARDINFO = 20
IV_EXTUSERINFO = 21
IV_SEEKCA = 22
IV_SHOWOWNSEEK = 23
IV_PREMOVE = 24
IV_SMARTMOVE = 25
IV_MOVECASE = 26
IV_SUICIDE = 27
IV_CRAZYHOUSE = 28
IV_LOSERS = 29
IV_WILDCASTLE = 30
IV_FR = 31
IV_NOWRAP = 32
IV_ALLRESULTS = 33
IV_OBSPING = 34
IV_SINGLEBOARD = 35
--}}}
--}}}
--{{{ Utility functions
local function tolist(str, delim) --{{{
    local delim = delim or " "
    local strlist = {}
    if str ~= "" then
        for element in string.gmatch(str, "[^" .. delim .. "]+") do
            table.insert(strlist, element)
        end
    end

    return strlist
end --}}}
local function totaglist(tags) --{{{
    local taglist = {}
    if tags ~= "" then
        for tag in string.gmatch(tags, "%(([%u%*]+)%)") do
            table.insert(taglist, tag)
        end
    end

    return taglist
end --}}}
--}}}
--{{{ fics.client functions
function client:new(argtable) --{{{
    assert(type(argtable) == "table", "Argument is not a table")

    local instance = {
        prompt = argtable.prompt or "^fics%% $",
        login_prompt = argtable.prompt_login or "^login: $",
        password_prompt = argtable.prompt_password or "^password: $",
        ivars = argtable.ivars or {},
        timeseal = argtable.timeseal or false,

        sock = nil,
        callbacks = {},

        -- Internal
        _ivars_sent = false,
        _last_sent = 0,
        _seen_prompt = false,
        _linebuf = ""
    }

    return setmetatable(instance, { __index = client })
end --}}}
function client:ivars_tostring() --{{{
    local ivstr = IVARS_PREFIX

    for index=1,IVARS_COUNT do
        if self.ivars[index] then
            ivstr = ivstr .. "1"
        else
            ivstr = ivstr .. "0"
        end
    end

    return ivstr
end --}}}
function client:connect(address, port) --{{{
    assert(self.sock == nil, "already connected")
    local address = address or "freechess.org"
    local port = port or 23

    local errmsg
    self.sock, errmsg = socket.connect(address, port)
    if self.sock == nil then return nil, errmsg end

    if self.timeseal then
        local initstr, errmsg = timeseal.init_string()
        if initstr == nil then return nil, errmsg end

        local bytes, errmsg = self:send(initstr)
        if errmsg ~= nil then return nil, errmsg end
    end

    self.sock:settimeout(0)
    return true
end --}}}
function client:disconnect() --{{{
    assert(self.sock ~= nil, "not connected")

    self.sock:close()
    self.sock = nil
end --}}}
function client:send(data) --{{{
    if self.timeseal then
        data, errmsg = timeseal.encode(data)
        if data == nil then
            return nil, errmsg
        end
    else
        data = data .. LF
    end

    local bytes, errmsg = self.sock:send(data)
    if errmsg == nil then
        -- Keep track of time for idle callback.
        self._last_sent = os.time()
    end

    return bytes, errmsg
end --}}}
function client:recvline() --{{{
    assert(self.sock ~= nil, "not connected")

    while true do
        local chunk, errmsg = self.sock:receive(1)
        if chunk == nil then
            return nil, errmsg
        end

        -- fics sends CRLF at the end of every line.
        if chunk == LF then
            break
        elseif chunk ~= CR then
            self._linebuf = self._linebuf .. chunk

            if string.find(self._linebuf, self.login_prompt) then
                break
            elseif string.find(self._linebuf, self.password_prompt) then
                break
            elseif string.find(self._linebuf, self.prompt) then
                if self._seen_prompt == false then
                    self._seen_prompt = true
                end
                break
            end
        end
    end

    local line = self._linebuf
    self._linebuf = ""
    if self._seen_prompt and line == "" then
        -- The newline after the prompt causes this.
        self._seen_prompt = false
        return nil, "timeout"
    else
        return line
    end
end --}}}
function client:register_callback(name, func) --{{{
    if self.callbacks[name] == nil then
        self.callbacks[name] = { func }
    else
        table.insert(self.callbacks[name], func)
    end
end --}}}
function client:run_callback(name, ...) --{{{
    if self.callbacks[name] ~= nil then
        for index, func in ipairs(self.callbacks[name]) do
            local status, errmsg = pcall(func, self, unpack(arg))
            if status == false then
                if self.sock ~= nil then self.sock:close() end
                error("Error: Callback group: " .. name .. " index: " .. index .. " failed: " .. errmsg)
            elseif errmsg == false then
                -- Callback returned false, don't run any other callback.
                break
            end
        end
    end
end --}}}
function client:parseline(line) --{{{
    self:run_callback("idle", os.time() - self._last_sent)
    self:run_callback("line", line)

    -- Prompts
    if string.find(line, self.login_prompt) then
        if self.ivars ~= nil and self._ivars_sent == false then
            -- Set necessary interface variables.
            self.ivars[IV_DEFPROMPT] = true
            self.ivars[IV_NOWRAP] = true
            -- and lock them.
            self.ivars[IV_LOCK] = true
            local bytes, errmsg = self:send(self:ivars_tostring())
            if errmsg ~= nil then
                return nil, errmsg
            else
                self._ivars_sent = true
            end

            -- Send another newline to get login prompt back.
            local bytes, errmsg = self:send("")
            if errmsg ~= nil then
                return nil, errmsg
            end
        else
            assert(self.callbacks["login"], "no callback for login")
            self:run_callback("login")
        end
    elseif string.find(line, self.password_prompt) then
        assert(self.callbacks["password"], "no callback for password")
        self:run_callback("password")
    elseif string.find(line, self.prompt) then
        self:run_callback("prompt")

    -- Authentication
    elseif string.find(line, "^A name should be at least three characters long") then
        if self.callbacks["handle_too_short"] ~= nil then
            self:run_callback("handle_too_short")
        else
            error("handle too short")
        end
    elseif string.find(line, "^Sorry, names may be at most 17 characters long") then
        if self.callbacks["handle_too_long"] ~= nil then
            self:run_callback("handle_too_long")
        else
            error("handle too long")
        end
    elseif string.find(line, "^Sorry, names can only consist of lower and upper case letters") then
        if self.callbacks["handle_not_alpha"] ~= nil then
            self:run_callback("handle_not_alpha")
        else
            error("handle not alpha")
        end
    elseif string.find(line, "^\"%w+\" is not a registered name") then
        handle = string.match(line, "^\"(%w+)\"")
        self:run_callback("handle_not_registered", handle)
    elseif string.find(line, "^%*%*%*%* Invalid password! %*%*%*%*") then
        if self.callbacks["password_invalid"] ~= nil then
            self:run_callback("password_invalid")
        else
            error("invalid password")
        end

    -- Session start
    elseif string.find(line, "^%*%*%*%* Starting FICS session as") then
        handle, tags = string.match(line, "^%*%*%*%* Starting FICS session as (%a+)(.*)")
        self:run_callback("session_start", handle, totaglist(tags))
    elseif string.find(line, "^%d+ %(.*%) .*") then
        local no, date, subject = string.match(line, "^(%d+) %((.*)%) (.*)")
        self:run_callback("news", no, date, subject)
    elseif string.find(line, "^You have %d+ messages? %(%d+ unread%).") then
        local total, unread = string.match(line, "^You have (%d+) messages? %((%d+) unread%).")
        self:run_callback("messages", total, unread)
    elseif string.find(line, "^Present company includes:") then
        local handles = string.match(line, "^Present company includes: ([%a ]+).")
        self:run_callback("notify_includes", tolist(handles))
    elseif string.find(line, "^Your arrival was noted by:") then
        local handles = string.match(line, "^Your arrival was noted by: ([%a ]+).")
        self:run_callback("notify_noted", tolist(handles))

    -- Chat
    elseif string.find(line, "^%a+[%u%*%(%)]* tells you:") then
        handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) tells you: (.*)")
        self:run_callback("tell", handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]*%(%d+%):") then
        handle, tags, channel, message = string.match(line, "^(%a+)([%u%*%(%)]*)%((%d+)%): (.*)")
        channel = channel + 0 -- Convert to integer
        self:run_callback("chantell", handle, totaglist(tags), channel, message)
    elseif string.find(line, "^:") then
        message = string.match(line, "^:(.*)")
        self:run_callback("qtell", message)
    elseif string.find(line, "^--> %a+[%u%*%(%)]*.*") then
        handle, tags, message = string.match(line, "^--> (%a+)([%u%*%(%)]*)(.*)")
        self:run_callback("it", handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]* shouts:") then
        handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) shouts: (.*)")
        self:run_callback("shout", handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]* c%-shouts:") then
        handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) c%-shouts: (.*)")
        self:run_callback("cshout", handle, totaglist(tags), message)
    elseif string.find(line, "^ +*%*%*ANNOUNCEMENT%%*%*") then
        handle, message = string.match(line, "^ +%*%*ANNOUNCEMENT%*%* from (%a+): (.*)")
        self:run_callback("announcement", handle, message)

    -- Challenge
    elseif string.find(line, "^%a+ updates the match request.") then
        game = { update = true }
    elseif string.find(line, "^Challenge:") then
        local handle1, rating1, handle2, rating2, rated, gtype, time, inc, chunk =
            string.match(line, "^Challenge: (%a+) %(([%dEP-]+)%) (%a+) %(([%dEP-]+)%) (%a+) (%a+) (%d+) (%d+)(.*)%.")

        -- if rating1 == "----" then rating1 = nil end
        -- if rating2 == "----" then rating2 = nil end

        if rated == "rated" then rated = true
        elseif rated == "unrated" then rated = false
        else error("unknown rated value '" .. rated .. "'") end

        if chunk ~= "" then
            if string.find(chunk, "^ Loaded from wild/") then
                wildtype = string.match(chunk, "^ Loaded from wild/(%d+)")
            end
        end

        player1 = { handle = handle1, rating = rating1 }
        player2 = { handle = handle2, rating = rating2 }

        if game == nil then
            game = { update = false, type = gtype, wtype = wildtype,
                rated = rated, time = time + 0, inc = inc + 0}
        else
            game.type = gtype
            game.wtype = wildtype
            game.rated = rated
            game.time = time + 0
            game.inc = inc + 0
        end

        if rated == false then
            -- Don't wait for the next line to call the callback
            self:run_callback("challenge", player1, player2, game)
        end
    elseif string.find(line, "^Your %a+ rating will change:") then
        game.win, game.draw, game.loss = string.match(line,
            "^Your %a+ rating will change:  Win: %+?([%d-%.]+),  Draw: %+?([%d-%.]+),  Loss: %+?([%d-%.]+)")
        -- Convert to integers
        game.win = game.win + 0
        game.draw = game.draw + 0
        game.loss = game.loss + 0
    elseif string.find(line, "^Your new RD will be") then
        game.newrd = string.match(line, "^Your new RD will be ([%d%.]+)") + 0
        self:run_callback("challenge", player1, player2, game)

    -- Bughouse
    elseif string.find(line, "^%a+ offers to be your bughouse partner") then
        handle = string.match(line, "^(%a+) ")
        self:run_callback("partner", handle)

    -- Style 12
    elseif string.find(line, "^<12>") then
        local m = {}
        m.rank8, m.rank7, m.rank6, m.rank5,
        m.rank4, m.rank3, m.rank2, m.rank1,
        m.tomove, m.doublepawn,
        m.wcastle, m.wlcastle, m.bcastle, m.blcastle,
        m.lastirr, m.gameno, m.wname, m.bname,
        m.relation, m.itime, m.inc,
        m.wstrength, m.bstrength, m.wtime, m.btime,
        m.moveno, m.llastmove, m.lastmin, m.lastsec, m.lastmove,
        m.flip = string.match(line,
            "^<12> " ..
            "([%a%-]+) ([%a%-]+) ([%a%-]+) ([%a%-]+) " ..
            "([%a%-]+) ([%a%-]+) ([%a%-]+) ([%a%-]+) " ..
            "([BW]) ([%d%l-]+) " ..
            "([01]) ([01]) ([01]) ([01]) " ..
            "(%d+) (%d+) (%a+) (%a+) " ..
            "([%d%-]+) (%d+) (%d+) " ..
            "(%d+) (%d+) (%d+) (%d+) " ..
            "(%d+) ([%a%d%p]+) %((%d+):(%d+)%) ([%a%d%p]+) " ..
            "([01])")

        if m.wcastle == 0 then
            m.wcastle = false
        else
            m.wcastle = true
        end

        if m.wlcastle == 0 then
            m.wlcastle = false
        else
            m.wlcastle = true
        end

        if m.bcastle == 0 then
            m.bcastle = false
        else
            m.bcastle = true
        end

        if m.blcastle == 0 then
            m.blcastle = false
        else
            m.blcastle = true
        end

        if m.flip == 0 then
            m.flip = false
        else
            m.flip = true
        end

        -- Convert to integer
        m.lastirr = m.lastirr + 0
        m.gameno = m.gameno + 0
        m.relation = m.relation + 0
        m.itime = m.itime + 0
        m.inc = m.inc + 0
        m.wstrength = m.wstrength + 0
        m.bstrength = m.bstrength + 0
        m.wtime = m.wtime + 0
        m.btime = m.btime + 0
        m.moveno = m.moveno + 0
        m.lastmin = m.lastmin + 0
        m.lastsec = m.lastsec + 0

        self:run_callback("style12", m)

    -- Game start, end
    elseif string.find(line, "{Game (%d+) %((%a+) vs. (%a+)%) (.*)} ([%*%d%p]+)") then
        gameno, wname, bname, reason, result = string.match(line,
            "{Game (%d+) %((%a+) vs. (%a+)%) (.*)} ([%*%d%p]+)")
        gameno = gameno + 0
        self:run_callback("game_end", gameno, wname, bname, reason, result)
    elseif string.find(line, "{Game (%d+) %((%a+) vs. (%a+)%) (.*)}") then
        gameno, wname, bname, reason = string.match(line,
            "{Game (%d+) %((%a+) vs. (%a+)%) (.*)}")
        gameno = gameno + 0
        self:run_callback("game_start", gameno, wname, bname, reason)
    -- The rest is unknown
    else
        self:run_callback("line_unknown", line)
    end

    return true
end --}}}
function client:loop(times) --{{{
    local times = times or 0

    if 0 >= times then
        while true do
            local line, errmsg = self:recvline()
            if line == nil then
                if errmsg ~= "timeout" then
                    return nil, errmsg
                end
            else
                status, errmsg = self:parseline(line)
                if status == nil then return nil, errmsg end
            end
        end
    else
        for i=1,times do
            local line, errmsg = self:recvline()
            if line == nil then
                if errmsg ~= "timeout" then
                    return nil, errmsg
                end
            else
                status, errmsg = self:parseline(line)
                if status == nil then return nil, errmsg end
            end
        end
    end

    return true
end --}}}
--}}}

