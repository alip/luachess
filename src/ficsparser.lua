#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
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

require("lpeg")

local ipairs = ipairs
local tonumber = tonumber
local type = type
local unpack = unpack

local string = string
local table = table

local C = lpeg.C
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Ct = lpeg.Ct
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local match = lpeg.match
local t = lpeg.locale()

module("ficsparser")

-- Ids
PROMPT_LOGIN = 1
PROMPT_PASSWORD = 2
PROMPT_SERVER = 3
HANDLE_TOO_SHORT = 4
HANDLE_TOO_LONG = 5
HANDLE_NOT_ALPHA = 6
HANDLE_NOT_REGISTERED = 7
PASSWORD_INVALID = 8
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

-- Tags
TAG_ADMIN = -1
TAG_BLIND = -2
TAG_CA = -3
TAG_COMPUTER = -4
TAG_SR = -5
TAG_TD = -6
TAG_TM = -7

-- Helper functions for tags
function tag_tostring(tag)
    if tag == TAG_ADMIN then
        return "*"
    elseif tag == TAG_BLIND then
        return "B"
    elseif tag == TAG_CA then
        return "CA"
    elseif tag == TAG_COMPUTER then
        return "C"
    elseif tag == TAG_SR then
        return "SR"
    elseif tag == TAG_TD then
        return "TD"
    elseif tag == TAG_TM then
        return "TM"
    else
        error("unknown tag " .. tag)
    end
end

function tag_concat(t)
    assert(type(t) == "table", "argument is not a table")
    local tstr = ""
    for i, tag in ipairs(t) do
        assert(type(tag) == "number", "tag table element at index " .. i .. " not a number")
        tstr = tstr .. "(" .. tag_tostring(tag) .. ")"
    end
    return tstr
end

number = (t.digit + S"+-.")^1 / tonumber
e = -P(1)
handle = C(t.alnum^-17)
admin = P"*" / function () return TAG_ADMIN end
blind = P"B" / function () return TAG_BLIND end
ca = P"CA" / function () return TAG_CA end
computer = P"C" / function () return TAG_COMPUTER end
sr = P"SR" / function () return TAG_SR end
td = P"TD" / function () return TAG_TD end
tm = P"TM" / function () return TAG_TM end
tag = P"(" * (admin + blind + ca + computer + sr + td + tm) * P")"
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
server_prompt = (C((R"09"^-2 * P":" * R"09"^-2)^0) * P"_"^0 * P"fics% " * e) / function (c)
    return {PROMPT_SERVER, c}
    end
prompts = login + password + server_prompt

-- Authentication
handle_too_short = P"A name should be at least three characters long" / function (c)
    return {HANDLE_TOO_SHORT} end
handle_too_long = P"Sorry, names may be at most 17 characters long" / function (c)
    return {HANDLE_TOO_LONG} end
handle_not_alpha = P"Sorry, names can only consist of lower and upper case letters" / function (c)
    return {HANDLE_NOT_ALPHA} end
handle_not_registered = (P'"' * handle * P'" is not a registered name') / function (c)
    return {HANDLE_NOT_REGISTERED, c} end
password_invalid = P"**** Invalid password! ****" / function (c) return {PASSWORD_INVALID} end

authentication = handle_too_short + handle_too_long + handle_not_alpha +
    handle_not_registered + password_invalid

-- Session start
welcome = (P"**** Starting FICS session as " * handle_tags) / function (...)
    return {WELCOME, unpack(arg)}
    end
news = (number * P" (" * C((t.print - P")")^1) * P") " * C(t.print^1) * e) / function (...)
    return {NEWS, unpack(arg)}
    end
messages = (P"You have " * number * P" messages (" * number * " unread)." * e) / function (...)
    return {MESSAGES, unpack(arg)}
    end

session_start = welcome + news + messages

-- Notifications
notify_include = (P"Present company includes: " * (handle * S" .")^1 * e) / function (...)
    return {NOTIFY_INCLUDE, arg}
    end
notify_note = (P"Your arrival was noted by: " * (handle * S" .")^1 * e) / function (...)
    return {NOTIFY_NOTE, arg}
    end
notify_arrive = P"Notification: " * handle * P" has arrived"  * C(P" and isn't on your notify list"^0) /
    function (c1, c2)
        local ret = {NOTIFY_ARRIVE, c1}
        if c2 == "" then
            table.insert(ret, true)
        else
            table.insert(ret, false)
        end
        return ret
    end
notify_depart = P"Notification: " * handle * P" has departed"  * C(P" and isn't on your notify list"^0) /
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
chantell = handle * tags^0 * P"(" * number * P"): " * C(t.print^1) / function (...)
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
announcement = P" **ANNOUNCEMENT** from " * handle * P": " * C(t.print^1) / function (...)
    return {ANNOUNCEMENT, unpack(arg)}
    end
kibitz = handle * tags^0 * P"(" * rating * P")[" * number * P"] kibitzes: " * C(t.print^1) / function (...)
    if #arg == 4 then return {KIBITZ, arg[1], nil, arg[2], arg[3], arg[4]} end
    return {KIBITZ, unpack(arg)}
    end
whisper = handle * tags^0 * P"(" * rating * P")[" * number * P"] whispers: " * C(t.print^1) / function (...)
    if #arg == 4 then return {KIBITZ, arg[1], nil, arg[2], arg[3], arg[4]} end
    return {KIBITZ, unpack(arg)}
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
partner_offer = (handle * P" offers to be your bughouse partner") / function (c)
    return {PARTNER_OFFER, c} end

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
boolean = S"01" / function (c)
    if c == "0" then return false end
    return true end
not_space = C((t.print - P" ")^1)
digit = t.digit^1 / tonumber
time = digit * P":" * digit * (P"." * digit)^0
style12 = (P"<12> " * (rank * P" ")^8 * C(S"WB") * P" " * number * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * boolean * P" " *
    number * P" " * number * P" " * handle * P" " * handle * P" " *
    number * P" " * number * P" " * number * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * number * P" " *
    not_space * P" (" * time * P") " * not_space * P" " * (S"01" / tonumber)) / function (...)
        local m = {}

        -- Ranks
        local i=1
        for j=8,1,-1 do
            m["rank" .. j] = arg[i]
            i = i + 1
        end

        m.tomove = arg[9]
        m.double_pawn_push = arg[10]
        m.white_castle = arg[11]
        m.white_long_castle = arg[12]
        m.black_castle = arg[13]
        m.black_long_castle = arg[14]
        m.last_irreversible = arg[15]
        m.game_no = arg[16]
        m.white_name = arg[17]
        m.black_name = arg[18]
        m.relation = arg[19]
        m.time = arg[20]
        m.increment = arg[21]
        m.white_strength = arg[22]
        m.black_strength = arg[23]
        m.white_time = arg[24]
        m.black_time = arg[25]
        m.move_no = arg[26]
        m.last_move_long = arg[27]
        m.last_minute = arg[28]
        m.last_second = arg[29]
        if type(arg[30]) == "number" then
            m.last_ms = arg[30]
            m.last_move = arg[31]
            m.flip = arg[32]
        else
            m.last_ms = 0
            m.last_move = arg[30]
            m.flip = arg[31]
        end

        return {STYLE12, m}
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
takeback = (handle * " would like to take back " * number * " half move") / function (c1, c2)
    return {TAKEBACK, c1, c2} end
takeback_accept = (handle * " accepts the takeback request") / function (c)
    return {TAKEBACK_ACCEPT, c} end
takeback_decline = (handle * " declines the takeback request") / function (c)
    return {TAKEBACK_DECLINE, c} end

offer = draw + draw_accept + draw_decline + abort + abort_accept + abort_decline +
    adjourn + adjourn_accept + adjourn_decline +
    takeback + takeback_accept + takeback_decline

p = prompts + authentication + session_start + notification + chat + challenge + bughouse + game + offer
