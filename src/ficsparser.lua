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

number = R"09" ^ 1 / tonumber
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

p = prompts + authentication + session_start + notification + chat
