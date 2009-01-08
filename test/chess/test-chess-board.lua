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

-- Unit tests for chess.Board
-- Requires lunit.

require "lunit"

module("test-chess-board", lunit.testcase, package.seeall)
print"Loading chess.Board unit tests"

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

local squarei = chess.squarei
local fromsq = chess.fromsq
local tosq = chess.tosq

function setup()
    board = chess.Board{}
    -- Dummy functions making it possible to call real functions using pcall()
    -- and it makes us write shorter code :)
    clear_all = function (...) return board:clear_all(unpack(arg)) end
    clear_piece = function (...) return board:clear_piece(unpack(arg)) end
    get_piece = function (...) return board:get_piece(unpack(arg)) end
    has_piece = function (...) return board:has_piece(unpack(arg)) end
    set_piece = function (...) return board:set_piece(unpack(arg)) end
    update = function (...) return board:update(unpack(arg)) end
    update_cboard = function (...) return board:update_cboard(unpack(arg)) end
    update_occupied = function (...) return board:update_occupied(unpack(arg)) end
    loadfen = function (...) return board:loadfen(unpack(arg)) end
end

function test_01_board_object()
    assert(not pcall(chess.Board, 1))
    assert(not pcall(chess.Board, "1"))
    assert(not pcall(chess.Board, {side = "foo"}))
    assert(not pcall(chess.Board, {castle = "baz"}))
    assert(not pcall(chess.Board, {castle = {}}))
    assert(not pcall(chess.Board, {castle = {1, 2}}))
    assert(not pcall(chess.Board, {castle = {{1, 2}, {1, 2}}}))
    assert(not pcall(chess.Board, {check_legality = "bar"}))
    assert(not pcall(chess.Board, {ep = {}}))
    assert(not pcall(chess.Board, {ep = "A1"}))

    local b1 = chess.Board{}
    assert(type(b1) == "table")
    assert(b1.side == WHITE)
    assert(b1.check_legality == true)
    assert(b1.ep == -1)
    assert(type(b1.castle) == "table")
    assert(type(b1.castle[WHITE]) == "table")
    assert(type(b1.castle[WHITE]) == "table")
    assert(type(b1.castle[WHITE][1]) == "boolean")
    assert(type(b1.castle[WHITE][2]) == "boolean")
    assert(type(b1.castle[BLACK][1]) == "boolean")
    assert(type(b1.castle[BLACK][2]) == "boolean")
    assert(type(b1.rooks) == "table")
    assert(b1.rooks[1] == squarei"h1")
    assert(b1.rooks[2] == squarei"a1")
    assert(type(b1.bitboard) == "table")
    assert(type(b1.bitboard.occupied) == "table")
    for i=1,4 do assert(b1.bitboard.occupied[i] == bb(0), i) end
    assert(type(b1.bitboard.pieces) == "table")
    for i=WHITE,BLACK do
        assert(type(b1.bitboard.pieces[i]) == "table")
        for j=PAWN,KING do
            assert(b1.bitboard.pieces[i][j] == bb(0), i .. " " .. j)
        end
    end

    local b2 = chess.Board{side = BLACK, check_legality = false,
        castle = {{true, false}, {false, true}}, ep = squarei"e3",
        rooks = {squarei"g1", squarei"c1"}}
    assert(type(b2) == "table")
    assert(b2.side == BLACK)
    assert(b2.check_legality == false)
    assert(b2.ep == squarei"e3")
    assert(type(b2.castle) == "table")
    assert(type(b2.castle[WHITE]) == "table")
    assert(type(b2.castle[BLACK]) == "table")
    assert(type(b2.castle[WHITE][1]) == "boolean")
    assert(type(b2.castle[WHITE][2]) == "boolean")
    assert(type(b2.castle[BLACK][1]) == "boolean")
    assert(type(b2.castle[BLACK][2]) == "boolean")
    assert(b2.castle[WHITE][1])
    assert(not b2.castle[WHITE][2])
    assert(not b2.castle[BLACK][1])
    assert(b2.castle[BLACK][2])
    assert(type(b2.rooks) == "table")
    assert(b2.rooks[1] == squarei"g1")
    assert(b2.rooks[2] == squarei"c1")

    for sq=0,63 do assert(b2.cboard[sq+1] == 0, sq) end
end
function test_02_set_piece()
    assert(not pcall(set_piece, -1))
    assert(not pcall(set_piece, 65))
    assert(not pcall(set_piece, 13, KING + 10))
    assert(not pcall(set_piece, 13, KING, BLACK + 1))
    for sq=0,63 do
        set_piece(sq, KING, WHITE)
        assert(board.bitboard.pieces[WHITE][KING]:tstbit(sq), sq)
    end
end
function test_03_get_piece()
    assert(not pcall(get_piece, -1))
    assert(not pcall(get_piece, 65))
    for sq=0,63 do
        set_piece(sq, QUEEN, BLACK)
        assert(get_piece(sq), sq)
        assert(select("#", get_piece(sq)) == 2, sq)
        assert(get_piece(sq) == QUEEN, sq)
        assert(select(2, get_piece(sq)) == BLACK, sq)
    end
end
function test_04_clear_piece()
    assert(not pcall(clear_piece, -1))
    assert(not pcall(clear_piece, 65))
    for sq=0,63 do
        set_piece(sq, KNIGHT, WHITE)
        clear_piece(11)
        assert(not get_piece(11), sq)
    end
end
function test_05_update_cboard()
    for sq=0,63 do
        set_piece(sq, PAWN, BLACK, true)
        assert(board.cboard[sq+1] == 0)
        update_cboard()
        assert(board.cboard[sq+1] == PAWN)
    end
end
function test_06_update_occupied()
    for sq=0,63 do
        set_piece(sq, PAWN, BLACK, true)
        assert(not board.bitboard.occupied[BLACK]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[WHITE]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[3]:tstbit(sq), sq)
        update_occupied()
        assert(board.bitboard.occupied[BLACK]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[WHITE]:tstbit(sq), sq)
        assert(board.bitboard.occupied[3]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[4]:tstbit(sq), sq)
    end
end
function test_07_board_has_piece()
    assert(not pcall(has_piece, -1))
    assert(not pcall(has_piece, 65))
    assert(not pcall(has_piece, 13, BLACK + 1))
    for sq=0,63 do
        -- With update
        set_piece(sq, ROOK, BLACK)
        assert(has_piece(sq, BLACK), sq)
        assert(not has_piece(sq, WHITE), sq)
        assert(has_piece(sq), sq)
        clear_piece(sq)
        assert(not has_piece(sq, BLACK), sq)
        assert(not has_piece(sq), sq)
        -- Without update
        set_piece(sq, BISHOP, WHITE, true)
        assert(not has_piece(sq, WHITE), sq)
        assert(not has_piece(sq))
        update()
        assert(has_piece(sq, WHITE), sq)
        assert(not has_piece(sq, BLACK), sq)
        assert(has_piece(sq), sq)
        clear_piece(sq, BISHOP, WHITE, true)
        assert(has_piece(sq, WHITE), sq)
        assert(has_piece(sq), sq)
        update()
        assert(not has_piece(sq, WHITE), sq)
        assert(not has_piece(sq), sq)
    end
end
function test_08_clear_all()
    for sq=0,63 do set_piece(sq, QUEEN, WHITE) end
    clear_all()
    for sq=0,63 do
        assert(not board.bitboard.pieces[WHITE][QUEEN]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[WHITE]:tstbit(sq), sq)
        assert(not board.bitboard.occupied[3]:tstbit(sq), sq)
        assert(board.cboard[sq + 1] == 0)
    end
end
function test_09_loadfen_invalid()
    assert(not pcall(loadfen, {}))
    assert(not pcall(loadfen, "foo"))
    assert(not pcall(loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"))
    assert(not pcall(loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w"))
    assert(not pcall(loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq"))
    assert(not pcall(loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"))
    assert(not pcall(loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0"))

    -- TODO write tests for valid FENs
end
function test_10_make_move_bare()
    local m = chess.MOVE(squarei"g1", squarei"f3")
    loadfen()
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"f3"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"f3"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"f3"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"f3"))
    assert(board.cboard[squarei"f3" + 1] == KNIGHT)
    assert(not board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"g1"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"g1"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"g1"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"g1"))
    assert(board.cboard[squarei"g1" + 1] == 0)
end
function test_10_make_move_pawn2()
    local m = chess.MOVE(squarei"a2", squarei"a4")
    loadfen"r1bq1rk1/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 w - - 0 8"
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"a4"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"a4"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"a4"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"a4"))
    assert(board.cboard[squarei"a4" + 1] == PAWN)
    assert(not board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"a2"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"a2"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"a2"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"a2"))
    assert(board.cboard[squarei"a2" + 1] == 0)
    assert(board.ep == squarei"a3")
end
function test_11_make_move_capture()
    local m = chess.MOVE(squarei"e4", squarei"d5")
    m = bor(m, PAWNCAP)
    loadfen"r1bq1rk1/2p1bppp/p1n2n2/1p1pp3/4P3/1BP2N2/PP1P1PPP/RNBQR1K1 w - d6 0 9"
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"d5"))
    assert(not board.bitboard.pieces[BLACK][PAWN]:tstbit(squarei"d5"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"d5"))
    assert(not board.bitboard.occupied[BLACK]:tstbit(squarei"d5"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"d5"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"d5"))
    assert(board.cboard[squarei"d5" + 1] == PAWN)
    assert(not board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"e4"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"e4"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"e4"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"e4"))
    assert(board.cboard[squarei"e4" + 1] == 0)
end
function test_12_make_move_enpassant()
    local m = chess.MOVE(squarei"d5", squarei"c6")
    m = bor(m, ENPASSANT)
    loadfen"rnbq1rk1/pp3pbp/3p1np1/2pPp3/2P1P3/2N2N2/PP2BPPP/R1BQK2R w KQ c6 0 8"
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"c6"))
    assert(not board.bitboard.pieces[BLACK][PAWN]:tstbit(squarei"c5"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"c6"))
    assert(not board.bitboard.occupied[BLACK]:tstbit(squarei"c5"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"c6"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"c5"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"c6"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"c5"))
    assert(board.cboard[squarei"c6" + 1] == PAWN)
    assert(board.cboard[squarei"c5" + 1] == 0)
    assert(not board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"d5"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"d5"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"d5"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"d5"))
    assert(board.cboard[squarei"d5" + 1] == 0)
end
function test_13_make_move_promotion()
    local m = chess.MOVE(squarei"b7", squarei"a8")
    m = bor(m, KNIGHTPRM)
    m = bor(m, ROOKCAP)
    loadfen"rn1q1rk1/pP3pbp/3p1np1/4p3/2P1b3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 10"
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"a8"))
    assert(not board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"a8"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"a8"))
    assert(not board.bitboard.occupied[BLACK]:tstbit(squarei"a8"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"a8"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"a8"))
    assert(board.cboard[squarei"a8" + 1] == KNIGHT)
    assert(not board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"b7"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"b7"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"b7"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"b7"))
    assert(board.cboard[squarei"b7" + 1] == 0)
end
function test_14_make_move_castle()
    local m = chess.MOVE(squarei"e1", squarei"g1")
    m = bor(m, CASTLING)
    loadfen"r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 5"
    board:make_move(m)
    assert(board.bitboard.pieces[WHITE][KING]:tstbit(squarei"g1"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"g1"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"g1"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"g1"))
    assert(board.cboard[squarei"g1" + 1] == KING)
    assert(not board.bitboard.pieces[WHITE][KING]:tstbit(squarei"e1"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"e1"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"e1"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"e1"))
    assert(board.cboard[squarei"e1" + 1] == 0)
    assert(board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"f1"))
    assert(board.bitboard.occupied[WHITE]:tstbit(squarei"f1"))
    assert(board.bitboard.occupied[3]:tstbit(squarei"f1"))
    assert(not board.bitboard.occupied[4]:tstbit(squarei"f1"))
    assert(board.cboard[squarei"f1" + 1] == ROOK)
    assert(not board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"h1"))
    assert(not board.bitboard.occupied[WHITE]:tstbit(squarei"h1"))
    assert(not board.bitboard.occupied[3]:tstbit(squarei"h1"))
    assert(board.bitboard.occupied[4]:tstbit(squarei"h1"))
    assert(board.cboard[squarei"h1" + 1] == 0)
    assert(not board.castle[WHITE][1])
    assert(not board.castle[WHITE][2])
end
