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
local match = lpeg.match

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
WELCOME = 10

-- Tags
TAG_ADMIN = -1
TAG_BLIND = -2
TAG_CA = -3
TAG_COMPUTER = -4
TAG_SR = -5
TAG_TM = -6

number = R"09" ^ 1 / tonumber
e = -P(1)
handle = C(R("09", "az", "AZ")^-17)
admin = P"*" / function () return TAG_ADMIN end
blind = P"B" / function () return TAG_BLIND end
ca = P"CA" / function () return TAG_CA end
computer = P"C" / function () return TAG_COMPUTER end
sr = P"SR" / function () return TAG_SR end
tm = P"TM" / function () return TAG_TM end
tag = P"(" * (admin + blind + ca + computer + sr + tm) * P")"
tags = tag^1 / function (...)
    local ret = {}
    for _, capture in ipairs(arg) do
        table.insert(ret, capture)
    end
    return ret
    end
handle_tags = handle * tags

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
handle_not_registered = handle * P"  is not a registered name" / function (c)
    return {HANDLE_NOT_REGISTERED, c} end
password_invalid = P"**** Invalid password! ****" / function (c) return {PASSWORD_INVALID} end

authentication = handle_too_short + handle_too_long + handle_not_alpha +
    handle_not_registered + password_invalid

-- Session start
welcome = (P"**** Starting FICS session as " * handle_tags) / function (...)
    return {WELCOME, unpack(arg)}
    end

p = prompts + authentication + welcome
