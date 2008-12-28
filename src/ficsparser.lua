#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 tw=80 fdm=marker:
--[[
  Copyright (c) 2008 Ali Polatel <polatel@gmail.com>

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

--- Lpeg parser for FICS.
-- Requires lpeg.

require"lpeg"

local ipairs = ipairs
local tonumber = tonumber
local type = type
local unpack = unpack

local string = string
local table = table
local ficsutils = require "ficsutils"

local C = lpeg.C
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Ct = lpeg.Ct
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local match = lpeg.match
local t = lpeg.locale()

module "ficsparser"

-- Ids
PROMPT_LOGIN = 1
PROMPT_PASSWORD = 2
PROMPT_SERVER = 3
HANDLE_TOO_SHORT = 4
HANDLE_TOO_LONG = 5
HANDLE_NOT_ALPHA = 6
HANDLE_NOT_REGISTERED = 7
HANDLE_BANNED = 52
PASSWORD_INVALID = 8
PRESS_RETURN = 53
WELCOME = 9
NEWS = 10
MESSAGES = 11
NOTIFY_INCLUDE = 12
NOTIFY_NOTE = 13
NOTIFY_ARRIVE = 14
NOTIFY_DEPART = 15
TELL = 16
CHANTELL = 17
QTELL = 18
IT = 19
SHOUT = 20
CSHOUT = 21
ANNOUNCEMENT = 22
KIBITZ = 23
WHISPER = 24
CHALLENGE_UPDATE = 25
MATCH_REQUEST = 26
RATING_CHANGE = 27
NEWRD = 28
PARTNER_OFFER = 29
GAME_START = 30
GAME_END = 31
STYLE12 = 32
DRAW = 33
DRAW_ACCEPT = 34
DRAW_DECLINE = 35
ABORT = 36
ABORT_ACCEPT = 37
ABORT_DECLINE = 38
ADJOURN = 39
ADJOURN_ACCEPT = 40
ADJOURN_DECLINE = 41
TAKEBACK = 42
TAKEBACK_ACCEPT = 43
TAKEBACK_DECLINE = 44
SEEKINFO = 45
SEEKREMOVE = 46
SEEKCLEAR = 47
MOVE = 48
EXAMINING = 49
IAC_WILL_ECHO = 50
IAC_WONT_ECHO = 51

number = (t.digit + S"+-.")^1 / tonumber
e = -P(1)
handle = C(t.alnum^-17)
tag = P"(" * C(P"*" + P"B" + P"CA" + P"C" + P"SR" + P"TD" + P"TM" +
    P"GM" + P"IM" + P"FM" + P"WGM" + P"WIM" + P"WFM") * P")"
tags = tag^1 / function (...)
    local ret = {}
    for _, capture in ipairs(arg) do
        table.insert(ret, capture)
    end
    return ret
    end
handle_tags = handle * tags
rating = ((number * C(S"EP")^0) + P"----") / function (...)
    local r = {}
    if type(arg[1]) == "number" then
        r.value = arg[1]
        if arg[2] == "E" then
            r.established = true
        elseif arg[2] == "P" then
            r.provisional = true
        end
    else
        r.value = 0
    end
    return r
    end

-- Prompts
login = (P"login: " * e) / function (c) return {PROMPT_LOGIN} end
password = (P"password: " * e) / function (c) return {PROMPT_PASSWORD} end
server_prompt = (C((R"09"^-2 * P":" * R"09"^-2)^0) * P"_"^0 * P"fics% " * e) /
    function (c) return {PROMPT_SERVER, c} end
prompts = login + password + server_prompt

-- Authentication
handle_too_short = P"A name should be at least three characters long" /
    function (c) return {HANDLE_TOO_SHORT} end
handle_too_long = P"Sorry, names may be at most 17 characters long" /
    function (c) return {HANDLE_TOO_LONG} end
handle_not_alpha = P"Sorry, names can only consist of lower and upper case letters" /
    function (c) return {HANDLE_NOT_ALPHA} end
handle_not_registered = (P'"' * handle * P'" is not a registered name') /
    function (c) return {HANDLE_NOT_REGISTERED, c} end
handle_banned = (P'Player "' * handle * P'" is banned') / function (c)
    return {HANDLE_BANNED, c} end
password_invalid = P"**** Invalid password! ****" /
    function (c) return {PASSWORD_INVALID} end
press_return = (P'Press return to enter the server as "' * handle * P'"') /
    function (c) return {PRESS_RETURN, c} end

authentication = handle_too_short + handle_too_long + handle_not_alpha +
    handle_not_registered + handle_banned + password_invalid + press_return

-- Session start
welcome = (P"**** Starting FICS session as " * handle_tags) / function (...)
    return {WELCOME, unpack(arg)}
    end
news = (number * P" (" * C((t.print - P")")^1) * P") " * C(t.print^1) * e) /
    function (...) return {NEWS, unpack(arg)} end
messages = (P"You have " * number * P" messages (" * number * " unread)." * e) /
    function (...) return {MESSAGES, unpack(arg)} end

session_start = welcome + news + messages

-- Notifications
notify_include = (P"Present company includes: " * (handle * S" .")^1 * e) /
    function (...) return {NOTIFY_INCLUDE, arg} end
notify_note = (P"Your arrival was noted by: " * (handle * S" .")^1 * e) /
    function (...) return {NOTIFY_NOTE, arg} end
notify_arrive = P"Notification: " * handle * P" has arrived"  *
    C(P" and isn't on your notify list"^0) /
    function (c1, c2)
        local ret = {NOTIFY_ARRIVE, c1}
        if c2 == "" then
            table.insert(ret, true)
        else
            table.insert(ret, false)
        end
        return ret
    end
notify_depart = P"Notification: " * handle * P" has departed"  *
    C(P" and isn't on your notify list"^0) /
    function (c1, c2)
        local ret = {NOTIFY_DEPART, c1}
        if c2 == "" then
            table.insert(ret, true)
        else
            table.insert(ret, false)
        end
        return ret
    end

notification = notify_include + notify_note + notify_arrive + notify_depart

-- Chat
tell = handle * tags^0 * P" tells you: " * C(t.print^1) / function (...)
    if #arg == 2 then return {TELL, arg[1], nil, arg[2]} end
    return {TELL, unpack(arg)}
    end
chantell = handle * tags^0 * P"(" * number * P"): " * C(t.print^1) /
    function (...)
        if #arg == 3 then return {CHANTELL, arg[1], nil, arg[2], arg[3]} end
        return {CHANTELL, unpack(arg)}
    end
qtell = P":" * C(t.print^1) / function (c) return {QTELL, c} end
it = P"--> " * handle * tags^0 * P" " * C(t.print^1) / function (...)
    if #arg == 2 then return {IT, arg[1], nil, arg[2]} end
    return {IT, unpack(arg)}
    end
shout = handle * tags^0 * P" shouts: " * C(t.print^1) / function (...)
    if #arg == 2 then return {SHOUT, arg[1], nil, arg[2]} end
    return {SHOUT, unpack(arg)}
    end
cshout = handle * tags^0 * P" c-shouts: " * C(t.print^1) / function (...)
    if #arg == 2 then return {CSHOUT, arg[1], nil, arg[2]} end
    return {CSHOUT, unpack(arg)}
    end
announcement = P" **ANNOUNCEMENT** from " * handle * P": " * C(t.print^1) /
    function (...) return {ANNOUNCEMENT, unpack(arg)} end
kibitz = handle * tags^0 * P"(" * rating * P")[" * number * P"] kibitzes: " *
    C(t.print^1) / function (...)
        if #arg == 4 then
            return {KIBITZ, arg[1], nil, arg[2], arg[3], arg[4]}
        end
        return {KIBITZ, unpack(arg)}
    end
whisper = handle * tags^0 * P"(" * rating * P")[" * number * P"] whispers: " *
    C(t.print^1) / function (...)
        if #arg == 4 then
            return {WHISPER, arg[1], nil, arg[2], arg[3], arg[4]}
        end
        return {WHISPER, unpack(arg)}
    end

chat = tell + chantell + qtell + it + shout + cshout + announcement + kibitz + whisper

-- Challenges
challenge_update = (handle * " updates the match request.") / function (c)
    return {CHALLENGE_UPDATE, c}
    end
match_request = C(P"Challenge" + P"Issuing" + P"Your game will be") * P": " *
    handle * P" (" * rating * P") " * (C(P"[white" + P"[black") * P"] ")^0 *
    handle * P" (" * rating * P") " * C(P"rated" + P"unrated") * P" " *
    C(t.alpha^1) * P" " * number * P" " * number *
    (P" Loaded from wild/" * number)^0 / function (...)
        local game = {}

        if arg[1] == "Challenge" then
            game.issued = false
        elseif arg[1]== "Issuing" then
            game.issued = true
        end

        local colour
        if arg[4] == "[white" or arg[4] == "[black" then
            colour = string.sub(arg[4], 2)
        end

        local player1, player2
        player1 = {handle = arg[2], rating = arg[3], colour = colour}
        if colour then
            player2 = {handle = arg[5], rating = arg[6]}

            if arg[7] == "rated" then
                game.rated = true
            else
                game.rated = false
            end

            game.type = arg[8]
            game.time = arg[9]
            game.increment = arg[10]
            game.wild_type = arg[11]
        else
            player2 = {handle = arg[4], rating = arg[5]}

            if arg[6] == "rated" then
                game.rated = true
            else
                game.rated = false
            end

            game.type = arg[7]
            game.time = arg[8]
            game.increment = arg[9]
            game.wild_type = arg[10]
        end

        return {MATCH_REQUEST, game, player1, player2}
    end
rating_change = (P"Your " * C(t.alpha^1) * P" rating will change:  Win: " *
    number * P",  Draw: " * number * P",  Loss: " * number) / function (...)
        return {RATING_CHANGE, unpack(arg)}
    end
newrd = (P"Your new RD will be " * number) / function (c)
    return {NEWRD, c} end

challenge = challenge_update + match_request + rating_change + newrd

-- Bughouse
partner_offer = (handle * P" offers to be your bughouse partner") /
    function (c) return {PARTNER_OFFER, c} end

bughouse = partner_offer

-- Game start/end
game_start = (P"{Game " * number * P" (" * handle * P" vs. " * handle * P") " *
    C((t.print - P"}")^1) * P"}" * e) / function (...)
        return {GAME_START, unpack(arg)} end
game_end = (P"{Game " * number * P" (" * handle * P" vs. " * handle * P") " *
    C((t.print - P"}")^1) * P"} " * C(S"012-/*"^1) * e) / function (...)
    return {GAME_END, unpack(arg)} end

-- Style 12
piece = S"rnbqkbnrpRNBQKBNRP-"
rank = C(piece^8)
board = ((rank * P" ")^7 * rank) / function (...)
    local board = {}

    for i=8,1,-1 do
        local pieces = arg[i]
        local rank = string.byte"a"
        while rank <= string.byte"h" do
            board[string.char(rank) .. i] = string.sub(pieces, i, i)
            rank = rank + 1
        end
    end
    return board
    end
boolean = S"01tf" / function (c)
    if c == "0" or c == "f" then return false end
    return true end
not_space = C((t.print - P" ")^1)
digit = t.digit^1 / tonumber
time = digit * P":" * digit * (P"." * digit)^0
style12 = (P"<12> " * board * P" " * C(S"WB") * P" " * number * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * boolean * P" " *
    number * P" " * number * P" " * handle * P" " * handle * P" " *
    number * P" " * number * P" " * number * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * number * P" " *
    not_space * P" (" * time * P") " * not_space * P" " * (S"01" / tonumber)) /
    function (...)
        local game = {
            board = arg[1],
            tomove = arg[2],
            double_pawn_push = arg[3],
            white_castle = arg[4],
            white_long_castle = arg[5],
            black_castle = arg[6],
            black_long_castle = arg[7],
            last_irreversible = arg[8],
            no = arg[9],
            white_name = arg[10],
            black_name = arg[11],
            relation = arg[12],
            time = arg[13],
            increment = arg[14],
            white_strength = arg[15],
            black_strength = arg[16],
            white_time = arg[17],
            black_time = arg[18],
            move_no = arg[19],
            last_move_long = arg[20],
            last_minute = arg[21],
            last_second = arg[22],
        }
        if type(arg[23]) == "number" then
            game.last_ms = arg[23]
            game.last_move = arg[24]
            game.flip = arg[25]
        else
            game.last_ms = 0
            game.last_move = arg[23]
            game.flip = arg[24]
        end

        return {STYLE12, game}
    end

game = game_end + game_start + style12

-- Offers
draw = (handle * P" offers you a draw") / function (c)
    return {DRAW, c} end
draw_accept = (handle * P" accepts the draw request") / function (c)
    return {DRAW_ACCEPT, c} end
draw_decline = (handle * P" declines the draw request") / function (c)
    return {DRAW_DECLINE, c} end
abort = (handle * " would like to abort the game") / function (c)
    return {ABORT, c} end
abort_accept = (handle * " accepts the abort request") / function (c)
    return {ABORT_ACCEPT, c} end
abort_decline = (handle * " declines the abort request") / function (c)
    return {ABORT_DECLINE, c} end
adjourn = (handle * " would like to adjourn the game") / function (c)
    return {ADJOURN, c} end
adjourn_accept = (handle * " accepts the adjourn request") / function (c)
    return {ADJOURN_ACCEPT, c} end
adjourn_decline = (handle * " declines the adjourn request") / function (c)
    return {ADJOURN_DECLINE, c} end
takeback = (handle * " would like to take back " * number * " half move") /
    function (c1, c2) return {TAKEBACK, c1, c2} end
takeback_accept = (handle * " accepts the takeback request") / function (c)
    return {TAKEBACK_ACCEPT, c} end
takeback_decline = (handle * " declines the takeback request") / function (c)
    return {TAKEBACK_DECLINE, c} end

offer = draw + draw_accept + draw_decline + abort + abort_accept + abort_decline +
    adjourn + adjourn_accept + adjourn_decline +
    takeback + takeback_accept + takeback_decline

-- Seek
rated = S"ru" / function (c)
    if c == "u" then return false end
    return true end
seekinfo = (P"<s> " * number * P" w=" * handle * P" ti=" *
    (number / ficsutils.titles_totable) * P" rt=" * rating *
    (P"  " + P" ") * P"t=" * number * P" i=" * number * P" r=" * rated  *
    P" tp=" * C(t.alpha^1) * P" c=" * C(S"?WB") * P" rr=" * digit * P"-" * digit *
    P" a=" * boolean * P" f=" * boolean) / function (...)
        local seek = {}

        seek.index = arg[1]
        seek.from = arg[2]
        seek.titles = arg[3]
        seek.rating = arg[4]
        seek.time = arg[5]
        seek.increment = arg[6]
        seek.rated = arg[7]
        seek.type = arg[8]
        seek.colour = arg[9]
        seek.rating_range = {arg[10], arg[11]}
        seek.automatic = arg[12]
        seek.formula_checked = arg[13]

        return {SEEKINFO, seek}
    end
seekremove = (P"<sr> " * (number * P" "^0)^1) / function (...)
    return {SEEKREMOVE, arg} end
seekclear = P"<sc>" / function () return {SEEKCLEAR} end

seek = seekinfo + seekremove + seekclear

-- Examined/Observed games
move = (P"Game " * number * P": " * handle * P" moves: " * C(t.print^1)) /
    function (...) return {MOVE, unpack(arg)} end
examining = (handle * P" is examining a game.") / function (c)
    return {EXAMINING, c} end

exob = move + examining

-- Telnet
iac_will_echo = P(string.char(255, 251, 1)) / function ()
    return {IAC_WILL_ECHO} end
iac_wont_echo = P(string.char(255, 252, 1)) / function ()
    return {IAC_WONT_ECHO} end

telnet = iac_will_echo + iac_wont_echo

p = prompts + authentication + session_start + notification +
    chat + challenge + bughouse + game + offer + seek + exob + telnet
