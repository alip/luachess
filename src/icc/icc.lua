#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
--[[
  Copyright (c) 2009 Ali Polatel <polatel@gmail.com>

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

--{{{ Grab environment we need
local assert = assert
local error = error
local ipairs = ipairs
local pcall = pcall
local setmetatable = setmetatable
local type = type
local unpack = unpack

local os = os
local string = string
local socket = require "socket"
require "chess.icc.parser"
local parser = chess.icc.parser
--}}}
--{{{ Variables
--- Lua module to interact with the Internet Chess Club.<br />
-- Requires <a href="http://www.tecgraf.puc-rio.br/~diego/professional/luasocket/">luasocket</a>
-- and <a href="http://www.inf.puc-rio.br/~roberto/lpeg.html">LPeg</a>.
module "chess.icc"
_VERSION = 0.02

client = {}

--{{{ Telnet
CR = "\r"
LF = "\n"
RCTE = string.char(7)
EOR = string.char(25)
--}}}
--{{{ ICC level 2 codes
DG_WHO_AM_I = 0
DG_PLAYER_ARRIVED = 1
DG_PLAYER_LEFT = 2
DG_BULLET = 3
DG_BLITZ = 4
DG_STANDARD = 5
DG_WILD = 6
DG_BUGHOUSE = 7
DG_TIMESTAMP = 8
DG_TITLES = 9
DG_OPEN = 10
DG_STATE = 11
DG_GAME_STARTED = 12
DG_GAME_RESULT = 13
DG_EXAMINED_GAME_IS_GONE = 14
DG_MY_GAME_STARTED = 15
DG_MY_GAME_RESULT = 16
DG_MY_GAME_ENDED = 17
DG_STARTED_OBSERVING = 18
DG_STOP_OBSERVING = 19
DG_PLAYERS_IN_MY_GAME = 20
DG_OFFERS_IN_MY_GAME = 21
DG_TAKEBACK = 22
DG_BACKWARD = 23
DG_SEND_MOVES = 24
DG_MOVE_LIST = 25
DG_KIBITZ = 26
DG_PEOPLE_IN_MY_CHANNEL = 27
DG_CHANNEL_TELL = 28
DG_MATCH = 29
DG_MATCH_REMOVED = 30
DG_PERSONAL_TELL = 31
DG_SHOUT = 32
DG_MOVE_ALGEBRAIC = 33
DG_MOVE_SMITH = 34
DG_MOVE_TIME = 35
DG_MOVE_CLOCK = 36
DG_BUGHOUSE_HOLDINGS = 37
DG_SET_CLOCK = 38
DG_FLIP = 39
DG_ISOLATED_BOARD = 40
DG_REFRESH = 41
DG_ILLEGAL_MOVE = 42
DG_MY_RELATION_TO_GAME = 43
DG_PARTNERSHIP = 44
DG_SEES_SHOUTS = 45
DG_CHANNELS_SHARED = 46
DG_MY_VARIABLE = 47
DG_MY_STRING_VARIABLE = 48
DG_JBOARD = 49
DG_SEEK = 50
DG_SEEK_REMOVED = 51
DG_MY_RATING = 52
DG_SOUND = 53
DG_PLAYER_ARRIVED_SIMPLE = 55
DG_MSEC = 56
DG_BUGHOUSE_PASS = 57
DG_IP = 58
DG_CIRCLE = 59
DG_ARROW = 60
DG_MORETIME = 61
DG_PERSONAL_TELL_ECHO = 62
DG_SUGGESTION = 63
DG_NOTIFY_ARRIVED = 64
DG_NOTIFY_LEFT = 65
DG_NOTIFY_OPEN = 66
DG_NOTIFY_STATE = 67
DG_MY_NOTIFY_LIST = 68
DG_LOGIN_FAILED = 69
DG_FEN = 70
DG_TOURNEY_MATCH = 71
DG_GAMELIST_BEGIN = 72
DG_GAMELIST_ITEM = 73
DG_IDLE = 74
DG_ACK_PING = 75
DG_RATING_TYPE_KEY = 76
DG_GAME_MESSAGE = 77
DG_UNACCENTED = 78
DG_STRINGLIST_BEGIN = 79
DG_STRINGLIST_ITEM = 80
DG_DUMMY_RESPONSE = 81
DG_CHANNEL_QTELL = 82
DG_PERSONAL_QTELL = 83
DG_SET_BOARD = 84
DG_MATCH_ASSESSMENT = 85
DG_LOG_PGN = 86
DG_NEW_MY_RATING = 87
DG_LOSERS = 88
DG_UNCIRCLE = 89
DG_UNARROW = 90
DG_WSUGGEST = 91
DG_TEMPORARY_PASSWORD = 93
DG_MESSAGELIST_BEGIN = 94
DG_MESSAGELIST_ITEM = 95
DG_LIST = 96
DG_SJI_AD = 97
DG_RETRACT = 99
DG_MY_GAME_CHANGE = 100
DG_POSITION_BEGIN = 101
DG_TOURNEY = 103
DG_REMOVE_TOURNEY = 104
DG_DIALOG_START = 105
DG_DIALOG_DATA = 106
DG_DIALOG_DEFAULT = 107
DG_DIALOG_END = 108
DG_DIALOG_RELEASE = 109
DG_POSITION_BEGIN2 = 110
DG_PAST_MOVE = 111
DG_PGN_TAG = 112
DG_IS_VARIATION = 113
DG_PASSWORD = 114
DG_WILD_KEY = 116
DG_SWITCH_SERVERS = 120
DG_CRAZYHOUSE = 121
DG_SET2 = 124
DG_FIVEMINUTE = 125
DG_ONEMINUTE = 126
DG_MUGSHOT = 128
DG_TRANSLATIONOKAY = 129
DG_UID = 131
DG_KNOWS_FISCHER_RANDOM = 132
DG_COMMAND = 136
DG_TOURNEY_GAME_STARTED = 137
DG_TOURNEY_GAME_ENDED = 138
DG_MY_TURN = 139
DG_CORRESPONDENCE_RATING = 140
DG_DISABLE_PREMOVE = 141
DG_PSTAT = 142
DG_BOARDINFO = 143
DG_MOVE_LAG = 144
DG_FIFTEENMINUTE = 145
MAX_DG = 145
--}}}
--}}}
--{{{ Utility functions
--- Concatenate tags
-- @param t List of tags (table)
-- @return Tag string
-- <br /><b>Example:</b>
-- <pre>
-- &gt; require "chess.icc"<br />
-- &gt; =chess.icc.tag_concat{"GM", "*"}<br />
-- (GM *)<br />
-- &gt;
-- </pre>
function tag_concat(t)
    assert(type(t) == "table", "argument is not a table")
    local tstr = ""
    for i, tag in ipairs(t) do
        assert(type(tag) == "string",
            "tag table element at index " .. i .. " not a string")
        if tstr == "" then
            tstr = "(" .. tag
        else
            tstr = tstr .. " " .. tag
        end
    end

    if tstr ~= "" then
        return tstr .. ")"
    else
        return ""
    end
end
--- Convert a seek failure reason to string
-- @param r Reason no.
-- @return Description string.
function reason_tostring(r)
    assert(type(r) == "number", "argument is not a number")
    if r == 1 then
        return "Seeker left"
    elseif r == 2 then
        return "Seeker is playing"
    elseif r == 3 then
        return "Seeker removed ad"
    elseif r == 4 then
        return "Seeker replaced ad"
    elseif r == 5 then
        return "Seeker not available (misc reasons)"
    end
end
--}}}
--{{{ icc.client functions
--- Create a new icc.client instance and generate the parser.
-- @param argtable A table which may have the following elements<br />
-- <ul>
--  <li><tt>settings</tt>: Table of Level-2 settings</li>
-- </ul>
-- @return icc.client instance
function client:new(argtable) --{{{
    assert(type(argtable) == "table", "Argument is not a table")

    local instance = {
        settings = argtable.settings or {},

        sock = nil,
        callbacks = {},

        -- Internal
        _last_sent = 0,
        _settings_sent = false,
        _linebuf = "",
        _in_datagram = false,
    }

    local ci = setmetatable(instance, { __index = client })
    ci:generate_parser()
    return ci
end --}}}
--- Generate parser using <tt>self.settings</tt>
-- @return <tt>nil</tt>
function client:generate_parser() --{{{
    local p = parser.telnet + parser.prompts
    if self.settings[DG_WHO_AM_I] then
        p = p + parser.dg_whoami
    end
    if self.settings[DG_LOGIN_FAILED] then
        p = p + parser.dg_login_failed
    end
    if self.settings[DG_PLAYER_ARRIVED] then
        p = p + parser.dg_player_arrived
    end
    if self.settings[DG_PLAYER_LEFT] then
        p = p + parser.dg_player_left
    end
    if self.settings[DG_TITLES] then
        p = p + parser.dg_titles
    end
    if self.settings[DG_PLAYER_ARRIVED_SIMPLE] then
        p = p + parser.dg_player_arrived_simple
    end
    if self.settings[DG_GAME_STARTED] then
        p = p + parser.dg_game_started
    end
    if self.settings[DG_GAME_RESULT] then
        p = p + parser.dg_game_result
    end
    if self.settings[DG_EXAMINED_GAME_IS_GONE] then
        p = p + parser.dg_examined_game_is_gone
    end
    if self.settings[DG_MY_GAME_STARTED] then
        p = p + parser.dg_my_game_started
    end
    if self.settings[DG_MY_GAME_RESULT] then
        p = p + parser.dg_my_game_result
    end
    if self.settings[DG_MY_GAME_ENDED] then
        p = p + parser.dg_my_game_ended
    end
    if self.settings[DG_STARTED_OBSERVING] then
        p = p + parser.dg_started_observing
    end
    if self.settings[DG_STOP_OBSERVING] then
        p = p + parser.dg_stop_observing
    end
    if self.settings[DG_ISOLATED_BOARD] then
        p = p + parser.dg_isolated_board
    end
    if self.settings[DG_PLAYERS_IN_MY_GAME] then
        p = p + parser.dg_players_in_my_game
    end
    if self.settings[DG_OFFERS_IN_MY_GAME] then
        p = p + parser.dg_offers_in_my_game
    end
    if self.settings[DG_TAKEBACK] then
        p = p + parser.dg_takeback
    end
    if self.settings[DG_BACKWARD] then
        p = p + parser.dg_backward
    end
    if self.settings[DG_SEND_MOVES] then
        p = p + parser.dg_send_moves
    end
    if self.settings[DG_MOVE_LIST] then
        p = p + parser.dg_move_list
    end
    if self.settings[DG_KIBITZ] then
        p = p + parser.dg_kibitz
    end
    if self.settings[DG_SET_CLOCK] then
        p = p + parser.dg_set_clock
    end
    if self.settings[DG_FLIP] then
        p = p + parser.dg_flip
    end
    if self.settings[DG_REFRESH] then
        p = p + parser.dg_refresh
    end
    if self.settings[DG_ILLEGAL_MOVE] then
        p = p + parser.dg_illegal_move
    end
    if self.settings[DG_MY_RELATION_TO_GAME] then
        p = p + parser.dg_my_relation_to_game
    end
    if self.settings[DG_PARTNERSHIP] then
        p = p + parser.dg_partnership
    end
    if self.settings[DG_JBOARD] then
        p = p + parser.dg_jboard
    end
    if self.settings[DG_FEN] then
        p = p + parser.dg_fen
    end
    if self.settings[DG_MSEC] then
        p = p + parser.dg_msec
    end
    if self.settings[DG_MORETIME] then
        p = p + parser.dg_moretime
    end
    if self.settings[DG_CHANNEL_TELL] then
        p = p + parser.dg_channel_tell
    end
    if self.settings[DG_PEOPLE_IN_MY_CHANNEL] then
        p = p + parser.dg_people_in_my_channel
    end
    if self.settings[DG_CHANNELS_SHARED] then
        p = p + parser.dg_channels_shared
    end
    if self.settings[DG_SEES_SHOUTS] then
        p = p + parser.dg_sees_shouts
    end
    if self.settings[DG_CHANNEL_QTELL] then
        p = p + parser.dg_channel_qtell
    end
    if self.settings[DG_MATCH] then
        p = p + parser.dg_match
    end
    if self.settings[DG_MATCH_REMOVED] then
        p = p + parser.dg_match_removed
    end
    if self.settings[DG_SEEK] then
        p = p + parser.dg_seek
    end
    if self.settings[DG_SEEK_REMOVED] then
        p = p + parser.dg_seek_removed
    end
    if self.settings[DG_PERSONAL_TELL] then
        p = p + parser.dg_personal_tell
    end
    if self.settings[DG_PERSONAL_TELL_ECHO] then
        p = p + parser.dg_personal_tell_echo
    end
    if self.settings[DG_SHOUT] then
        p = p + parser.dg_shout
    end
    if self.settings[DG_PERSONAL_QTELL] then
        p = p + parser.dg_personal_qtell
    end
    if self.settings[DG_MY_VARIABLE] then
        p = p + parser.dg_my_variable
    end
    if self.settings[DG_MY_STRING_VARIABLE] then
        p = p + parser.dg_my_string_variable
    end
    if self.settings[DG_SOUND] then
        p = p + parser.dg_sound
    end
    if self.settings[DG_SUGGESTION] then
        p = p + parser.dg_suggestion
    end
    if self.settings[DG_WSUGGEST] then
        p = p + parser.dg_wsuggest
    end
    if self.settings[DG_ARROW] then
        p = p + parser.dg_arrow
    end
    if self.settings[DG_UNARROW] then
        p = p + parser.dg_unarrow
    end
    if self.settings[DG_CIRCLE] then
        p = p + parser.dg_circle
    end
    if self.settings[DG_UNCIRCLE] then
        p = p + parser.dg_uncircle
    end
    if self.settings[DG_NOTIFY_ARRIVED] then
        p = p + parser.dg_notify_arrived
    end
    if self.settings[DG_NOTIFY_LEFT] then
        p = p + parser.dg_notify_left
    end
    if self.settings[DG_NOTIFY_OPEN] then
        p = p + parser.dg_notify_open
    end
    if self.settings[DG_NOTIFY_STATE] then
        p = p + parser.dg_notify_state
    end
    if self.settings[DG_GAMELIST_BEGIN] then
        p = p + parser.dg_gamelist_begin
    end
    if self.settings[DG_GAMELIST_ITEM] then
        p = p + parser.dg_gamelist_item
    end
    if self.settings[DG_RATING_TYPE_KEY] then
        p = p + parser.dg_rating_type_key
    end
    if self.settings[DG_WILD_KEY] then
        p = p + parser.dg_wild_key
    end
    if self.settings[DG_GAME_MESSAGE] then
        p = p + parser.dg_game_message
    end
    if self.settings[DG_DUMMY_RESPONSE] then
        p = p + parser.dg_dummy_response
    end
    if self.settings[DG_SET_BOARD] then
        p = p + parser.dg_set_board
    end
    if self.settings[DG_LOG_PGN] then
        p = p + parser.dg_log_pgn
    end
    if self.settings[DG_MESSAGELIST_BEGIN] then
        p = p + parser.dg_messagelist_begin
    end
    if self.settings[DG_MESSAGELIST_ITEM] then
        p = p + parser.dg_messagelist_item
    end
    if self.settings[DG_LIST] then
        p = p + parser.dg_list
    end
    if self.settings[DG_TOURNEY] then
        p = p + parser.dg_tourney
    end
    if self.settings[DG_REMOVE_TOURNEY] then
        p = p + parser.dg_remove_tourney
    end
    if self.settings[DG_PASSWORD] then
        p = p + parser.dg_password
    end
    if self.settings[DG_MUGSHOT] then
        p = p + parser.dg_mugshot
    end
    if self.settings[DG_COMMAND] then
        p = p + parser.dg_command
    end
    if self.settings[DG_BOARDINFO] then
        p = p + parser.dg_boardinfo
    end
    if self.settings[DG_MOVE_LAG] then
        p = p + parser.dg_move_lag
    end
    self.parser = p
end --}}}
--- Set a level-2 setting. Do <b>NOT</b> use <tt>set-2</tt> directly!
-- @param index level-2 setting index
-- @param boolean Boolean that specifies whether this interface variable should be enabled.
-- @return <tt>nil</tt>
function client:set(index, boolean) --{{{
    assert(type(index) == "number", "index not a number")
    assert(0 <= index and index <= MAX_DG, "invalid index")

    if self.sock ~= nil then
        if boolean then
            self.sock:send("set-2 " .. index .. " 1")
        else
            self.sock:send("set-2 " .. index .. " 0")
        end
    end
    self.settings[index] = boolean
    self:generate_parser()
end --}}}
--- Convert settings table to a string.
-- @return Level-2 settings represented as a string suitable to sent to server on login prompt.
function client:settings_tostring() --{{{
    local settings_str = "level2settings="

    for index=0, MAX_DG do
        if self.settings[index] then
            settings_str = settings_str .. "1"
        else
            settings_str = settings_str .. "0"
        end
    end

    return settings_str
end --}}}
--- Connect to Internet Chess Club.
-- @param address Address of the Internet Chess Club. Defaults to
-- <tt>chessclub.com</tt>.
-- @param port Port of the Internet Chess Club. Defaults to <tt>23</tt>.
-- @return <tt>true</tt> on success, <tt>nil</tt> and error message on failure.
function client:connect(address, port) --{{{
    assert(self.sock == nil, "already connected")
    local address = address or "chessclub.com"
    local port = port or 23

    local errmsg
    self.sock, errmsg = socket.connect(address, port)
    if self.sock == nil then return nil, errmsg end

    self.sock:settimeout(0)
    self.sock:setoption("tcp-nodelay", true)
    return true
end --}}}
--- Disconnect from the Internet Chess Club.
-- @return <tt>nil</tt>
function client:disconnect() --{{{
    assert(self.sock ~= nil, "not connected")

    self.sock:close()
    self.sock = nil

    self._last_sent = 0
    self._settings_sent = false
    self._linebuf = ""
    self._in_datagram = false
end --}}}
--- Send data to the server.
-- @param data Data to send
-- @return Number of bytes sent on success, <tt>nil</tt> and error message on
-- failure.
function client:send(data) --{{{
    assert(type(data) == "string", "argument not a string")
    assert(self.sock ~= nil, "not connected")

    data = data .. "\n"

    local bytes, errmsg = self.sock:send(data)
    if errmsg == nil then
        -- Keep track of time for idle callback.
        self._last_sent = os.time()
    end

    return bytes, errmsg
end --}}}
--- Receive a line from the server.
-- @return The received line, <tt>nil</tt> and error message on failure.
-- <br/><b>Note:</b><br />
-- The error message may be <tt>internal</tt> for internal lines like timeseal
-- responses.
function client:recvline() --{{{
    assert(self.sock ~= nil, "not connected")

    self:run_callback("idle", os.time() - self._last_sent)
    while true do
        local chunk, errmsg = self.sock:receive(1)
        if chunk == nil then
            return nil, errmsg
        end

        if chunk == EOR then
            -- Receive another byte
            local chunk, errmsg = self.sock:receive(1)
            if chunk == nil then
                return nil, errmsg
            end

            self._linebuf = self._linebuf .. EOR .. chunk
            if chunk == "(" then
                self._in_datagram = true
            elseif chunk == ")" then
                self._in_datagram = false
                break
            end
        elseif chunk == CR then
            if not self._in_datagram then break end
        elseif chunk ~= LF then
            self._linebuf = self._linebuf .. chunk

            if parser.prompts:match(self._linebuf) then
                break
            end
        elseif chunk == RCTE then
            break
        end
    end

    local line = self._linebuf
    self._linebuf = ""

    line = parser.suppress_prompt:match(line)
    if line then return line
    else return nil, "internal" end
end --}}}
--- Register a callback.
-- @param group Name of the callback group.
-- @param func Function or coroutine to register.
-- @return Callback index which can be used to remove the callback.
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
--- Register a callback
-- @param index Callback index.
-- @return <tt>true</tt> if the callback was found and removed, <tt>false</tt>
-- otherwise.
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
--- Run a callback.
-- @param group The callback group.
-- @param ... Arguments passed to the callback function or coroutine.
-- @return <tt>nil</tt>
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
--- Parse a line and call related callback functions.
-- @param line The line to parse.
-- @return <tt>true</tt> on success, <tt>nil</tt> and error message on failure.
function client:parseline(line) --{{{
    local parsed = self.parser:match(line)

    if not parsed then
        self:run_callback("line", line)
    -- Telnet
    elseif parsed[1] == parser.IAC_WILL_ECHO then
        self:run_callback("iac_will_echo")
    elseif parsed[1] == parser.IAC_WONT_ECHO then
        self:run_callback("iac_wont_echo")
    elseif parsed[1] == parser.RCTE then
        self:run_callback("rcte")
    -- Prompts
    elseif parsed[1] == parser.PROMPT_LOGIN then
        if not self._settings_sent then
            local bytes, errmsg = self:send(self:settings_tostring())
            if errmsg ~= nil then
                return nil, errmsg
            else
                self._settings_sent = true
            end
        end

        self:run_callback("login", line)
    -- Datagrams
    elseif parsed[1] == parser.PROMPT_PASSWORD then
        self:run_callback("password", line)
    elseif parsed[1] == DG_WHO_AM_I then
        self:run_callback(DG_WHO_AM_I, parsed[2], parsed[3])
    elseif parsed[1] == DG_LOGIN_FAILED then
        if self.callbacks[DG_LOGIN_FAILED] then
            self:run_callback(DG_LOGIN_FAILED, parsed[2], parsed[3])
        elseif parsed[2] ~= 5 then
            self:disconnect()
            error("Login failed with code " .. parsed[2] .. " (" ..
                parsed[3] .. ")")
        end
    elseif parsed[1] == DG_PLAYER_ARRIVED then
        self:run_callback(DG_PLAYER_ARRIVED, parsed[2], parsed[3],
            parsed[4], parsed[5], parsed[6], parsed[7], parsed[8],
            parsed[9], parsed[10], parsed[11], parsed[12], parsed[13],
            parsed[14], parsed[15], parsed[16])
    elseif parsed[1] == DG_PLAYER_LEFT then
        self:run_callback(DG_PLAYER_LEFT, parsed[2])
    elseif parsed[1] == DG_TITLES then
        self:run_callback(DG_TITLES, parsed[2], parsed[3])
    elseif parsed[1] == DG_PLAYER_ARRIVED_SIMPLE then
        self:run_callback(DG_PLAYER_ARRIVED_SIMPLE, parsed[2])
    elseif parsed[1] == DG_GAME_STARTED then
        self:run_callback(DG_GAME_STARTED, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_GAME_RESULT then
        self:run_callback(DG_GAME_RESULT, parsed[2])
    elseif parsed[1] == DG_EXAMINED_GAME_IS_GONE then
        self:run_callback(DG_EXAMINED_GAME_IS_GONE, parsed[2])
    elseif parsed[1] == DG_MY_GAME_STARTED then
        self:run_callback(DG_MY_GAME_STARTED, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_MY_GAME_RESULT then
        self:run_callback(DG_MY_GAME_RESULT, parsed[2])
    elseif parsed[1] == DG_MY_GAME_ENDED then
        self:run_callback(DG_MY_GAME_ENDED, parsed[2])
    elseif parsed[1] == DG_STARTED_OBSERVING then
        self:run_callback(DG_STARTED_OBSERVING, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_STOP_OBSERVING then
        self:run_callback(DG_STOP_OBSERVING, parsed[2])
    elseif parsed[1] == DG_ISOLATED_BOARD then
        self:run_callback(DG_ISOLATED_BOARD, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_PLAYERS_IN_MY_GAME then
        self:run_callback(DG_PLAYERS_IN_MY_GAME, parsed[2], parsed[3], parsed[4],
            parsed[5])
    elseif parsed[1] == DG_OFFERS_IN_MY_GAME then
        self:run_callback(DG_OFFERS_IN_MY_GAME, parsed[2])
    elseif parsed[1] == DG_TAKEBACK then
        self:run_callback(DG_TAKEBACK, parsed[2])
    elseif parsed[1] == DG_BACKWARD then
        self:run_callback(DG_BACKWARD, parsed[2])
    elseif parsed[1] == DG_SEND_MOVES then
        self:run_callback(DG_SEND_MOVES, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6], parsed[7])
    elseif parsed[1] == DG_MOVE_LIST then
        self:run_callback(DG_MOVE_LIST, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_KIBITZ then
        self:run_callback(DG_KIBITZ, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6])
    elseif parsed[1] == DG_SET_CLOCK then
        self:run_callback(DG_SET_CLOCK, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_FLIP then
        self:run_callback(DG_FLIP, parsed[2], parsed[3])
    elseif parsed[1] == DG_REFRESH then
        self:run_callback(DG_REFRESH, parsed[2])
    elseif parsed[1] == DG_ILLEGAL_MOVE then
        self:run_callback(DG_ILLEGAL_MOVE, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_MY_RELATION_TO_GAME then
        self:run_callback(DG_MY_RELATION_TO_GAME, parsed[2], parsed[3])
    elseif parsed[1] == DG_PARTNERSHIP then
        self:run_callback(DG_PARTNERSHIP, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_JBOARD then
        self:run_callback(DG_JBOARD, parsed[2])
    elseif parsed[1] == DG_FEN then
        self:run_callback(DG_FEN, parsed[2], parsed[3])
    elseif parsed[1] == DG_MSEC then
        self:run_callback(DG_MSEC, parsed[2], parsed[3], parsed[4],
            parsed[5])
    elseif parsed[1] == DG_MORETIME then
        self:run_callback(DG_MORETIME, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_CHANNEL_TELL then
        self:run_callback(DG_CHANNEL_TELL, parsed[2], parsed[3],
            parsed[4], parsed[5], parsed[6])
    elseif parsed[1] == DG_PEOPLE_IN_MY_CHANNEL then
        self:run_callback(DG_PEOPLE_IN_MY_CHANNEL, parsed[2],
            parsed[3], parsed[4])
    elseif parsed[1] == DG_CHANNELS_SHARED then
        self:run_callback(DG_CHANNELS_SHARED, parsed[2], parsed[3])
    elseif parsed[1] == DG_SEES_SHOUTS then
        self:run_callback(DG_SEES_SHOUTS, parsed[2], parsed[3])
    elseif parsed[1] == DG_CHANNEL_QTELL then
        self:run_callback(DG_CHANNEL_QTELL, parsed[2], parsed[3], parsed[4],
            parsed[5])
    elseif parsed[1] == DG_MATCH then
        self:run_callback(DG_MATCH, parsed[2], parsed[3],
            parsed[4])
    elseif parsed[1] == DG_MATCH_REMOVED then
        self:run_callback(DG_MATCH_REMOVED, parsed[2], parsed[3],
            parsed[4])
    elseif parsed[1] == DG_SEEK then
        self:run_callback(DG_SEEK, parsed[2], parsed[3])
    elseif parsed[1] == DG_SEEK_REMOVED then
        self:run_callback(DG_SEEK_REMOVED, parsed[2], parsed[3])
    elseif parsed[1] == DG_PERSONAL_TELL then
        self:run_callback(DG_PERSONAL_TELL, parsed[2], parsed[3],
            parsed[4], parsed[5])
    elseif parsed[1] == DG_PERSONAL_TELL_ECHO then
        self:run_callback(DG_PERSONAL_TELL_ECHO, parsed[2], parsed[3],
            parsed[4])
    elseif parsed[1] == DG_SHOUT then
        self:run_callback(DG_SHOUT, parsed[2], parsed[3],
            parsed[4], parsed[5])
    elseif parsed[1] == DG_PERSONAL_QTELL then
        self:run_callback(DG_PERSONAL_QTELL, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_MY_VARIABLE then
        self:run_callback(DG_MY_VARIABLE, parsed[2], parsed[3])
    elseif parsed[1] == DG_MY_STRING_VARIABLE then
        self:run_callback(DG_MY_STRING_VARIABLE, parsed[2], parsed[3])
    elseif parsed[1] == DG_SOUND then
        self:run_callback(DG_SOUND, parsed[2])
    elseif parsed[1] == DG_SUGGESTION then
        self:run_callback(DG_SUGGESTION, parsed[2], parsed[3],
            parsed[4], parsed[5], parsed[6], parsed[7])
    elseif parsed[1] == DG_WSUGGEST then
        self:run_callback(DG_WSUGGEST, parsed[2], parsed[3],
            parsed[4], parsed[5], parsed[6], parsed[7])
    elseif parsed[1] == DG_ARROW then
        self:run_callback(DG_ARROW, parsed[2], parsed[3],
            parsed[4], parsed[5])
    elseif parsed[1] == DG_UNARROW then
        self:run_callback(DG_UNARROW, parsed[2], parsed[3],
            parsed[4], parsed[5])
    elseif parsed[1] == DG_CIRCLE then
        self:run_callback(DG_CIRCLE, parsed[2], parsed[3],
            parsed[4])
    elseif parsed[1] == DG_UNCIRCLE then
        self:run_callback(DG_UNCIRCLE, parsed[2], parsed[3],
            parsed[4])
    elseif parsed[1] == DG_NOTIFY_ARRIVED then
        self:run_callback(DG_NOTIFY_ARRIVED, parsed[2], parsed[3],
            parsed[4], parsed[5], parsed[6], parsed[7], parsed[8],
            parsed[9], parsed[10], parsed[11], parsed[12], parsed[13],
            parsed[14], parsed[15], parsed[16])
    elseif parsed[1] == DG_NOTIFY_LEFT then
        self:run_callback(DG_NOTIFY_LEFT, parsed[2])
    elseif parsed[1] == DG_NOTIFY_OPEN then
        self:run_callback(DG_NOTIFY_OPEN, parsed[2], parsed[3])
    elseif parsed[1] == DG_NOTIFY_STATE then
        self:run_callback(DG_NOTIFY_STATE, parsed[2], parsed[3])
    elseif parsed[1] == DG_GAMELIST_BEGIN then
        self:run_callback(DG_GAMELIST_BEGIN, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6], parsed[7])
    elseif parsed[1] == DG_GAMELIST_ITEM then
        self:run_callback(DG_GAMELIST_ITEM, parsed[2])
    elseif parsed[1] == DG_RATING_TYPE_KEY then
        self:run_callback(DG_RATING_TYPE_KEY, parsed[2], parsed[3])
    elseif parsed[1] == DG_WILD_KEY then
        self:run_callback(DG_WILD_KEY, parsed[2], parsed[3])
    elseif parsed[1] == DG_GAME_MESSAGE then
        self:run_callback(DG_GAME_MESSAGE, parsed[2], parsed[3])
    elseif parsed[1] == DG_DUMMY_RESPONSE then
        self:run_callback(DG_DUMMY_RESPONSE)
    elseif parsed[1] == DG_SET_BOARD then
        self:run_callback(DG_SET_BOARD, parsed[2])
    elseif parsed[1] == DG_LOG_PGN then
        self:run_callback(DG_LOG_PGN, parsed[2])
    elseif parsed[1] == DG_MESSAGELIST_BEGIN then
        self:run_callback(DG_MESSAGELIST_BEGIN, parsed[2])
    elseif parsed[1] == DG_MESSAGELIST_ITEM then
        self:run_callback(DG_MESSAGELIST_ITEM, parsed[2])
    elseif parsed[1] == DG_LIST then
        self:run_callback(DG_LIST, parsed[2])
    elseif parsed[1] == DG_TOURNEY then
        self:run_callback(DG_TOURNEY, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6], parsed[7], parsed[8])
    elseif parsed[1] == DG_REMOVE_TOURNEY then
        self:run_callback(DG_REMOVE_TOURNEY, parsed[2])
    elseif parsed[1] == DG_PASSWORD then
        self:run_callback(DG_PASSWORD, parsed[2], parsed[3])
    elseif parsed[1] == DG_MUGSHOT then
        self:run_callback(DG_MUGSHOT, parsed[2], parsed[3], parsed[4])
    elseif parsed[1] == DG_COMMAND then
        self:run_callback(DG_COMMAND, parsed[2], parsed[3])
    elseif parsed[1] == DG_BOARDINFO then
        self:run_callback(DG_BOARDINFO, parsed[2], parsed[3], parsed[4],
            parsed[5], parsed[6], parsed[7])
    elseif parsed[1] == DG_MOVE_LAG then
        self:run_callback(DG_MOVE_LAG, parsed[2], parsed[3])
    else
        error("unhandled parser id " .. parsed[1])
    end

    return true
end --}}}
--- Enter main loop.
-- @param times How many times to loop, if 0 loop forever. Defaults to
-- <tt>0</tt>.
-- @return <tt>true</tt> on success, <tt>nil</tt> and error message on failure.
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

