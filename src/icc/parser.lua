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

--- Lpeg parser for ICC Level 2.
-- Requires lpeg.

local ipairs = ipairs
local print = print
local tonumber = tonumber
local type = type
local unpack = unpack

local string = string
local table = table
local lpeg = require "lpeg"

local C = lpeg.C
local Cg = lpeg.Cg
local Cmt = lpeg.Cmt
local Ct = lpeg.Ct
local P = lpeg.P
local R = lpeg.R
local S = lpeg.S
local match = lpeg.match
local t = lpeg.locale()

module "chess.icc.parser"

--{{{ Variables
PROMPT_LOGIN = 1001
PROMPT_PASSWORD = 1002
IAC_WILL_ECHO = 1003
IAC_WONT_ECHO = 1004
RCTE = 1005
--}}}
-- Remove ICC prompt from line
prompt = C(P"aics% "^0)
suppress_prompt = (prompt * C(P(1)^0)) / function (c1, c2)
    if c1 == "" then
        return c1 .. c2
    else
        if c2 == "" then return nil
        else return c2 end
    end
    end
--{{{ Tags
tag = C(P"GM" + P"IM" + P"FM" + P"WGM" + P"WIM" +
    P"WFM" + P"TD" + P"C" + P"U" + P"*" + P"DM" + P"H")
tags = (P"{" * (tag * P" "^0)^0 * P"}") / function (...)
    local ret = {}
    for _, capture in ipairs(arg) do
        if capture ~= "{}" then
            table.insert(ret, capture)
        end
    end
    return ret
    end
--}}}
boolean = S"01" / function (c)
    if c == "0" then return false end
    return true end
decimal = t.digit^1 / tonumber
number = (t.digit + S"+-.")^1 / tonumber
word = C(t.alnum^1)
e = -P(1)
not_space = C((t.print - P" ")^1)
handle = C((t.alnum + t.punct)^-17)
rating = (number * P" " * (S"012" / tonumber)) / function (c1, c2)
    local rating = {}
    rating.value = c1
    if c2 == 0 then
        rating.none = true
    elseif c2 == 1 then
        rating.provisional = true
    elseif c2 == 2 then
        rating.established = true
    end
    return rating
    end
rating_or_none = (P" " * rating)^0
colour = (P"-1" + P"0" + P"1") / tonumber
fancy_time_control = (P"{" * C((t.print - P"}")^0) * P"}") + C(P"?")
state = ((C(P"P") * P" " * number) +
    (C(P"E") * P" " * number) +
    (C(P"S") * P" " * number) +
    (C(P"X") * P" " * (P"0" /tonumber))) / function (c1, c2)
        local state = {}
        state.gameno = c2
        if c1 == "P" then
            state.playing = true
        elseif c1 == "E" then
            state.examining = true
        elseif c1 == "S" then
            state.simul = true
        end
        return state
    end
piece = S"rnbqkbnrpRNBQKBNRP-"
board = C(piece^64) / function (c)
    local board = {}

    for i=8,1,-1 do
        local pieces = string.sub(c, 1, 8)
        c = string.sub(c, 9)
        local rank = string.byte"a"
        while rank <= string.byte"h" do
            board[string.char(rank) .. i] = string.sub(pieces, i, i)
            rank = rank + 1
        end
    end
    return board
    end
score_string = C(P"1-0" + P"0-1" + P"1/2-1/2" + P"*" + P"aborted")
symbol = C(P"O" + P"PW" + P"PB" + P"SW" + P"SB" + P"E" + P"X")
move = (not_space^0 * P" "^0 * not_space^0 * P" "^0 *
    number^0 * P" "^0 * number^0 * P" "^0 * number^0) /
    function (...) return arg end
qmove = P"{" * move * P"}"
initial_position = C(P"*") + board

-- Telnet
iac_will_echo = P(string.char(255, 251, 1)) / function ()
    return {IAC_WILL_ECHO} end
iac_wont_echo = P(string.char(255, 252, 1)) / function ()
    return {IAC_WONT_ECHO} end
rcte = P(string.char(7)) / function ()
    return {RCTE} end
telnet = iac_will_echo + iac_wont_echo + rcte

-- Prompts
login = (P"login: " * e) / function (c) return {PROMPT_LOGIN} end
password = P"password: " * e / function (c) return {PROMPT_PASSWORD} end
prompts = login + password

-- Datagrams
bd = string.char(25) .. "("
ed = string.char(25) .. ")"
bc = string.char(25) .. "{"
ec = string.char(25) .. "}"

msg = bc * C((P(1) - P(string.char(25)))^0) * ec
smsg = "{" * C((P(1) - P"}")^0) * P"}"

dg_whoami = (bd * P"0 " * handle * P" " * tags) / function (c1, c2)
    return {0, c1, c2} end
dg_login_failed = (bd * P"69 " * number * P" " * smsg) / function (c1, c2)
    return {69, c1, c2} end

-- Player Sets
dg_player_arrived = (bd * P"1 " * handle * rating_or_none *
    rating_or_none * rating_or_none * rating_or_none * rating_or_none *
    rating_or_none * rating_or_none * rating_or_none * rating_or_none *
    rating_or_none * rating_or_none * P" "^0 * boolean^0 * P" "^0 *
    state^0 * P" "^0 * number^0) / function (...)
        return {1, unpack(arg)} end
dg_player_left = (bd * P"2 " * handle) / function (c)
    return {2, c} end
dg_titles = (bd * P"9 " * handle * P" " * tags) / function (c1, c2)
    return {9, c1, c2} end
dg_player_arrived_simple = (bd * P"55 " * handle) / function (c)
    return {55, c} end

-- Game Lists
dg_game_started = (bd * P"12 " * number * P" " * handle * P" " * handle *
    P" " * number * P" " * not_space * P" " * boolean * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * boolean * P" " * msg * P" " *
    number * P" " * number * P" " * number * P" " * tags * P" " * tags * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * fancy_time_control * P" " *
    boolean) / function (...)
        local game = {
            no = arg[1],
            wild_type = arg[4],
            type = arg[5],
            rated = arg[6],
            white_time = arg[7],
            white_increment = arg[8],
            black_time = arg[9],
            black_increment = arg[10],
            played = arg[11],
            ex_string = arg[12],
            id = arg[15],
            irregular_legality = arg[18],
            irregular_semantics = arg[19],
            uses_plunkers = arg[20],
            fancy_time_control = arg[21],
            promote_to_king = arg[22],
        }
        local player1 = { handle = arg[2], rating = arg[13], tags = arg[16] }
        local player2 = { handle = arg[3], rating = arg[14], tags = arg[17] }
        return {12, game, player1, player2}
    end
dg_game_result = (bd * P"13 " * number * P" " * boolean * P" " * word *
    P" " * score_string * P" " * msg * P" " * msg) / function (...)
        local game = {
            no = arg[1],
            examined = arg[2],
            result = arg[3],
            score = arg[4],
            description = arg[5],
            eco = arg[6],
        }
        return {13, game}
    end
dg_examined_game_is_gone = (bd * P"14 " * number) / function (c)
    return {14, c} end

-- My Games
dg_my_game_started = (bd * P"15 " * number * P" " * handle * P" " * handle *
    P" " * number * P" " * not_space * P" " * boolean * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * boolean * P" " * msg * P" " *
    number * P" " * number * P" " * number * P" " * tags * P" " * tags * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * fancy_time_control * P" " *
    boolean) / function (...)
        local game = {
            no = arg[1],
            wild_type = arg[4],
            type = arg[5],
            rated = arg[6],
            white_time = arg[7],
            white_increment = arg[8],
            black_time = arg[9],
            black_increment = arg[10],
            played = arg[11],
            ex_string = arg[12],
            id = arg[15],
            irregular_legality = arg[18],
            irregular_semantics = arg[19],
            uses_plunkers = arg[20],
            fancy_time_control = arg[21],
            promote_to_king = arg[22],
        }
        local player1 = { handle = arg[2], rating = arg[13], tags = arg[16] }
        local player2 = { handle = arg[3], rating = arg[14], tags = arg[17] }
        return {15, game, player1, player2}
    end
dg_my_game_result = (bd * P"16 " * number * P" " * boolean * P" " * word *
    P" " * score_string * P" " * msg * P" " * msg) / function (...)
        local game = {
            no = arg[1],
            examined = arg[2],
            result = arg[3],
            score = arg[4],
            description = arg[5],
            eco = arg[6],
        }
        return {16, game}
    end
dg_my_game_ended = (bd * P"17 " * number) / function (c) return {17, c} end
dg_started_observing = (bd * P"18 " * number * P" " * handle * P" " * handle *
    P" " * number * P" " * not_space * P" " * boolean * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * boolean * P" " * msg * P" " *
    number * P" " * number * P" " * number * P" " * tags * P" " * tags * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * fancy_time_control * P" " *
    boolean) / function (...)
        local game = {
            no = arg[1],
            wild_type = arg[4],
            type = arg[5],
            rated = arg[6],
            white_time = arg[7],
            white_increment = arg[8],
            black_time = arg[9],
            black_increment = arg[10],
            played = arg[11],
            ex_string = arg[12],
            id = arg[15],
            irregular_legality = arg[18],
            irregular_semantics = arg[19],
            uses_plunkers = arg[20],
            fancy_time_control = arg[21],
            promote_to_king = arg[22],
        }
        local player1 = { handle = arg[2], rating = arg[13], tags = arg[16] }
        local player2 = { handle = arg[3], rating = arg[14], tags = arg[17] }
        return {18, game, player1, player2}
    end
dg_stop_observing = (bd * P"19 " * number) / function (c) return {19, c} end
dg_isolated_board = (bd * P"40 " * number * P" " * handle * P" " * handle *
    P" " * number * P" " * not_space * P" " * boolean * P" " * number * P" " *
    number * P" " * number * P" " * number * P" " * boolean * P" " * msg * P" " *
    number * P" " * number * P" " * number * P" " * tags * P" " * tags * P" " *
    boolean * P" " * boolean * P" " * boolean * P" " * fancy_time_control * P" " *
    boolean) / function (...)
        local game = {
            no = arg[1],
            wild_type = arg[4],
            type = arg[5],
            rated = arg[6],
            white_time = arg[7],
            white_increment = arg[8],
            black_time = arg[9],
            black_increment = arg[10],
            played = arg[11],
            ex_string = arg[12],
            id = arg[15],
            irregular_legality = arg[18],
            irregular_semantics = arg[19],
            uses_plunkers = arg[20],
            fancy_time_control = arg[21],
            promote_to_king = arg[22],
        }
        local player1 = { handle = arg[2], rating = arg[13], tags = arg[16] }
        local player2 = { handle = arg[3], rating = arg[14], tags = arg[17] }
        return {40, game, player1, player2}
    end
dg_players_in_my_game = (bd * P"20 " * number * P" " * handle * P" " * symbol *
    P" " * number) /
    function (...) return {20, unpack(arg)} end
dg_offers_in_my_game = (bd * P"21 " * number * P" " * boolean * P" " * boolean *
    P" " * boolean * P" " * boolean * P" " * boolean * P" " * boolean * P" " *
    decimal * P" " * decimal) / function (...)
        local offer = {
            gameno = arg[1],
            white_draw = arg[2],
            black_draw = arg[3],
            white_adjourn = arg[4],
            black_adjourn = arg[5],
            white_abort = arg[6],
            black_abort = arg[7],
            white_takeback = arg[8],
            black_takeback = arg[9],
        }
        return {21, offer}
    end
dg_takeback = (bd * P"22 " * decimal) / function (c) return {22, c} end
dg_backward = (bd * P"23 " * decimal) / function (c) return {23, c} end
dg_send_moves = (bd * P"24 " * number * P" "^0 * move) /
    function (...) return {24, unpack(arg)} end
dg_move_list = (bd * P"25 " * number * P" " * initial_position *
    P" "^0 * qmove^0) /
    function (...)
        local moves = {}
        for i=3,#arg do moves[i-2] = arg[i] end
        return {25, arg[1], arg[2], moves}
    end
-- TODO dg_bughouse_holdings
-- TODO dg_bughouse_pass
dg_kibitz = (bd * P"26 " * number* P" " * handle * P" " * tags * P" " * boolean *
    P" " * msg) / function (...) return {26, unpack(arg)} end
dg_set_clock = (bd * P"38 " * number * P" " * number * P" " * number) /
    function (c1, c2, c3) return {38, c1, c2, c3} end
dg_flip = (bd * P"39 " * number * P" " * boolean) / function (c1, c2)
    return {39, c1, c2} end
dg_refresh = (bd * P"41 " * number) / function (c) return {41, c} end
dg_illegal_move = (bd * P"42 " * number * P" " * not_space * P" " * number) /
    function (c1, c2, c3) return {42, c1, c2, c3} end
dg_my_relation_to_game = (bd * P"43 " * number * P" " * symbol) /
    function (c1, c2) return {43, c1, c2} end
dg_partnership = (bd * P"44 " * handle * P" " * handle * P" " * boolean) /
    function (c1, c2, c3) return {44, c1, c2, c3} end
dg_jboard = (bd * P"49 " * number * P" " * board * P" " * C(S"WB") * P" " *
    number * P" " * boolean * P" " * boolean * P" " * boolean * P" " *
    boolean * P" " * number * P" " * not_space * P" " * not_space * P" " *
    number * P" " * number * P" " * number * P" " * boolean) /
    function (...)
        local game = {
            no = arg[1],
            board = arg[2],
            tomove = arg[3],
            double_pawn_push = arg[4],
            white_castle = arg[5],
            white_long_castle = arg[6],
            black_castle = arg[7],
            black_long_castle = arg[8],
            move_no = arg[9],
            last_move = arg[10],
            last_move_smith = arg[11],
            white_time = arg[12],
            black_time = arg[13],
            status = arg[14],
            flip = arg[15],
        }
        return {49, game}
    end
dg_fen = (bd * P"70 " * number * P" " * smsg) / function (c1, c2)
    return {70, c1, c2} end
dg_msec = (bd * P"56 " * number * P" " * C(S"WB") * P" " * number * P" " *
    boolean) / function (...) return {56, unpack(arg)} end
dg_moretime = (bd * P"61 " * number * P" " * C(S"WB") * P" " * number) /
    function (c1, c2, c3) return {61, c1, c2, c3} end

-- Channels
dg_channel_tell = (bd * P"28 " * number * P" " * handle *
    P" " * tags * P" " * bc * C((t.print - P"}")^1) * ec *
    P" " * number) / function (...)
        return {28, unpack(arg)} end
dg_people_in_my_channel = (bd * P"27 " * number * P" " * handle *
    P" " * (S"01" / tonumber)) / function (...)
        return {27, unpack(arg)} end
dg_channels_shared = (bd * P"46 " * handle * P" " *
    (number * P" "^0)^1) / function (...)
        local channels = {}
        for i=2,#arg do
            table.insert(channels, arg[i])
        end
        return {46, arg[1], channels}
    end
dg_sees_shouts = (bd * P"45 " * handle * P" " * number) /
    function (c1, c2) return {45, c1, c2} end
dg_channel_qtell = (bd * P"82 " * number * P" " * handle * P" " * tags *
    P" " * msg) / function (...) return {82, unpack(arg)} end

-- Matches
dg_match = (bd * P"29 " * handle * P" " * rating * P" " * tags *
    P" " * handle * P" " * rating * P" " * tags * P" " * number *
    P" " * word * P" " * boolean * P" " * boolean * P" " * number *
    P" " * number * P" " * number * P" " * number * P" " * colour *
    (P" " * number * P" " * number * P" " * number)^0 *
    P" " * fancy_time_control) / function (...)
        local game = {}

        local player1, player2
        player1 = {handle = arg[1], rating = arg[2], tags = arg[3]}
        player2 = {handle = arg[4], rating = arg[5], tags = arg[6]}

        game.wild_type = arg[7]
        game.type = arg[8]
        game.rated = arg[9]
        game.adjourned = arg[10]
        game.challenger_time = arg[11]
        game.challenger_increment = arg[12]
        game.receiver_time = arg[13]
        game.receiver_increment = arg[14]
        game.colour = arg[15]

        if type(arg[16]) == "number" then
            -- DG_MATCH_ASSESSMENT is set
            game.loss = arg[16]
            game.draw = arg[17]
            game.win = arg[18]
            game.fancy_time_control = arg[19]
        else
            game.fancy_time_control = arg[16]
        end

        return {29, game, player1, player2}
    end
dg_match_removed = (bd * P"30 " * handle * P" " * handle * P" " *
    msg) / function (...)
        return {30, unpack(arg)} end
dg_seek = (bd * P"50 " * number * P" " * handle * P" " * tags * P" " *
    rating * P" " * number * P" " * word * P" " * number * P" " * number *
    P" " * boolean * P" " * colour * P" " * number * P" " * number * P" " *
    boolean * P" " * boolean * P" " * fancy_time_control) / function (...)
        local seek = {}
        local player = {}

        seek.index = arg[1]
        player = {handle = arg[2], tags = arg[3], rating = arg[4]}
        seek.wild_type = arg[5]
        seek.type = arg[6]
        seek.time = arg[7]
        seek.increment = arg[8]
        seek.rated = arg[9]
        seek.colour = arg[10]
        seek.rating_range = {arg[11], arg[12]}
        seek.auto_accept = arg[13]
        seek.formula_checked = arg[14]
        seek.fancy_time_control = arg[15]

        return {50, seek, player}
    end
dg_seek_removed = (bd * P"51 " * number * P" " * number) / function (c1, c2)
    return {51, c1, c2} end
-- TODO dg_my_rating
-- TODO dg_new_my_rating

-- Communication
dg_personal_tell = (bd * P"31 " * handle * P" " * tags *
    P" " * msg * P" " * number) / function (...)
        return {31, unpack(arg)} end
dg_personal_tell_echo = (bd * P"62 " * handle * P" " * number *
    P" " * msg) / function (...)
        return {62, unpack(arg)} end
dg_shout = (bd * P"32 " * handle * P" " * tags * P" " * number *
    P" " * msg) / function (...)
        return {32, unpack(arg)} end
dg_personal_qtell = (bd * P"83 " * handle * P" " * tags * P" " * msg) /
    function (c1, c2, c3) return {83, c1, c2, c3} end

-- Miscallenous
dg_my_variable = (bd * P"47 " * word * P" " * number) / function (...)
    return {47, unpack(arg)} end
dg_my_string_variable = (bd * P"48 " * word * P" " * msg) / function (...)
    return {48, unpack(arg)} end
dg_sound = (bd * P"53 " * number) / function (c)
    return {53, c} end

dg_suggestion = (bd * P"63 " * msg * P" " * msg * P" " * number *
    P" " * handle * P" " * msg * P" " * msg) / function (...)
        return {63, unpack(arg)} end
dg_wsuggest = (bd * P"91 " * msg * P" " * msg * P" " * number *
    P" " * handle * P" " * msg * P" " * msg) / function (...)
        return {91, unpack(arg)} end

dg_arrow = (bd * P"60 " * number * P" " * handle * P" " *
    word * P" " * word) / function (...)
        return {60, unpack(arg)} end
dg_unarrow = (bd * P"90 " * number * P" " * handle * P" " *
    word * P" " * word) / function (...)
        return {90, unpack(arg)} end
dg_circle = (bd * P"59 " * number * P" " * handle * P" " *
    word) / function (...) return {59, unpack(arg)} end
dg_uncircle = (bd * P"89 " * number * P" " * handle * P" " *
    word) / function (...) return {89, unpack(arg)} end

-- Notify list DGs and other new stuff
dg_notify_arrived = (bd * P"64 " * handle * rating_or_none *
    rating_or_none * rating_or_none * rating_or_none * rating_or_none *
    rating_or_none * rating_or_none * rating_or_none * rating_or_none *
    rating_or_none * rating_or_none * P" "^0 * boolean^0 * P" "^0 *
    state^0 * P" "^0 * number^0) / function (...)
        return {64, unpack(arg)} end
dg_notify_left = (bd * P"65 " * handle) / function (c)
    return {65, c} end
dg_notify_open = (bd * P"66 " * handle * P" " * boolean) / function (c1, c2)
    return {66, c1, c2} end
dg_notify_state = (bd * P"67 " * handle * P" " * state) / function (c1, c2)
    return {67, c1, c2} end

dash = C(P"-")
gcommand = C(P"search" + P"history" + P"liblist" + P"stored")
date = ((decimal * P"." * decimal * P"." * decimal) + P"?") / function (...)
    local date
    if #arg == 3 then
        date = {year = arg[1], month = arg[2], day = arg[3]}
    else
        date = {year = 0, month = 0, day = 0}
    end
    return date
    end
time = ((decimal * P":" * decimal * P":" * decimal) + P"?") / function (...)
    local time
    if #arg == 3 then
        time = {hour = arg[1], minute = arg[2], second = arg[3]}
    end
    return time
    end
dg_gamelist_begin = (bd * P"72 " * gcommand * P" " * smsg * P" " * number *
    P" " * number * P" " * number * P" " * smsg) / function (...)
        return {72, unpack(arg)} end
dg_gamelist_item = (bd * P"73 " * number * P" " * number * P" " * not_space *
    P" " * date * P" " * time * P" " * handle * P" " * number * P" " * handle *
    P" " * number * P" " * boolean * P" " * number * P" " * number * P" " *
    (number + dash) * P" " * (number + dash)* P" " * (number + dash) * P" " *
    (number + dash) * P" " * not_space * P" " * number * P" " * number * P" " *
    number * P" " * msg * P" " * boolean) /
    function (...)
        local item = {
            index = arg[1],
            id = arg[2],
            event = arg[3],
            date = arg[4],
            time = arg[5],
            white_handle = arg[6],
            white_rating = arg[7],
            black_handle = arg[8],
            black_rating = arg[9],
            rated = arg[10],
            rating_type = arg[11],
            wild_type = arg[12],
            white_time = arg[13],
            white_increment = arg[14],
            black_time = arg[15],
            black_increment = arg[16],
            eco = arg[17],
            status = arg[18],
            colour = arg[19],
            mode = arg[20],
            note = arg[21],
            here = arg[22],
        }
        return {73, item}
    end
-- TODO dg_idle
-- TODO dg_ack_ping
dg_rating_type_key = (bd * P"76 " * number * P" " * not_space) /
    function (c1, c2) return {76, c1, c2} end
dg_wild_key = (bd * P"116 " * number * P" " * smsg) / function (c1, c2)
    return {116, c1, c2} end
dg_game_message = (bd * P"77 " * number * P" " * msg) / function (c1, c2)
    return {77, c1, c2} end
-- TODO dg_string_list_begin
-- TODO dg_string_list_item
dg_dummy_response = (bd * P"81") / function () return {81} end
dg_set_board = (bd * P"84 " * number * P" " * board * P" " * C(S"WB")) /
    function (c1, c2, c3)
        return {84, {no = c1, board = c2, tomove = c3}}
    end
dg_log_pgn = (bd * P"86 " * msg^1) / function (...)
    return {86, arg} end
dg_messagelist_begin = (bd * P"94 " * msg) / function (c) return {94, c} end
-- header is not used yet so don't parse it :)
dg_messagelist_item = (bd * P"95 " * number * P" " * handle * P" " *
    number * P":" * number * P" " * decimal * P"-" * word * P"-" * decimal *
    P" " * msg) / function (...)
        local message = {
            no = arg[1],
            sender = arg[2],
            hour = arg[3],
            minute = arg[4],
            day = arg[5],
            month = arg[6],
            year = arg[7],
            text = arg[8],
        }
        return {95, message}
    end
dg_list = (bd * P"96 " * smsg * P" " * smsg * msg^0) / function (...)
    local list = {header = arg[1], rowstart = arg[2]}
    for i=3,#arg do list[i-2] = arg[i] end
    return {96, list}
    end
-- TODO dg_sji_ad
-- TODO dg_qretract
-- TODO dg_my_game_change
-- TODO dg_position_begin
dg_tourney = (bd * P"103 " * number * P" " * number * P" " * msg * P" " *
    msg * P" " * msg * P" " * msg * P" " * msg) / function (...)
        return {103, unpack(arg)} end
dg_remove_tourney = (bd * P"104 " * number) / function (c) return {104, c} end

-- Dialog Windows
-- TODO dg_dialog_start
-- TODO dg_dialog_data
-- TODO dg_dialog_default
-- TODO dg_dialog_end
-- TODO dg_dialog_release

-- TODO dg_position_begin2
-- TODO dg_past_move
-- TODO dg_pgn_tag

dg_password = (bd * P"114 " * msg * P" " * handle) / function (c1, c2)
    return {114, c1, c2} end
-- TODO dg_switch_servers
-- TODO dg_set2
dg_mugshot = (bd * P"128 " * handle * P" " * msg * P" " * number) /
    function (c1, c2, c3) return {128, c1, c2, c3} end
dg_command = (bd * P"136 " * msg * P" " * msg) / function (c1, c2)
    return {136, c1, c2} end
-- TODO dg_tourney_game_started
-- TODO dg_tourney_game_ended
-- TODO dg_my_turn
-- TODO dg_disable_premove (can't be disabled! modify client:set())

--[[ XXX How do you figure out what rating type a result group is?
result_group = (decimal * P" ")^6 * decimal
result_groups = (result_group * P" | "^0)^0
dg_pstat = (bd * P"142 " * decimal * P" " * handle * P" " * handle * P" "^0 *
    result_groups)
--]]

dg_boardinfo = (bd * P"143 " * number * P" " * handle * P" " * number * P" " *
    word * P" " * word * P" " * number) / function (...)
        return {143, unpack(arg)} end
dg_move_lag = (bd * P"144 " * handle * P" " * number) / function (c1, c2)
    return {144, c1, c2} end

