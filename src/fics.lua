#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
--[[
  Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>

  This file is part of LuaFics. LuaFics is free software; you can redistribute
  it and/or modify it under the terms of the GNU General Public License version
  2, as published by the Free Software Foundation.

  LuaFics is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
  Place, Suite 330, Boston, MA  02111-1307  USA
--]]

--- Lua module to interact with the Free Internet Chess Server
-- Requires luasocket.

--{{{ Grab environment we need
local assert = assert
local error = error
local ipairs = ipairs
local pcall = pcall
local setmetatable = setmetatable
local tonumber = tonumber
local type = type
local unpack = unpack

local coroutine = coroutine
local io = io
local os = os
local string = string
local table = table
local socket = require("socket")
local timeseal = require("timeseal")
--}}}
--{{{ Variables
module("fics")
_VERSION = 0.02

client = {}

--{{{ Telnet
local CR = "\r"
local LF = "\n"
local IAC_WILL_ECHO = string.char(255, 251, 1)
local IAC_WONT_ECHO = string.char(255, 252, 1)
--}}}
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
        prompt = argtable.prompt or "^([0-9]?[0-9]?:?[0-9]?[0-9]?)_?fics%% $",
        login_prompt = argtable.prompt_login or "^login: $",
        password_prompt = argtable.prompt_password or "^password: $",
        timeseal = argtable.timeseal or false,

        ivars = argtable.ivars or {},
        send_ivars = argtable.send_ivars or true,

        sock = nil,
        callbacks = {},

        -- Internal
        _ivars_sent = false,
        _last_sent = 0,
        _seen_magicgstr = false,
        _linebuf = "",
        _empty_lines = 0,
        _got_gresponse = false,
        _last_wrapping_group = nil,
    }

    -- Set necessary interface variables.
    instance.ivars[IV_DEFPROMPT] = true
    instance.ivars[IV_LOCK] = true

    client_instance = setmetatable(instance, { __index = client })
    client_instance:register_callback("game_start", function (client)
        client._playing = true
        end)
    client_instance:register_callback("game_end", function (client)
        client._playing = false
        end)
    return client_instance
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

    self:run_callback("idle", os.time() - self._last_sent)
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
                break
            end
        end
    end

    local line = self._linebuf
    self._linebuf = ""
    if self.timeseal and string.find(line, timeseal.MAGICGSTR) then
        self._got_gresponse = true
        self:send(timeseal.GRESPONSE)
        return nil, "internal"
    else
        return line
    end
end --}}}
function client:register_callback(group, func) --{{{
    assert(type(func) == "function" or type(func) == "thread",
        "callback is neither a function nor a coroutine.")
    if self.callbacks[group] == nil then
        self.callbacks[group] = { func }
    else
        table.insert(self.callbacks[group], func)
    end
end --}}}
function client:run_callback(group, ...) --{{{
    if self.callbacks[group] == nil then self.callbacks[group] = {} end
    assert(type(self.callbacks[group]) == "table", "callback group not table")

    for index, func in ipairs(self.callbacks[group]) do
        if type(func) == "function" then
            local status, value = pcall(func, self, unpack(arg))
        elseif type(func) == "thread" then
            local status, value = coroutine.resume(func, self, unpack(arg))
        else
            error("callback is neither a function nor a coroutine.")
        end

        if status == false then
            if self.sock ~= nil then self:disconnect() end
            error("Error: Callback group: " .. group .. " index: " .. index .. " failed: " .. value)
        elseif value == false then
            -- Callback returned/yielded false, don't run any other callback.
            break
        end
    end
end --}}}
function client:parseline(line) --{{{
    -- FICS sends empty lines before timeseal gresponse.
    if self.timeseal and self._playing then
        if self._got_gresponse then
            self._empty_lines = self._empty_lines - 2
            self._got_gresponse = false
        end

        if line == "" then
            self._empty_lines = self._empty_lines + 1
            return true
        else
            while self._empty_lines > 0 do
                self:run_callback("line", nil, "")
                self._empty_lines = self._empty_lines - 1
            end
        end
    end

    -- Prompts
    if string.find(line, self.login_prompt) then
        if self.send_ivars and self._ivars_sent == false then
            local bytes, errmsg = self:send(self:ivars_tostring())
            if errmsg ~= nil then
                return nil, errmsg
            else
                self._ivars_sent = true
            end

            -- Send another newline to get login prompt back.
            bytes, errmsg = self:send("")
            if errmsg ~= nil then
                return nil, errmsg
            end
        else
            self:run_callback("line", "login", line)
            self:run_callback("login", line)
        end
    elseif string.find(line, self.password_prompt) then
        self:run_callback("line", "password", line)
        self:run_callback("password", line)
    elseif string.find(line, self.prompt) then
        self:run_callback("line", "prompt", line)
        if not self.callbacks["prompt"] then return true end

        local ptime = string.match(line, self.prompt)
        self:run_callback("prompt", line, ptime)

    -- Authentication
    elseif string.find(line, "^A name should be at least three characters long") then
        self:run_callback("line", "handle_too_short", line)
        if self.callbacks["handle_too_short"] then
            self:run_callback("handle_too_short")
        else
            error("handle too short")
        end
    elseif string.find(line, "^Sorry, names may be at most 17 characters long") then
        self:run_callback("line", "handle_too_long", line)
        if self.callbacks["handle_too_long"] then
            self:run_callback("handle_too_long", line)
        else
            error("handle too long")
        end
    elseif string.find(line, "^Sorry, names can only consist of lower and upper case letters") then
        self:run_callback("line", "handle_not_alpha", line)
        if self.callbacks["handle_not_alpha"] then
            self:run_callback("handle_not_alpha", line)
        else
            error("handle not alpha")
        end
    elseif string.find(line, "^\"%w+\" is not a registered name") then
        self:run_callback("line", "handle_not_registered", line)
        if not self.callbacks["handle_not_registered"] then return true end

        local handle = string.match(line, "^\"(%w+)\"")
        self:run_callback("handle_not_registered", line, handle)
    elseif string.find(line, "^%*%*%*%* Invalid password! %*%*%*%*") then
        self:run_callback("line", "password_invalid", line)
        if self.callbacks["password_invalid"] then
            self:run_callback("password_invalid", line)
        else
            error("invalid password")
        end

    -- Session start
    elseif string.find(line, "^%*%*%*%* Starting FICS session as") then
        self:run_callback("line", "session_start", line)
        if not self.callbacks["session_start"] then return true end

        local handle, tags = string.match(line, "^%*%*%*%* Starting FICS session as (%a+)(.*)")
        self:run_callback("session_start", line, handle, totaglist(tags))
    elseif string.find(line, "^%d+ %(.*%) .*") then
        self:run_callback("line", "news", line)
        if not self.callbacks["news"] then return true end

        local no, date, subject = string.match(line, "^(%d+) %((.*)%) (.*)")

        no = tonumber(no)

        self:run_callback("news", line, no, date, subject)
    elseif string.find(line, "^You have %d+ messages? %(%d+ unread%)") then
        self:run_callback("line", "messages", line)
        if not self.callbacks["messages"] then return true end

        local total, unread = string.match(line, "^You have (%d+) messages? %((%d+) unread%)")

        total = tonumber(total)
        unread = tonumber(unread)

        self:run_callback("messages", line, total, unread)

    -- Notifications
    elseif string.find(line, "^Present company includes:") then
        self:run_callback("line", "notify_include", line)
        if not self.callbacks["notify_include"] then return true end

        local handles = string.match(line, "^Present company includes: ([%a ]+)%.")
        self:run_callback("notify_include", line, tolist(handles))
    elseif string.find(line, "^Your arrival was noted by:") then
        self:run_callback("line", "notify_note", line)
        if not self.callbacks["notify_note"] then return true end

        local handles = string.match(line, "^Your arrival was noted by: ([%a ]+)%.")
        self:run_callback("notify_note", line, tolist(handles))
    elseif string.find(line, "^Notification: %a+ has arrived and isn't on your notify list") then
        self:run_callback(line, "notify_arrive", line)
        if not self.callbacks["notify_arrive"] then return true end

        local handle = string.match(line, "^Notification: (%a+) has arrived")
        self:run_callback("notify_arrive", line, handle, false)
    elseif string.find(line, "^Notification: %a+ has arrived") then
        self:run_callback("line", "notify_arrive", line)
        if not self.callbacks["notify_arrive"] then return true end

        local handle = string.match(line, "^Notification: (%a+) has arrived")
        self:run_callback("notify_arrive", line, handle, true)
    elseif string.find(line, "^Notification: %a+ has departed and isn't on your notify list") then
        self:run_callback(line, "notify_arrive", line)
        if not self.callbacks["notify_depart"] then return true end

        local handle = string.match(line, "^Notification: (%a+) has departed")
        self:run_callback("notify_depart", line, handle, false)
    elseif string.find(line, "^Notification: %a+ has departed") then
        self:run_callback("line", "notify_depart", line)
        if not self.callbacks["notify_depart"] then return true end

        local handle = string.match(line, "^Notification: (%a+) has departed")
        self:run_callback("notify_depart", line, handle, true)

    -- Chat (may be wrapped by server.)
    elseif string.find(line, "^%a+[%u%*%(%)]* tells you:") then
        self._last_wrapping_group = "tell"

        self:run_callback("line", "tell", line)
        if not self.callbacks["tell"] then return true end

        local handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) tells you: (.*)")
        self:run_callback("tell", line, handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]*%(%d+%):") then
        self._last_wrapping_group = "chantell"

        self:run_callback("line", "chantell", line)
        if not self.callbacks["chantell"] then return true end

        local handle, tags, channel, message = string.match(line, "^(%a+)([%u%*%(%)]*)%((%d+)%): (.*)")
        channel = tonumber(channel)
        self:run_callback("chantell", line, handle, totaglist(tags), channel, message)
    elseif string.find(line, "^:") then
        self._last_wrapping_group = "qtell"

        self:run_callback("line", "qtell", line)
        if not self.callbacks["qtell"] then return true end

        local message = string.match(line, "^:(.*)")
        self:run_callback("qtell", line, message)
    elseif string.find(line, "^--> %a+[%u%*%(%)]*.*") then
        self._last_wrapping_group = "it"

        self:run_callback("line", "it", line)
        if not self.callbacks["it"] then return true end

        local handle, tags, message = string.match(line, "^--> (%a+)([%u%*%(%)]*)(.*)")
        self:run_callback("it", line, handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]* shouts:") then
        self._last_wrapping_group = "shout"

        self:run_callback("line", "shout", line)
        if not self.callbacks["shout"] then return true end

        local handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) shouts: (.*)")
        self:run_callback("shout", line, handle, totaglist(tags), message)
    elseif string.find(line, "^%a+[%u%*%(%)]* c%-shouts:") then
        self._last_wrapping_group = "cshout"

        self:run_callback("line", "cshout", line)
        if not self.callbacks["cshout"] then return true end

        local handle, tags, message = string.match(line, "^(%a+)([%u%*%(%)]*) c%-shouts: (.*)")
        self:run_callback("cshout", line, handle, totaglist(tags), message)
    elseif string.find(line, "^ +%*%*ANNOUNCEMENT%*%*") then
        self._last_wrapping_group = "announcement"

        self:run_callback("line", "announcement", line)
        if not self.callbacks["announcement"] then return true end

        local handle, message = string.match(line, "^ +%*%*ANNOUNCEMENT%*%* from (%a+): (.*)")
        self:run_callback("announcement", line, handle, message)
    elseif not self.ivars[IV_NOWRAP] and string.find(line, "^\\   ") then
        self:run_callback("line", "wrap", line)
        self:run_callback("wrap", line, self._last_wrapping_group)

    -- Challenge
    elseif string.find(line, "^%a+ updates the match request.") then
        self:run_callback("line", "challenge", line)
        if not self.callbacks["challenge"] then return true end
        self.__parse_chunk_game = { update = true }
    elseif string.find(line, "^Challenge:") or string.find(line, "^Issuing:") or string.find(line, "^Your game will be:") then
        self:run_callback("line", "challenge", line)
        if not self.callbacks["challenge"] then return true end

        local pattern, issued
        if string.find(line, "^Challenge:") then
            pattern = "^Challenge: "
            issued = false
        elseif string.find(line, "^Issuing:") then
            pattern = "^Issuing: "
            issued = true
        else
            pattern = "^Your game will be:"
        end
        pattern = pattern .. "(%a+) %(([%dEP-]+)%) ?(%[?%a*%]?) (%a+) %(([%dEP-]+)%) (%a+) (%a+) (%d+) (%d+)(.*)%."

        local handle1, rating1, colour, handle2, rating2, rated, gtype, time, inc, chunk = string.match(line, pattern)

        -- if rating1 == "----" then rating1 = nil end
        -- if rating2 == "----" then rating2 = nil end

        if rated == "rated" then rated = true
        elseif rated == "unrated" then rated = false
        else error("unknown rated value '" .. rated .. "'") end

        if colour ~= nil then
            colour = string.match(colour, "%[(%a+)%]")
        end

        if chunk ~= "" then
            if string.find(chunk, "^ Loaded from wild/") then
                wildtype = string.match(chunk, "^ Loaded from wild/(%d+)")
            end
        end

        self.__parse_chunk_player1 = { handle = handle1, rating = rating1, colour = colour }
        self.__parse_chunk_player2 = { handle = handle2, rating = rating2 }

        if self.__parse_chunk_game == nil then
            self.__parse_chunk_game = { update = false, type = gtype,
                wtype = wildtype, rated = rated, time = tonumber(time),
                inc = tonumber(inc), issued = issued }
        else
            self.__parse_chunk_game.type = gtype
            self.__parse_chunk_game.wtype = wildtype
            self.__parse_chunk_game.rated = rated
            self.__parse_chunk_game.time = tonumber(inc)
            self.__parse_chunk_game.inc = tonumber(inc)
            self.__parse_chunk_game.issued = issued
        end

        if rated == false then
            -- Don't wait for the next line to call the callback
            self:run_callback("challenge", line, self.__parse_chunk_player1,
                self.__parse_chunk_player2, self.__parse_chunk_game)
            self.__parse_chunk_game = nil
            self.__parse_chunk_player1 = nil
            self.__parse_chunk_player2 = nil
        end
    elseif string.find(line, "^Your %a+ rating will change:") then
        self:run_callback("line", "challenge", line)
        if not self.callbacks["challenge"] then return true end

        self.__parse_chunk_game.win,
        self.__parse_chunk_game.draw,
        self.__parse_chunk_game.loss = string.match(line,
            "^Your %a+ rating will change:  Win: %+?([%d-%.]+),  Draw: %+?([%d-%.]+),  Loss: %+?([%d-%.]+)")
        self.__parse_chunk_game.win = tonumber(self.__parse_chunk_game.win)
        self.__parse_chunk_game.draw = tonumber(self.__parse_chunk_game.draw)
        self.__parse_chunk_game.loss = tonumber(self.__parse_chunk_game.loss)
    elseif string.find(line, "^Your new RD will be") then
        self:run_callback("line", "challenge", line)
        -- Don't return here because parse chunks must be set to nil.
        -- if not self.callbacks["challenge"] then return true end

        self.__parse_chunk_game.newrd = tonumber(string.match(line, "^Your new RD will be ([%d%.]+)"))
        self:run_callback("challenge", line, self.__parse_chunk_player1,
            self.__parse_chunk_player2, self.__parse_chunk_game)
        self.__parse_chunk_game = nil
        self.__parse_chunk_player1 = nil
        self.__parse_chunk_player2 = nil

    -- Bughouse
    elseif string.find(line, "^%a+ offers to be your bughouse partner") then
        self:run_callback("line", "partner", line)
        if not self.callbacks["partner"] then return true end

        local handle = string.match(line, "^(%a+) ")
        self:run_callback("partner", line, handle)

    -- Game start/end
    elseif string.find(line, "^{Game %d+ %(%a+ vs%. %a+%) [^}]+} [01%-%*]+") then
        self:run_callback("line", "game_end", line)
        if not self.callbacks["game_end"] then return true end

        local gameno, whandle, bhandle, reason, result = string.match(line, "^{Game (%d+) %((%a+) vs%. (%a+)%) ([^}]+)} ([01%-%*]+)")
        gameno = tonumber(gameno)
        self:run_callback("game_end", line, gameno, whandle, bhandle, reason, result)

    elseif string.find(line, "^{Game %d+ %(%a+ vs%. %a+%) [^}]+}") then
        self:run_callback("line", "game_start", line)
        if not self.callbacks["game_start"] then return true end

        local gameno, whandle, bhandle, reason = string.match(line, "^{Game (%d+) %((%a+) vs%. (%a+)%) ([^}]+)}")
        gameno = tonumber(gameno)
        self:run_callback("game_start", line ,gameno, whandle, bhandle, reason)

    -- Style 12
    elseif string.find(line, "^<12>") then
        self:run_callback("line", "style12", line)
        if not self.callbacks["style12"] then return true end

        local pattern = "^<12> " ..
            "([%a%-]+) ([%a%-]+) ([%a%-]+) ([%a%-]+) " ..
            "([%a%-]+) ([%a%-]+) ([%a%-]+) ([%a%-]+) " ..
            "([BW]) ([%d%l-]+) " ..
            "([01]) ([01]) ([01]) ([01]) " ..
            "(%d+) (%d+) (%a+) (%a+) " ..
            "([%d%-]+) (%d+) (%d+) " ..
            "(%d+) (%d+) ([%d%-]+) ([%d%-]+) " ..
            "(%d+) ([%a%d%p]+) "

        if self.ivars[IV_MS] then
            pattern = pattern .. "%((%d+:%d+%.%d+)%) "
        else
            pattern = pattern .. "%((%d+:%d+)%) "
        end

        pattern = pattern .. "([%a%d%p]+) ([01])"

        local last_time
        local m = {}
        m.rank8, m.rank7, m.rank6, m.rank5,
        m.rank4, m.rank3, m.rank2, m.rank1,
        m.tomove, m.doublepawn,
        m.wcastle, m.wlcastle, m.bcastle, m.blcastle,
        m.lastirr, m.gameno, m.wname, m.bname,
        m.relation, m.itime, m.inc,
        m.wstrength, m.bstrength, m.wtime, m.btime,
        m.moveno, m.llastmove, last_time, m.lastmove,
        m.flip = string.match(line, pattern)

        if self.ivars[IV_MS] then
            m.lastmin, m.lastsec, m.lastms = string.match(last_time, "(%d+):(%d+)%.(%d+)")
            m.lastms = tonumber(m.lastms)
        else
            m.lastmin, m.lastsec = string.match(last_time, "(%d+):(%d+)")
        end

        -- Convert to boolean
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

        m.doublepawn = tonumber(m.doublepawn)
        m.lastirr = tonumber(m.lastirr)
        m.gameno = tonumber(m.gameno)
        m.relation = tonumber(m.relation)
        m.itime = tonumber(m.itime)
        m.inc = tonumber(m.inc)
        m.wstrength = tonumber(m.wstrength)
        m.bstrength = tonumber(m.bstrength)
        m.wtime = tonumber(m.wtime)
        m.btime = tonumber(m.btime)
        m.moveno = tonumber(m.moveno)
        m.lastmin = tonumber(m.lastmin)
        m.lastsec = tonumber(m.lastsec)

        self:run_callback("style12", line, m)

    -- Game start, end
    elseif string.find(line, "^{Game (%d+) %((%a+) vs. (%a+)%) (.*)} ([%*%d%p]+)") then
        self:run_callback("line", "game_end", line)
        if not self.callbacks["game_end"] then return true end

        local gameno, wname, bname, reason, result = string.match(line,
            "^{Game (%d+) %((%a+) vs. (%a+)%) (.*)} ([%*%d%p]+)")
        gameno = tonumber(gameno)
        self:run_callback("game_end", gameno, wname, bname, reason, result)
    elseif string.find(line, "^{Game (%d+) %((%a+) vs. (%a+)%) (.*)}") then
        self:run_callback("line", "game_start", line)
        if not self.callbacks["game_start"] then return true end

        local gameno, wname, bname, reason = string.match(line,
            "^{Game (%d+) %((%a+) vs. (%a+)%) (.*)}")
        gameno = tonumber(gameno)
        self:run_callback("game_start", line, gameno, wname, bname, reason)

    -- Offers
    elseif string.find(line, "^%a+ offers you a draw%.") then
        self:run_callback("line", "offer_draw", line)
        if not self.callbacks["offer_draw"] then return true end

        local handle = string.match(line, "^(%a+) offers you a draw%.")
        self:run_callback("offer_draw", line, handle)

    elseif string.find(line, "^%a+ accepts the draw request") then
        self:run_callback("line", "draw_accept", line)
        if not self.callbacks["draw_accept"] then return true end

        local handle = string.match(line, "^(%a+) accepts the draw request")
        self:run_callback("draw_accept", line, handle)

    elseif string.find(line, "^%a+ declines the draw request") then
        self:run_callback("line", "draw_decline", line)
        if not self.callbacks["draw_decline"] then return true end

        local handle = string.match(line, "^(%a+) declines the draw request")
        self:run_callback("draw_decline", line, handle)

    elseif string.find(line, "^%a+ would like to abort the game") then
        self:run_callback("line", "offer_abort", line)
        if not self.callbacks["offer_abort"] then return true end

        local handle = string.match(line, "^(%a+) would like to abort the game")
        self:run_callback("offer_abort", line, handle)

    elseif string.find(line, "^%a+ accepts the abort request") then
        self:run_callback("line", "abort_accept", line)
        if not self.callbacks["abort_accept"] then return true end

        local handle = string.match(line, "^(%a+) accepts the abort request")
        self:run_callback("abort_accept", line, handle)

    elseif string.find(line, "^%a+ declines the abort request") then
        self:run_callback("line", "abort_decline", line)
        if not self.callbacks["abort_decline"] then return true end

        local handle = string.match(line, "^(%a+) declines the abort request")
        self:run_callback("abort_decline", line, handle)

    elseif string.find(line, "^%a+ would like to adjourn the game") then
        self:run_callback("line", "offer_adjourn", line)
        if not self.callbacks["offer_adjourn"] then return true end

        local handle = string.match(line, "^(%a+) would like to adjourn the game")
        self:run_callback("offer_adjourn", line, handle)

    elseif string.find(line, "^%a+ accepts the adjourn request") then
        self:run_callback("line", "adjourn_accept", line)
        if not self.callbacks["adjourn_accept"] then return true end

        local handle = string.match(line, "^(%a+) accepts the adjourn request")
        self:run_callback("adjourn_accept", line, handle)

    elseif string.find(line, "^%a+ declines the adjourn request") then
        self:run_callback("line", "adjourn_decline", line)
        if not self.callbacks["adjourn_decline"] then return true end

        local handle = string.match(line, "^(%a+) declines the adjourn request")
        self:run_callback("adjourn_decline", line, handle)

    elseif string.find(line, "^%a+ would like to take back %d+ half move") then
        self:run_callback("line", "offer_takeback", line)
        if not self.callbacks["offer_takeback"] then return true end

        local handle, halfmoves = string.match(line, "^(%a+) would like to take back (%d+) half move")
        halfmoves = tonumber(halfmoves)
        self:run_callback("offer_takeback", line, handle, halfmoves)

    elseif string.find(line, "^%a+ accepts the takeback request") then
        self:run_callback("line", "takeback_accept", line)
        if not self.callbacks["takeback_accept"] then return true end

        local handle = string.match(line, "^(%a+) accepts the takeback request")
        self:run_callback("takeback_accept", line, handle)

    elseif string.find(line, "^%a+ declines the takeback request") then
        self:run_callback("line", "takeback_decline", line)
        if not self.callbacks["takeback_decline"] then return true end

        local handle = string.match(line, "^(%a+) declines the takeback request")
        self:run_callback("takeback_decline", line, handle)

    -- Seeks
    elseif self.ivars[IV_SEEKINFO] and string.find(line, "^<s>") then
        self:run_callback("line", "seek", line)
        if not self.callbacks["style12"] then return true end

        local seek = {}
        seek.index, seek.from, seek.titles, seek.rating, seek.time,
        seek.increment, seek.rated, seek.type, seek.colour, seek.rating_range,
        seek.automatic, seek.formula_checked = string.match(line,
            "^<s> (%d+) w=(%a+) ti=(%d+) rt=(%d+[ EP]) t=(%d+) " ..
            "i=(%d+) r=([ru]) tp=(%a+) c=([%?WB]) rr=(%d+-%d+) " ..
            "a=([ft]) f=([ft])")

        seek.index = tonumber(seek.index)
        seek.titles = tonumber(seek.titles)
        seek.time = tonumber(seek.time)
        seek.increment = tonumber(seek.increment)

        -- Convert to booleans
        if seek.rated == "r" then
            seek.rated = true
        else
            seek.rated = false
        end

        if seek.automatic == "t" then
            seek.automatic = true
        else
            seek.automatic = false
        end

        if seek.formula_checked == "t" then
            seek.formula_checked = true
        else
            seek.formula_checked = false
        end

        self:run_callback("seek", line, seek)
    elseif (self.ivars[IV_SEEKINFO] or self.ivars[IV_SEEKREMOVE]) and string.find(line, "^<sr>") then
        self:run_callback("line", "seekremove", line)
        if not self.callbacks["seekremove"] then return true end

        local indexes = {}

        for index in string.gmatch(line, "%d+") do
            table.insert(indexes, tonumber(index))
        end

        self:run_callback("seekremove", line, indexes)
    elseif self.ivars[IV_SEEKINFO] and string.find(line, "^<sc>") then
        self:run_callback("line", "seekclear", line)
        self:run_callback("seekclear", line)

    -- Telnet
    elseif line == IAC_WILL_ECHO then
        self:run_callback("line", "iacwillecho", line)
        self:run_callback("iacwillecho", line)

    elseif line == IAC_WONT_ECHO then
        self:run_callback("line", "iacwontecho", line)
        self:run_callback("iacwontecho", line)

    -- The rest is unknown
    else
        self:run_callback("line", nil, line)
    end

    return true
end --}}}
function client:loop(times) --{{{
    local times = times or 0

    if 0 >= times then
        while true do
            local line, errmsg = self:recvline()
            if line == nil then
                if errmsg ~= "internal" and errmsg ~= "timeout" then
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
                if errmsg ~= "internal" and errmsg ~= "timeout" then
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

