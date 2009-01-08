#!/usr/bin/env lua
-- vim: set et sts=4 sw=4 ts=4 tw=80 fdm=marker:
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

-- Move parsing module for LuaChess
-- Requires lpeg.

--{{{Grab environment
local ipairs = ipairs
local tonumber = tonumber
local unpack = unpack

-- XXX for debugging
local print = print

local attack = require "attack"
local lpeg = require "lpeg"
--}}}

module "move"

--{{{Globals
local WHITE = attack.WHITE
local BLACK = attack.BLACK

local PAWN = attack.PAWN
local KNIGHT = attack.KNIGHT
local BISHOP = attack.BISHOP
local ROOK = attack.ROOK
local QUEEN = attack.QUEEN
local KING = attack.KING
--}}}
--{{{Shortcuts
local C, Ct, P, R, S = lpeg.C, lpeg.Ct, lpeg.P, lpeg.R, lpeg.S
--}}}
--{{{Common patterns
number = R"09"^1 / tonumber
coord = R"ah"
rank = R"18"
square = coord * rank
coord_only = coord - square
return_false = P(true) / function () return false end
return_true = P(true) / function () return true end
--}}}
--{{{SAN - Standard algebraic notation
san_king = P"K" / function () return KING end
san_queen = P"Q" / function () return QUEEN end
san_rook = P"R" / function () return ROOK end
san_bishop = P"B" / function () return BISHOP end
san_knight = P"N" / function () return KNIGHT end
san_pawn = P(true) / function () return PAWN end
san_piece = san_king + san_queen + san_rook + san_bishop + san_knight
san_capture = C(P"x") / function () return true end + return_false
san_check = C(P"+")
san_checkmate = C(P"#")
san_checkormate = (san_check + san_checkmate)^0
san_castle_short = C(P"O-O")
san_castle_long = C(P"O-O-O")
san_disambiguity = C(square) + C(coord) + C(rank)
san_promotion = (P"=" * (san_knight + san_bishop + san_rook + san_queen)) + return_false

san_move_pawn = (san_pawn * (C(coord_only) + return_false) * san_capture * C(square) *
    san_promotion * san_checkormate) /
    function (piece, from, capture, to, promotion, check)
        return {piece = piece,
            from = from,
            capture = capture,
            promotion = promotion,
            to = to,
            check = check,
        }
    end
san_move_piece = (san_piece * san_capture * C(square) * san_checkormate) /
    function (piece, capture, to, check)
        return {piece = piece,
            capture = capture,
            to = to,
            check = check,
        }
    end
san_move_piece_amb = (san_piece * san_disambiguity * san_capture * C(square) *
    san_checkormate) /
    function (piece, from, capture, to, check)
        return {piece = piece,
            from = from,
            capture = capture,
            to = to,
            check = check
        }
    end
san_move_castle = (san_castle_long + san_castle_short) /
    function (c)
        if c == "O-O" then return {castle_short = true}
        else return {castle_long = true} end
    end
san_move = san_move_pawn + san_move_piece_amb + san_move_piece + san_move_castle
--}}}
--{{{FEN - Forsyth-Edwards Notation
-- Pieces
fen_king_white = P"K" / function () return KING, WHITE end
fen_king_black = P"k" / function () return KING, BLACK end
fen_king = fen_king_white + fen_king_black
fen_queen_white = P"Q" / function () return QUEEN, WHITE end
fen_queen_black = P"q" / function () return QUEEN, BLACK end
fen_queen = fen_queen_white + fen_queen_black
fen_rook_white = P"R" / function () return ROOK, WHITE end
fen_rook_black = P"r" / function () return ROOK, BLACK end
fen_rook = fen_rook_white + fen_rook_black
fen_bishop_white = P"B" / function () return BISHOP, WHITE end
fen_bishop_black = P"b" / function () return BISHOP, BLACK end
fen_bishop = fen_bishop_white + fen_bishop_black
fen_knight_white = P"N" / function () return KNIGHT, WHITE end
fen_knight_black = P"n" / function () return KNIGHT, BLACK end
fen_knight = fen_knight_white + fen_knight_black
fen_pawn_white = P"P" / function () return PAWN, WHITE end
fen_pawn_black = P"p" / function () return PAWN, BLACK end
fen_pawn = fen_pawn_white + fen_pawn_black
fen_piece = Ct(fen_king + fen_queen + fen_rook + fen_bishop + fen_knight + fen_pawn)
-- Ranks
fen_rank_sep = P"/"
fen_digit = rank / tonumber
fen_rank = (fen_piece + fen_digit)^-8 /
    function (...)
        -- Reverse the elements
        -- Because FEN lists them from a to h, we need h to a
        local t = {}
        local i = 1
        for j=#arg,1,-1 do
            t[i] = arg[j]
            i = i + 1
        end
        return unpack(t)
    end
fen_piece_placement = ((fen_rank * fen_rank_sep)^7 * fen_rank) /
    function(...) return function () return ipairs(arg) end end
-- Side to move
fen_side_white = P"w" / function () return WHITE end
fen_side_black = P"b" / function () return BLACK end
fen_side = fen_side_white + fen_side_black
-- Castling rights
fen_castle = (P"-" + Ct(fen_king + fen_queen)^-4) /
    function(...) return function () return ipairs(arg) end end
fen_epsquare = C(P"-" + (coord * S"36"))
-- Reversible halfmove counter
fen_rhc = number
-- Fullmove counter
fen_fmc = number

fen = fen_piece_placement * P" " * fen_side * P" " * fen_castle * P" " *
    fen_epsquare * P" " * fen_rhc * P" " * fen_fmc
--}}}
