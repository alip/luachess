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

-- Unit tests for chess module.
-- Requires lunit.

require "lunit"

module("test-chess", lunit.testcase, package.seeall)
print"Loading chess unit tests"

require "bit"
require "chess"

local band, bnot, bor, bxor, lshift, rshift = bit.band, bit.bnot, bit.bor, bit.bxor,
    bit.lshift, bit.rshift

local bb = chess.bitboard.bb

local WHITE = chess.WHITE
local BLACK = chess.BLACK

local PAWN = chess.PAWN
local KNIGHT = chess.KNIGHT
local BISHOP = chess.BISHOP
local ROOK = chess.ROOK
local QUEEN = chess.QUEEN
local KING = chess.KING

local KNIGHTPRM = chess.KNIGHTPRM
local BISHOPPRM = chess.BISHOPPRM
local ROOKPRM = chess.ROOKPRM
local QUEENPRM = chess.QUEENPRM
local PROMOTION = chess.PROMOTION
local PAWNCAP = chess.PAWNCAP
local KNIGHTCAP = chess.KNIGHTCAP
local BISHOPCAP = chess.BISHOPCAP
local ROOKCAP = chess.ROOKCAP
local QUEENCAP = chess.QUEENCAP
local KINGCAP = chess.KINGCAP
local CAPTURE = chess.CAPTURE
local NULLMOVE = chess.NULLMOVE
local CASTLING = chess.CASTLING
local ENPASSANT = chess.ENPASSANT

function test_01_switch_side()
    assert(chess.switch_side(WHITE) == BLACK)
    assert(chess.switch_side(BLACK) == WHITE)
end
function test_02_piece_tostring()
    assert(chess.piece_tostring(KING, WHITE) == "K")
    assert(chess.piece_tostring(KING, BLACK) == "k")
    assert(chess.piece_tostring(QUEEN, WHITE) == "Q")
    assert(chess.piece_tostring(QUEEN, BLACK) == "q")
    assert(chess.piece_tostring(ROOK, WHITE) == "R")
    assert(chess.piece_tostring(ROOK, BLACK) == "r")
    assert(chess.piece_tostring(BISHOP, WHITE) == "B")
    assert(chess.piece_tostring(BISHOP, BLACK) == "b")
    assert(chess.piece_tostring(KNIGHT, WHITE) == "N")
    assert(chess.piece_tostring(KNIGHT, BLACK) == "n")
    assert(chess.piece_tostring(PAWN, WHITE) == "P")
    assert(chess.piece_tostring(PAWN, BLACK) == "p")
    assert(not pcall(chess.piece_tostring, 13, WHITE))
    assert(not pcall(chess.piece_tostring, KING, 3))
end
function test_03_piece_toindex()
    assert(chess.piece_toindex"K" == KING)
    assert(chess.piece_toindex"k" == KING)
    assert(chess.piece_toindex"Q" == QUEEN)
    assert(chess.piece_toindex"q" == QUEEN)
    assert(chess.piece_toindex"R" == ROOK)
    assert(chess.piece_toindex"r" == ROOK)
    assert(chess.piece_toindex"B" == BISHOP)
    assert(chess.piece_toindex"b" == BISHOP)
    assert(chess.piece_toindex"N" == KNIGHT)
    assert(chess.piece_toindex"n" == KNIGHT)
    assert(chess.piece_toindex"P" == PAWN)
    assert(chess.piece_toindex"p" == PAWN)
    assert(not pcall(chess.piece_toindex, "L"))
end
function test_04_rank()
    for sq=0,7 do assert(chess.rank(sq) == 1) end
    for sq=8,15 do assert(chess.rank(sq) == 2) end
    for sq=16,23 do assert(chess.rank(sq) == 3) end
    for sq=24,31 do assert(chess.rank(sq) == 4) end
    for sq=32,39 do assert(chess.rank(sq) == 5) end
    for sq=40,47 do assert(chess.rank(sq) == 6) end
    for sq=48,55 do assert(chess.rank(sq) == 7) end
    for sq=56,63 do assert(chess.rank(sq) == 8) end
end
function test_05_file()
    for sq=0,56,8 do assert(chess.file(sq) == 1) end
    for sq=1,57,8 do assert(chess.file(sq) == 2) end
    for sq=2,58,8 do assert(chess.file(sq) == 3) end
    for sq=3,59,8 do assert(chess.file(sq) == 4) end
    for sq=4,60,8 do assert(chess.file(sq) == 5) end
    for sq=5,61,8 do assert(chess.file(sq) == 6) end
    for sq=6,62,8 do assert(chess.file(sq) == 7) end
    for sq=7,63,8 do assert(chess.file(sq) == 8) end
end
function test_06_filec()
    for sq=0,56,8 do assert(chess.filec(sq) == "a") end
    for sq=1,57,8 do assert(chess.filec(sq) == "b") end
    for sq=2,58,8 do assert(chess.filec(sq) == "c") end
    for sq=3,59,8 do assert(chess.filec(sq) == "d") end
    for sq=4,60,8 do assert(chess.filec(sq) == "e") end
    for sq=5,61,8 do assert(chess.filec(sq) == "f") end
    for sq=6,62,8 do assert(chess.filec(sq) == "g") end
    for sq=7,63,8 do assert(chess.filec(sq) == "h") end
end
function test_07_squarei()
    for sq=0,63 do
        local sc = chess.squarec(sq)
        assert(chess.squarei(sc) == sq)
    end
end
function test_08_square_left()
    assert(not pcall(chess.square_left, {}))
    assert(not pcall(chess.square_left, -1))
    assert(not pcall(chess.square_left, 64))
    for sq=0,63 do
        if sq % 8 == 0 then assert(not chess.square_left(sq))
        else assert(chess.square_left(sq) == sq - 1) end
    end
end
function test_09_square_right()
    assert(not pcall(chess.square_right, {}))
    assert(not pcall(chess.square_right, -1))
    assert(not pcall(chess.square_right, 64))
    for sq=0,63 do
        if sq % 8 == 7 then assert(not chess.square_right(sq))
        else assert(chess.square_right(sq) == sq + 1) end
    end
end
function test_10_square_up()
    assert(not pcall(chess.square_up, {}))
    assert(not pcall(chess.square_up, -1))
    assert(not pcall(chess.square_up, 64))
    for sq=0,63 do
        if sq > 54 then assert(not chess.square_up(sq))
        else assert(chess.square_up(sq) == sq + 8) end
    end
end
function test_11_square_down()
    assert(not pcall(chess.square_down, {}))
    assert(not pcall(chess.square_down, -1))
    assert(not pcall(chess.square_down, 64))
    for sq=0,63 do
        if sq < 8 then assert(not chess.square_down(sq))
        else assert(chess.square_down(sq) == sq - 8) end
    end
end
function test_12_square_border()
    assert(not pcall(chess.square_border, {}))
    assert(not pcall(chess.square_border, -1))
    assert(not pcall(chess.square_border, 64))
    for sq=0,63 do
        local f, r = chess.file(sq), chess.rank(sq)
        if f == 1 or f == 8 or r == 1 or r == 8 then
            assert(chess.square_border(sq))
        else
            assert(not chess.square_border(sq))
        end
    end
end
function test_13_move()
    local m = chess.MOVE(chess.squarei"e2", chess.squarei"e4")
    assert(chess.fromsq(m) == chess.squarei"e2")
    assert(chess.tosq(m) == chess.squarei"e4")
    -- TODO this could use more tests
end
function test_14_capture_piece()
    local m = chess.MOVE(chess.squarei"f3", chess.squarei"e5")
    assert(chess.capture_piece(bor(m, PAWNCAP)) == PAWN)
    assert(chess.capture_piece(bor(m, KNIGHTCAP)) == KNIGHT)
    assert(chess.capture_piece(bor(m, BISHOPCAP)) == BISHOP)
    assert(chess.capture_piece(bor(m, ROOKCAP)) == ROOK)
    assert(chess.capture_piece(bor(m, QUEENCAP)) == QUEEN)
    assert(chess.capture_piece(bor(m, KINGCAP)) == KING)
end
function test_14_promote_piece()
    local m = chess.MOVE(chess.squarei"e7", chess.squarei"e8")
    assert(chess.promote_piece(bor(m, KNIGHTPRM)) == KNIGHT)
    assert(chess.promote_piece(bor(m, BISHOPPRM)) == BISHOP)
    assert(chess.promote_piece(bor(m, ROOKPRM)) == ROOK)
    assert(chess.promote_piece(bor(m, QUEENPRM)) == QUEEN)
end

