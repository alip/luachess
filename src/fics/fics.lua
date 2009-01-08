#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 tw=80 fdm=marker:
--[[
  Copyright (c) 2008, 2009 Ali Polatel <polatel@gmail.com>

  This file is part of LuaChess. LuaChess is free software; you can redistribute
  it and/or modify it under the terms of the GNU General Public License version
  2, as published by the Free Software Foundation.

  LuaChess is distributed in the hope that it will be useful, but WITHOUT ANY
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
local socket = require "socket"
require "chess.fics.utils"
require "chess.fics.parser"
local utils = chess.fics.utils
local parser = chess.fics.parser
--}}}
--{{{ Variables
module "chess.fics"
_VERSION = utils._VERSION

client = {}

--{{{ Telnet
local CR = "\r"
local LF = "\n"
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
ivar_to_setting = {
    IV_COMPRESSMOVE = "compressmove",
    IV_AUDIOCHAT = "audiochat",
    IV_SEEKREMOVE = "seekremove",
    IV_DEFPROMPT = "defprompt",
    IV_LOCK = "lock",
    IV_STARTPOS = "startpos",
    IV_BLOCK = "block",
    IV_GAMEINFO = "gameinfo",
    IV_XDR = "xdr",
    IV_PENDINFO = "pendinfo",
    IV_GRAPH = "graph",
    IV_SEEKINFO = "seekinfo",
    IV_EXTASCII = "extascii",
    IV_NOHILIGHT = "nohilight",
    IV_VT_HILIGHT = "vt_hilight",
    IV_SHOWSERVER = "showserver",
    IV_PIN = "pin",
    IV_MS = "ms",
    IV_PINGINFO = "pinginfo",
    IV_BOARDINFO = "boardinfo",
    IV_EXTUSERINFO = "extuserinfo",
    IV_SEEKCA = "seekca",
    IV_SHOWOWNSEEK = "showownseek",
    IV_PREMOVE = "premove",
    IV_SMARTMOVE = "smartmove",
    IV_MOVECASE = "movecase",
    IV_SUICIDE = "suicide",
    IV_CRAZYHOUSE = "crazyhouse",
    IV_LOSERS = "losers",
    IV_WILDCASTLE = "wildcastle",
    IV_FR = "fr",
    IV_NOWRAP = "nowrap",
    IV_ALLRESULTS = "allresults",
    IV_OBSPING = "obsping",
    IV_SINGLEBOARD = "singleboard",
}
--}}}
--}}}
--{{{ Utility functions
--{{{ Helper functions for tags
function tag_concat(t)
    assert(type(t) == "table", "argument is not a table")
    local tstr = ""
    for i, tag in ipairs(t) do
        assert(type(tag) == "string",
            "tag table element at index " .. i .. " not a string")
        tstr = tstr .. "(" .. tag .. ")"
    end
    return tstr
end --}}}
--}}}
--{{{ fics.client functions
function client:new(argtable) --{{{
    assert(type(argtable) == "table", "argument is not a table")

    local instance = {
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
function client:set(ivar, boolean) --{{{
    assert(0 < ivar and ivar < IVARS_COUNT, "invalid interface variable")
    if self.sock ~= nil then
        if boolean then
            self.sock:send("iset " .. ivar_to_setting[ivar] .. " 1")
        else
            self.sock:send("iset " .. ivar_to_setting[ivar] .. " 0")
        end
    end
    self.ivars[ivar] = boolean
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
        local initstr, errmsg = utils.timeseal_init_string()
        if initstr == nil then return nil, errmsg end

        local bytes, errmsg = self:send(initstr)
        if errmsg ~= nil then return nil, errmsg end
    end

    self.sock:settimeout(0)
    self.sock:setoption("tcp-nodelay", true)
    return true
end --}}}
function client:disconnect() --{{{
    assert(self.sock ~= nil, "not connected")

    self.sock:close()
    self.sock = nil

    self._ivars_sent = false
    self._last_sent = 0
    self._seen_magicgstr = false
    self._linebuf = ""
    self._empty_lines = 0
    self._got_gresponse = false
    self._last_wrapping_group = nil
end --}}}
function client:send(data) --{{{
    assert(self.sock ~= nil, "not connected")

    if self.timeseal then
        data, errmsg = utils.timeseal_encode(data)
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

            if parser.prompts:match(self._linebuf) then
                break
            end
        end
    end

    local line = self._linebuf
    self._linebuf = ""
    if self.timeseal and string.find(line, utils.TIMESEAL_MAGICGSTR) then
        self._got_gresponse = true
        self:send(utils.TIMESEAL_GRESPONSE)
        return nil, "internal"
    else
        return line
    end
end --}}}
function client:register_callback(group, func) --{{{
    assert(type(func) == "function" or type(func) == "thread",
        "callback is neither a function nor a coroutine.")
    local callback_index = { group = group }
    if self.callbacks[group] == nil then
        callback_index.key = 1
        self.callbacks[group] = { func }
    else
        callback_index.key = #self.callbacks[group] + 1
        table.insert(self.callbacks[group], func)
    end
    return callback_index
end --}}}
function client:remove_callback(index) --{{{
    assert(type(index) == "table", "invalid callback index")
    assert(index.group, "no group data in callback index")
    assert(type(index.key) == "number", "bad key in callback index")

    if self.callbacks[index.group] then
        if self.callbacks[index.group][index.key] then
            table.remove(self.callbacks[index.group], index.key)
            return true
        end
    end
    return false
end --}}}
function client:run_callback(group, ...) --{{{
    if self.callbacks[group] == nil then self.callbacks[group] = {} end
    assert(type(self.callbacks[group]) == "table", "callback group not table")

    for index, func in ipairs(self.callbacks[group]) do
        local status, value
        if type(func) == "function" then
            status, value = pcall(func, self, unpack(arg))
        elseif type(func) == "thread" then
            status, value = coroutine.resume(func, self, unpack(arg))
        else
            error "callback is neither a function nor a coroutine."
        end

        if not status then
            if self.sock ~= nil then self:disconnect() end
            error(string.format("callback failed, group: %s index: %d\n%s",
                group, index, value))
        end
        if value == false then
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

    local parsed = parser.p:match(line)

    if not parsed then
        -- Wrap
        if not self.ivars[IV_NOWRAP] and string.find(line, "^\\   ") then
            self:run_callback("line", "wrap", line)
            self:run_callback("wrap", line, self._last_wrapping_group)

        -- The rest is unknown
        else
            self._last_wrapping_group = nil
            self:run_callback("line", nil, line)
        end

    -- Prompts
    elseif parsed[1] == parser.PROMPT_LOGIN then
        if self.send_ivars and self._ivars_sent == false then
            local bytes, errmsg = self:send(self:ivars_tostring())
            if errmsg ~= nil then
                return nil, errmsg
            else
                self._ivars_sent = true
            end

            -- Send another newline to get login prompt back.
            bytes, errmsg = self:send ""
            if errmsg ~= nil then
                return nil, errmsg
            end
        else
            self:run_callback("line", "login", line)
            self:run_callback("login", line)
        end
        return true
    elseif parsed[1] == parser.PROMPT_PASSWORD then
        self:run_callback("line", "password", line)
        self:run_callback("password", line)
        return true
    elseif parsed[1] == parser.PROMPT_SERVER then
        self:run_callback("line", "prompt", line)
        self:run_callback("prompt", line, parsed[2])
        return true

    -- Authentication
    elseif parsed[1] == parser.HANDLE_TOO_SHORT then
        self:run_callback("line", "handle_too_short", line)
        if self.callbacks["handle_too_short"] then
            self:run_callback("handle_too_short")
        else
            error "handle too short"
        end
    elseif parsed[1] == parser.HANDLE_TOO_LONG then
        self:run_callback("line", "handle_too_long", line)
        if self.callbacks["handle_too_long"] then
            self:run_callback("handle_too_long", line)
        else
            error "handle too long"
        end
    elseif parsed[1] == parser.HANDLE_NOT_ALPHA then
        self:run_callback("line", "handle_not_alpha", line)
        if self.callbacks["handle_not_alpha"] then
            self:run_callback("handle_not_alpha", line)
        else
            error "handle not alpha"
        end
    elseif parsed[1] == parser.HANDLE_BANNED then
        self:run_callback("line", "handle_banned", line)
        if self.callbacks["handle_banned"] then
            self:run_callback("handle_banned", line, parsed[2])
        else
            error("handle '" .. parsed[2] .. "' banned")
        end
    elseif parsed[1] == parser.HANDLE_NOT_REGISTERED then
        self:run_callback("line", "handle_not_registered", line)
        self:run_callback("handle_not_registered", line, parsed[2])
    elseif parsed[1] == parser.PASSWORD_INVALID then
        self:run_callback("line", "password_invalid", line)
        if self.callbacks["password_invalid"] then
            self:run_callback("password_invalid", line)
        else
            error "invalid password"
        end
    elseif parsed[1] == parser.PRESS_RETURN then
        self:run_callback("line", "press_return", line)
        if self.callbacks["press_return"] then
            self:run_callback("press_return", line, parsed[2])
        else
            self:send""
        end

    -- Session start
    elseif parsed[1] == parser.WELCOME then
        self:run_callback("line", "session_start", line)
        self:run_callback("session_start", line, parsed[2], parsed[3])

    elseif parsed[1] == parser.NEWS then
        self:run_callback("line", "news", line)
        self:run_callback("news", line, parsed[2], parsed[3], parsed[4])

    elseif parsed[1] == parser.MESSAGES then
        self:run_callback("line", "messages", line)
        self:run_callback("messages", line, parsed[2], parsed[3])

    -- Notifications
    elseif parsed[1] == parser.NOTIFY_INCLUDE then
        self:run_callback("line", "notify_include", line)
        self:run_callback("notify_include", line, parsed[2])

    elseif parsed[1] == parser.NOTIFY_NOTE then
        self:run_callback("line", "notify_note", line)
        self:run_callback("notify_note", line, parsed[2])

    elseif parsed[1] == parser.NOTIFY_ARRIVE then
        self:run_callback(line, "notify_arrive", line)
        self:run_callback("notify_arrive", line, parsed[2], parsed[3])

    elseif parsed[1] == parser.NOTIFY_DEPART then
        self:run_callback(line, "notify_depart", line)
        self:run_callback("notify_depart", line, parsed[2], parsed[3])

    -- Chat (may be wrapped by server.)
    elseif parsed[1] == parser.TELL then
        self._last_wrapping_group = "tell"

        self:run_callback("line", "tell", line)
        self:run_callback("tell", line, parsed[2], parsed[3], parsed[4])

    elseif parsed[1] == parser.CHANTELL then
        self._last_wrapping_group = "chantell"

        self:run_callback("line", "chantell", line)
        self:run_callback("chantell", line, parsed[2], parsed[3], parsed[4],
            parsed[5])

    elseif parsed[1] == parser.QTELL then
        self._last_wrapping_group = "qtell"

        self:run_callback("line", "qtell", line)
        self:run_callback("qtell", line, parsed[2])

    elseif parsed[1] == parser.IT then
        self._last_wrapping_group = "it"

        self:run_callback("line", "it", line)
        self:run_callback("it", line, parsed[1], parsed[2], parsed[3])

    elseif parsed[1] == parser.SHOUT then
        self._last_wrapping_group = "shout"

        self:run_callback("line", "shout", line)
        self:run_callback("shout", line, parsed[1], parsed[2], parsed[3])

    elseif parsed[1] == parser.CSHOUT then
        self._last_wrapping_group = "cshout"

        self:run_callback("line", "cshout", line)
        self:run_callback("cshout", line, parsed[1], parsed[2], parsed[3])

    elseif parsed[1] == parser.ANNOUNCEMENT then
        self._last_wrapping_group = "announcement"

        self:run_callback("line", "announcement", line)
        self:run_callback("announcement", line, parsed[1], parsed[2])

    elseif parsed[1] == parser.KIBITZ then
        self._last_wrapping_group = "kibitz"

        self:run_callback("line", "kibitz", line)
        self:run_callback("kibitz", line, parsed[1], parsed[2], parsed[3],
            parsed[4], parsed[5])

    elseif parsed[1] == parser.WHISPER then
        self._last_wrapping_group = "whisper"

        self:run_callback("line", "whisper", line)
        self:run_callback("whisper", line, parsed[1], parsed[2], parsed[3],
            parsed[4], parsed[5])

    -- Challenge
    elseif parsed[1] == parser.CHALLENGE_UPDATE then
        self:run_callback("line", "challenge", line)
        if not self.callbacks["challenge"] then return true end
        self.__parse_chunk_game_update = true

    elseif parsed[1] == parser.MATCH_REQUEST then
        self:run_callback("line", "challenge", line)

        if self.__parse_chunk_game_update then
            parsed[2].update = true
        else
            parsed[2].update = false
        end
        self.__parse_chunk_game_update = nil

        if parsed[2].rated == false then
            -- Don't wait for the next line to call the callback
            self:run_callback("challenge", line, parsed[3], parsed[4],
                parsed[2])
        else
            self.__parse_chunk_game = parsed[2]
            self.__parse_chunk_player1 = parsed[3]
            self.__parse_chunk_player2 = parsed[4]
        end

    elseif parsed[1] == parser.RATING_CHANGE then
        self:run_callback("line", "challenge", line)
        if not self.callbacks["challenge"] then return true end

        self.__parse_chunk_game.win = parsed[3]
        self.__parse_chunk_game.draw = parsed[4]
        self.__parse_chunk_game.loss = parsed[5]

    elseif parsed[1] == parser.NEWRD then
        self:run_callback("line", "challenge", line)
        -- Don't return here because parse chunks must be set to nil.
        -- if not self.callbacks["challenge"] then return true end

        self.__parse_chunk_game.newrd = parsed[2]
        self:run_callback("challenge", line, self.__parse_chunk_player1,
            self.__parse_chunk_player2, self.__parse_chunk_game)
        self.__parse_chunk_game = nil
        self.__parse_chunk_player1 = nil
        self.__parse_chunk_player2 = nil

    -- Bughouse
    elseif parsed[1] == parser.PARTNER_OFFER then
        self:run_callback("line", "partner", line)
        self:run_callback("partner", line, parsed[2])

    -- Game start/end
    elseif parsed[1] == parser.GAME_START then
        self:run_callback("line", "game_start", line)
        self:run_callback("game_start", line, parsed[2], parsed[3], parsed[4],
            parsed[5])

    elseif parsed[1] == parser.GAME_END then
        self:run_callback("line", "game_end", line)
        self:run_callback("game_end", line, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6])

    -- Style 12
    elseif parsed[1] == parser.STYLE12 then
        self:run_callback("line", "style12", line)
        self:run_callback("style12", line, parsed[2])

    -- Offers
    elseif parsed[1] == parser.DRAW then
        self:run_callback("line", "offer_draw", line)
        self:run_callback("offer_draw", line, parsed[2])

    elseif parsed[1] == parser.DRAW_ACCEPT then
        self:run_callback("line", "draw_accept", line)
        self:run_callback("draw_accept", line, parsed[2])

    elseif parsed[1] == parser.DRAW_DECLINE then
        self:run_callback("line", "draw_decline", line)
        self:run_callback("draw_decline", line, parsed[2])

    elseif parsed[1] == parser.ABORT then
        self:run_callback("line", "offer_abort", line)
        self:run_callback("offer_abort", line, parsed[2])

    elseif parsed[1] == parser.ABORT_ACCEPT then
        self:run_callback("line", "abort_accept", line)
        self:run_callback("abort_accept", line, parsed[2])

    elseif parsed[1] == parser.ABORT_DECLINE then
        self:run_callback("line", "abort_decline", line)
        self:run_callback("abort_decline", line, parsed[2])

    elseif parsed[1] == parser.ADJOURN then
        self:run_callback("line", "offer_adjourn", line)
        self:run_callback("offer_adjourn", line, parsed[2])

    elseif parsed[1] == parser.ADJOURN_ACCEPT then
        self:run_callback("line", "adjourn_accept", line)
        self:run_callback("adjourn_accept", line, parsed[2])

    elseif parsed[1] == parser.ADJOURN_DECLINE then
        self:run_callback("line", "adjourn_decline", line)
        self:run_callback("adjourn_decline", line, parsed[2])

    elseif parsed[1] == parser.TAKEBACK then
        self:run_callback("line", "offer_takeback", line)
        self:run_callback("offer_takeback", line, parsed[2], parsed[3])

    elseif parsed[1] == parser.TAKEBACK_ACCEPT then
        self:run_callback("line", "takeback_accept", line)
        self:run_callback("takeback_accept", line, parsed[2])

    elseif parsed[1] == parser.TAKEBACK_DECLINE then
        self:run_callback("line", "takeback_decline", line)
        self:run_callback("takeback_decline", line, parsed[2])

    -- Seeks
    elseif parsed[1] == parser.SEEKINFO then
        self:run_callback("line", "seek", line)
        self:run_callback("seek", line, parsed[2])

    elseif parsed[1] == parser.SEEKREMOVE then
        self:run_callback("line", "seekremove", line)
        self:run_callback("seekremove", line, parsed[2])

    elseif parsed[1] == parser.SEEKCLEAR then
        self:run_callback("line", "seekclear", line)
        self:run_callback("seekclear", line)

    -- Examined/Observed
    elseif parsed[1] == parser.MOVE then
        self:run_callback("line", "move", line)
        self:run_callback("move", line, parsed[2], parsed[3], parsed[4])

    elseif parsed[1] == parser.EXAMINING then
        self:run_callback("line", "examining", line)
        self:run_callback("examining", line, parsed[2])

    -- Telnet
    elseif parsed[1] == parser.IAC_WILL_ECHO  then
        self:run_callback("line", "iacwillecho", line)
        self:run_callback("iacwillecho", line)

    elseif parsed[1] == parser.IAC_WONT_ECHO then
        self:run_callback("line", "iacwontecho", line)
        self:run_callback("iacwontecho", line)
    else
        error("unhandled parser id " .. parsed[1])
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

