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
-- Requires luaunit.

require "luaunit"
require "customloaders"

require "bit"
require "chess"

local bor = bit.bor

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

TestChessBoard = {} -- class
    function TestChessBoard:setUp()
        self.board = chess.Board{}
        -- Dummy functions making it possible to call real functions using pcall()
        -- and it makes us write shorter code :)
        self.clear_all = function (...) return self.board:clear_all(unpack(arg)) end
        self.clear_piece = function (...) return self.board:clear_piece(unpack(arg)) end
        self.get_piece = function (...) return self.board:get_piece(unpack(arg)) end
        self.has_piece = function (...) return self.board:has_piece(unpack(arg)) end
        self.set_piece = function (...) return self.board:set_piece(unpack(arg)) end
        self.update = function (...) return self.board:update(unpack(arg)) end
        self.update_cboard = function (...)
            return self.board:update_cboard(unpack(arg)) end
        self.update_occupied = function (...)
            return self.board:update_occupied(unpack(arg)) end
        self.loadfen = function (...) return self.board:loadfen(unpack(arg)) end
    end
    function TestChessBoard:test_01_board_object()
        assert(not pcall(chess.Board, 1))
        assert(not pcall(chess.Board, "1"))
        assert(not pcall(chess.Board, {side = "foo"}))
        assert(not pcall(chess.Board, {check_legality = "bar"}))
        assert(not pcall(chess.Board, {ep = {}}))
        assert(not pcall(chess.Board, {ep = "a1"}))
        assert(not pcall(chess.Board, {ep = 65}))
        assert(not pcall(chess.Board, {flag = "a"}))
        assert(not pcall(chess.Board, {li_king = 65}))
        assert(not pcall(chess.Board, {li_rook = "not table"}))
        assert(not pcall(chess.Board, {li_rook = {-1, 1}}))
        assert(not pcall(chess.Board, {li_rook = {1, -1}}))
        assert(not pcall(chess.Board, {li_rook = {65, 1}}))
        assert(not pcall(chess.Board, {li_rook = {1, 65}}))
        assert(not pcall(chess.Board, {rhmc = "not number"}))
        assert(not pcall(chess.Board, {fmc = "not number"}))

        local b1 = chess.Board{}
        assert(type(b1) == "table")
        assert(b1.side == WHITE)
        assert(b1.check_legality == true)
        assert(b1.ep == -1)
        assert(b1.flag == 0)
        assert(b1.li_king == squarei"e1")
        assert(type(b1.li_rook) == "table")
        assert(b1.li_rook[1] == squarei"h1")
        assert(b1.li_rook[2] == squarei"a1")
        assert(b1.rhmc == 0)
        assert(b1.fmc == 1)
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
            flag = 3, ep = squarei"e3", li_king = squarei"a1",
            li_rook = {squarei"g1", squarei"c1"},
            rhmc = 3, fmc = 6}
        assert(type(b2) == "table")
        assert(b2.side == BLACK)
        assert(b2.check_legality == false)
        assert(b2.ep == squarei"e3")
        assert(b2.flag == 3)
        assert(b2.li_king == squarei"a1")
        assert(type(b2.li_rook) == "table")
        assert(b2.li_rook[1] == squarei"g1")
        assert(b2.li_rook[2] == squarei"c1")
        assert(b2.rhmc == 3)
        assert(b2.fmc == 6)

        for sq=0,63 do assert(b2.cboard[sq+1] == 0, sq) end
    end
    function TestChessBoard:test_02_set_piece()
        assert(not pcall(self.set_piece, -1))
        assert(not pcall(self.set_piece, 65))
        assert(not pcall(self.set_piece, 13, KING + 10))
        assert(not pcall(self.set_piece, 13, KING, BLACK + 1))
        for sq=0,63 do
            self.set_piece(sq, KING, WHITE)
            assert(self.board.bitboard.pieces[WHITE][KING]:tstbit(sq), sq)
        end
    end
    function TestChessBoard:test_03_get_piece()
        assert(not pcall(self.get_piece, -1))
        assert(not pcall(self.get_piece, 65))
        for sq=0,63 do
            self.set_piece(sq, QUEEN, BLACK)
            assert(self.get_piece(sq), sq)
            assert(select("#", self.get_piece(sq)) == 2, sq)
            assert(self.get_piece(sq) == QUEEN, sq)
            assert(select(2, self.get_piece(sq)) == BLACK, sq)
        end
    end
    function TestChessBoard:test_04_clear_piece()
        assert(not pcall(self.clear_piece, -1))
        assert(not pcall(self.clear_piece, 65))
        for sq=0,63 do
            self.set_piece(sq, KNIGHT, WHITE)
            self.clear_piece(11)
            assert(not self.get_piece(11), sq)
        end
    end
    function TestChessBoard:test_05_update_cboard()
        for sq=0,63 do
            self.set_piece(sq, PAWN, BLACK, true)
            assert(self.board.cboard[sq+1] == 0)
            self.update_cboard()
            assert(self.board.cboard[sq+1] == PAWN)
        end
    end
    function TestChessBoard:test_06_update_occupied()
        for sq=0,63 do
            self.set_piece(sq, PAWN, BLACK, true)
            assert(not self.board.bitboard.occupied[BLACK]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[WHITE]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[3]:tstbit(sq), sq)
            self.update_occupied()
            assert(self.board.bitboard.occupied[BLACK]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[WHITE]:tstbit(sq), sq)
            assert(self.board.bitboard.occupied[3]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[4]:tstbit(sq), sq)
        end
    end
    function TestChessBoard:test_07_board_has_piece()
        assert(not pcall(self.has_piece, -1))
        assert(not pcall(self.has_piece, 65))
        assert(not pcall(self.has_piece, 13, BLACK + 1))
        for sq=0,63 do
            -- With update
            self.set_piece(sq, ROOK, BLACK)
            assert(self.has_piece(sq, BLACK), sq)
            assert(not self.has_piece(sq, WHITE), sq)
            assert(self.has_piece(sq), sq)
            self.clear_piece(sq)
            assert(not self.has_piece(sq, BLACK), sq)
            assert(not self.has_piece(sq), sq)
            -- Without update
            self.set_piece(sq, BISHOP, WHITE, true)
            assert(not self.has_piece(sq, WHITE), sq)
            assert(not self.has_piece(sq))
            self.update()
            assert(self.has_piece(sq, WHITE), sq)
            assert(not self.has_piece(sq, BLACK), sq)
            assert(self.has_piece(sq), sq)
            self.clear_piece(sq, BISHOP, WHITE, true)
            assert(self.has_piece(sq, WHITE), sq)
            assert(self.has_piece(sq), sq)
            self.update()
            assert(not self.has_piece(sq, WHITE), sq)
            assert(not self.has_piece(sq), sq)
        end
    end
    function TestChessBoard:test_08_clear_all()
        for sq=0,63 do self.set_piece(sq, QUEEN, WHITE) end
        self.clear_all()
        for sq=0,63 do
            assert(not self.board.bitboard.pieces[WHITE][QUEEN]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[WHITE]:tstbit(sq), sq)
            assert(not self.board.bitboard.occupied[3]:tstbit(sq), sq)
            assert(self.board.cboard[sq + 1] == 0)
        end
        assert(self.board.ep == -1)
        assert(self.board.flag == 0)
        assert(self.board.rhmc == 0)
        assert(self.board.fmc == 1)
    end
    function TestChessBoard:test_09_loadfen_invalid()
        assert(not pcall(self.loadfen, {}))
        assert(not pcall(self.loadfen, "foo"))
        assert(not pcall(self.loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"))
        assert(not pcall(self.loadfen, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w"))
        assert(not pcall(self.loadfen,
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq"))
        assert(not pcall(self.loadfen,
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -"))
        assert(not pcall(self.loadfen,
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0"))

        -- TODO write tests for valid FENs
    end
    function TestChessBoard:test_10_fen()
        -- Fischer, R - Tal, M , the great game :)
        local fenlist = {
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
            "rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2",
            "rnbqkbnr/pppp1ppp/4p3/8/3PP3/8/PPP2PPP/RNBQKBNR b KQkq d3 0 2",
            "rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR w KQkq d6 0 3",
            "rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/2N5/PPP2PPP/R1BQKBNR b KQkq - 1 3",
            "rnbqk1nr/ppp2ppp/4p3/3p4/1b1PP3/2N5/PPP2PPP/R1BQKBNR w KQkq - 2 4",
            "rnbqk1nr/ppp2ppp/4p3/3pP3/1b1P4/2N5/PPP2PPP/R1BQKBNR b KQkq - 0 4",
            "rnbqk1nr/pp3ppp/4p3/2ppP3/1b1P4/2N5/PPP2PPP/R1BQKBNR w KQkq c6 0 5",
            "rnbqk1nr/pp3ppp/4p3/2ppP3/1b1P4/P1N5/1PP2PPP/R1BQKBNR b KQkq - 0 5",
            "rnbqk1nr/pp3ppp/4p3/b1ppP3/3P4/P1N5/1PP2PPP/R1BQKBNR w KQkq - 1 6",
            "rnbqk1nr/pp3ppp/4p3/b1ppP3/1P1P4/P1N5/2P2PPP/R1BQKBNR b KQkq b3 0 6",
            "rnbqk1nr/pp3ppp/4p3/b2pP3/1P1p4/P1N5/2P2PPP/R1BQKBNR w KQkq - 0 7",
            "rnbqk1nr/pp3ppp/4p3/b2pP3/1P1p2Q1/P1N5/2P2PPP/R1B1KBNR b KQkq - 1 7",
            "rnbqk2r/pp2nppp/4p3/b2pP3/1P1p2Q1/P1N5/2P2PPP/R1B1KBNR w KQkq - 2 8",
            "rnbqk2r/pp2nppp/4p3/P2pP3/3p2Q1/P1N5/2P2PPP/R1B1KBNR b KQkq - 0 8",
            "rnbqk2r/pp2nppp/4p3/P2pP3/6Q1/P1p5/2P2PPP/R1B1KBNR w KQkq - 0 9",
            "rnbqk2r/pp2npQp/4p3/P2pP3/8/P1p5/2P2PPP/R1B1KBNR b KQkq - 0 9",
            "rnbqk1r1/pp2npQp/4p3/P2pP3/8/P1p5/2P2PPP/R1B1KBNR w KQq - 0 10",
            "rnbqk1r1/pp2np1Q/4p3/P2pP3/8/P1p5/2P2PPP/R1B1KBNR b KQq - 0 10",
            "r1bqk1r1/pp2np1Q/2n1p3/P2pP3/8/P1p5/2P2PPP/R1B1KBNR w KQq - 1 11",
            "r1bqk1r1/pp2np1Q/2n1p3/P2pP3/8/P1p2N2/2P2PPP/R1B1KB1R b KQq - 2 11",
            "r1b1k1r1/ppq1np1Q/2n1p3/P2pP3/8/P1p2N2/2P2PPP/R1B1KB1R w KQq - 3 12",
            "r1b1k1r1/ppq1np1Q/2n1p3/PB1pP3/8/P1p2N2/2P2PPP/R1B1K2R b KQq - 4 12",
            "r3k1r1/ppqbnp1Q/2n1p3/PB1pP3/8/P1p2N2/2P2PPP/R1B1K2R w KQq - 5 13",
            "r3k1r1/ppqbnp1Q/2n1p3/PB1pP3/8/P1p2N2/2P2PPP/R1B2RK1 b q - 0 13",
            "2kr2r1/ppqbnp1Q/2n1p3/PB1pP3/8/P1p2N2/2P2PPP/R1B2RK1 w - - 0 14",
            "2kr2r1/ppqbnp1Q/2n1p3/PB1pP1B1/8/P1p2N2/2P2PPP/R4RK1 b - - 1 14",
            "2kr2r1/ppqbnp1Q/4p3/PB1pn1B1/8/P1p2N2/2P2PPP/R4RK1 w - - 0 15",
            "2kr2r1/ppqbnp1Q/4p3/PB1pN1B1/8/P1p5/2P2PPP/R4RK1 b - - 0 15",
            "2kr2r1/ppq1np1Q/4p3/Pb1pN1B1/8/P1p5/2P2PPP/R4RK1 w - - 0 16",
            "2kr2r1/ppq1nN1Q/4p3/Pb1p2B1/8/P1p5/2P2PPP/R4RK1 b - - 0 16",
            "2kr2r1/ppq1nN1Q/4p3/P2p2B1/8/P1p5/2P2PPP/R4bK1 w - - 0 17",
            "2kN2r1/ppq1n2Q/4p3/P2p2B1/8/P1p5/2P2PPP/R4bK1 b - - 0 17",
            "2kN4/ppq1n2Q/4p3/P2p2r1/8/P1p5/2P2PPP/R4bK1 w - - 0 18",
            "2k5/ppq1n2Q/4N3/P2p2r1/8/P1p5/2P2PPP/R4bK1 b - - 0 18",
            "2k5/ppq1n2Q/4N3/P2p4/8/P1p5/2P2PrP/R4bK1 w - - 0 19",
            "2k5/ppq1n2Q/4N3/P2p4/8/P1p5/2P2PrP/R4b1K b - - 1 19",
            "2k5/pp2n2Q/4N3/P2pq3/8/P1p5/2P2PrP/R4b1K w - - 2 20",
            "2k5/pp2n2Q/4N3/P2pq3/8/P1p5/2P2PrP/5R1K b - - 0 20",
            "2k5/pp2n2Q/4q3/P2p4/8/P1p5/2P2PrP/5R1K w - - 0 21",
            "2k5/pp2n2Q/4q3/P2p4/8/P1p5/2P2PKP/5R2 b - - 0 21",
            "2k5/pp2n2Q/8/P2p4/6q1/P1p5/2P2PKP/5R2 w - - 1 22",
            -- 1/2-1/2
        }
        for _, fen in ipairs(fenlist) do
            self.board:loadfen(fen)
            assert(self.board:fen() == fen, "Failed for FEN: '" .. fen .. "'")
        end
    end
    function TestChessBoard:test_11_make_move_bare()
        local m = chess.MOVE(squarei"g1", squarei"f3")
        self.loadfen()
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"f3"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"f3"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"f3"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"f3"))
        assert(self.board.cboard[squarei"f3" + 1] == KNIGHT)
        assert(not self.board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"g1"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"g1"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"g1"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"g1"))
        assert(self.board.cboard[squarei"g1" + 1] == 0)
        assert(self.board.rhmc == 1)
    end
    function TestChessBoard:test_12_make_move_pawn2()
        local m = chess.MOVE(squarei"a2", squarei"a4")
        self.loadfen"r1bq1rk1/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 w - - 0 8"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"a4"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"a4"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"a4"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"a4"))
        assert(self.board.cboard[squarei"a4" + 1] == PAWN)
        assert(not self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"a2"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"a2"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"a2"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"a2"))
        assert(self.board.cboard[squarei"a2" + 1] == 0)
        assert(self.board.ep == squarei"a3")
        assert(self.board.rhmc == 0)
    end
    function TestChessBoard:test_13_make_move_capture()
        local m = chess.MOVE(squarei"e4", squarei"d5")
        m = bor(m, PAWNCAP)
        self.loadfen
            "r1bq1rk1/2p1bppp/p1n2n2/1p1pp3/4P3/1BP2N2/PP1P1PPP/RNBQR1K1 w - d6 0 9"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"d5"))
        assert(not self.board.bitboard.pieces[BLACK][PAWN]:tstbit(squarei"d5"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"d5"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"d5"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"d5"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"d5"))
        assert(self.board.cboard[squarei"d5" + 1] == PAWN)
        assert(not self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"e4"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"e4"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"e4"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"e4"))
        assert(self.board.cboard[squarei"e4" + 1] == 0)
        assert(self.board.rhmc == 0)
    end
    function TestChessBoard:test_14_make_move_enpassant()
        local m = chess.MOVE(squarei"d5", squarei"c6")
        m = bor(m, ENPASSANT)
        self.loadfen"rnbq1rk1/pp3pbp/3p1np1/2pPp3/2P1P3/2N2N2/PP2BPPP/R1BQK2R w KQ c6 0 8"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"c6"))
        assert(not self.board.bitboard.pieces[BLACK][PAWN]:tstbit(squarei"c5"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"c6"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"c5"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"c6"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"c5"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"c6"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"c5"))
        assert(self.board.cboard[squarei"c6" + 1] == PAWN)
        assert(self.board.cboard[squarei"c5" + 1] == 0)
        assert(not self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"d5"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"d5"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"d5"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"d5"))
        assert(self.board.cboard[squarei"d5" + 1] == 0)
        assert(self.board.rhmc == 0)
    end
    function TestChessBoard:test_15_make_move_promotion()
        local m = chess.MOVE(squarei"b7", squarei"a8")
        m = bor(m, KNIGHTPRM)
        m = bor(m, ROOKCAP)
        self.loadfen"rn1q1rk1/pP3pbp/3p1np1/4p3/2P1b3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 10"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][KNIGHT]:tstbit(squarei"a8"))
        assert(not self.board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"a8"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"a8"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"a8"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"a8"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"a8"))
        assert(self.board.cboard[squarei"a8" + 1] == KNIGHT)
        assert(not self.board.bitboard.pieces[WHITE][PAWN]:tstbit(squarei"b7"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"b7"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"b7"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"b7"))
        assert(self.board.cboard[squarei"b7" + 1] == 0)
        assert(self.board.rhmc == 0)
        assert(self.board.fmc == 10)
    end
    function TestChessBoard:test_16_make_move_castle_short_white()
        local m = chess.MOVE(squarei"e1", squarei"g1")
        m = bor(m, CASTLING)
        self.loadfen"r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 5"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][KING]:tstbit(squarei"g1"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"g1"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"g1"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"g1"))
        assert(self.board.cboard[squarei"g1" + 1] == KING)
        assert(not self.board.bitboard.pieces[WHITE][KING]:tstbit(squarei"e1"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"e1"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"e1"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"e1"))
        assert(self.board.cboard[squarei"e1" + 1] == 0)
        assert(self.board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"f1"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"f1"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"f1"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"f1"))
        assert(self.board.cboard[squarei"f1" + 1] == ROOK)
        assert(not self.board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"h1"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"h1"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"h1"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"h1"))
        assert(self.board.cboard[squarei"h1" + 1] == 0)
        assert(not chess.tstbit(self.board.flag, chess.WKINGCASTLE))
        assert(not chess.tstbit(self.board.flag, chess.WQUEENCASTLE))
        assert(self.board.rhmc == 3)
        assert(self.board.fmc == 5)
    end
    function TestChessBoard:test_17_make_move_castle_long_white()
        local m = chess.MOVE(squarei"e1", squarei"c1")
        m = bor(m, CASTLING)
        self.loadfen"r1bq1rk1/pp2ppbp/2np1np1/8/3NP3/2N1BP2/PPPQ2PP/R3KB1R w KQ - 0 9"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[WHITE][KING]:tstbit(squarei"c1"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"c1"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"c1"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"c1"))
        assert(self.board.cboard[squarei"c1" + 1] == KING)
        assert(not self.board.bitboard.pieces[WHITE][KING]:tstbit(squarei"e1"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"e1"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"e1"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"e1"))
        assert(self.board.cboard[squarei"e1" + 1] == 0)
        assert(self.board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"d1"))
        assert(self.board.bitboard.occupied[WHITE]:tstbit(squarei"d1"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"d1"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"d1"))
        assert(self.board.cboard[squarei"d1" + 1] == ROOK)
        assert(not self.board.bitboard.pieces[WHITE][ROOK]:tstbit(squarei"a1"))
        assert(not self.board.bitboard.occupied[WHITE]:tstbit(squarei"a1"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"a1"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"a1"))
        assert(self.board.cboard[squarei"a1" + 1] == 0)
        assert(not chess.tstbit(self.board.flag, chess.WKINGCASTLE))
        assert(not chess.tstbit(self.board.flag, chess.WQUEENCASTLE))
        assert(self.board.rhmc == 1)
        assert(self.board.fmc == 9)
    end
    function TestChessBoard:test_18_make_move_castle_short_black()
        local m = chess.MOVE(squarei"e8", squarei"g8")
        m = bor(m, CASTLING)
        self.loadfen"rnbqk2r/ppp1ppbp/3p1np1/8/3PP3/2N2N2/PPP1BPPP/R1BQK2R b KQkq - 3 5"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[BLACK][KING]:tstbit(squarei"g8"))
        assert(self.board.bitboard.occupied[BLACK]:tstbit(squarei"g8"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"g8"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"g8"))
        assert(self.board.cboard[squarei"g8" + 1] == KING)
        assert(not self.board.bitboard.pieces[BLACK][KING]:tstbit(squarei"e8"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"e8"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"e8"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"e8"))
        assert(self.board.cboard[squarei"e8" + 1] == 0)
        assert(self.board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"f8"))
        assert(self.board.bitboard.occupied[BLACK]:tstbit(squarei"f8"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"f8"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"f8"))
        assert(self.board.cboard[squarei"f8" + 1] == ROOK)
        assert(not self.board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"h8"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"h8"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"h8"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"h8"))
        assert(self.board.cboard[squarei"h8" + 1] == 0)
        assert(not chess.tstbit(self.board.flag, chess.BKINGCASTLE))
        assert(not chess.tstbit(self.board.flag, chess.BQUEENCASTLE))
        assert(self.board.rhmc == 4)
        assert(self.board.fmc == 6)
    end
    function TestChessBoard:test_19_make_move_castle_long_black()
        local m = chess.MOVE(squarei"e8", squarei"c8")
        m = bor(m, CASTLING)
        self.loadfen"r3kbnr/pppb1ppp/2np1q2/1B2p3/3PP3/2N2N2/PPP2PPP/R1BQ1RK1 b kq - 0 6"
        self.board:make_move(m)
        assert(self.board.bitboard.pieces[BLACK][KING]:tstbit(squarei"c8"))
        assert(self.board.bitboard.occupied[BLACK]:tstbit(squarei"c8"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"c8"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"c8"))
        assert(self.board.cboard[squarei"c8" + 1] == KING)
        assert(not self.board.bitboard.pieces[BLACK][KING]:tstbit(squarei"e8"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"e8"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"e8"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"e8"))
        assert(self.board.cboard[squarei"e8" + 1] == 0)
        assert(self.board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"d8"))
        assert(self.board.bitboard.occupied[BLACK]:tstbit(squarei"d8"))
        assert(self.board.bitboard.occupied[3]:tstbit(squarei"d8"))
        assert(not self.board.bitboard.occupied[4]:tstbit(squarei"d8"))
        assert(self.board.cboard[squarei"d8" + 1] == ROOK)
        assert(not self.board.bitboard.pieces[BLACK][ROOK]:tstbit(squarei"a8"))
        assert(not self.board.bitboard.occupied[BLACK]:tstbit(squarei"a8"))
        assert(not self.board.bitboard.occupied[3]:tstbit(squarei"a8"))
        assert(self.board.bitboard.occupied[4]:tstbit(squarei"a8"))
        assert(self.board.cboard[squarei"a8" + 1] == 0)
        assert(not chess.tstbit(self.board.flag, chess.BKINGCASTLE))
        assert(not chess.tstbit(self.board.flag, chess.BQUEENCASTLE))
        assert(self.board.rhmc == 1)
        assert(self.board.fmc == 7)
    end
-- class

ret = LuaUnit:run()
if ret > 0 then os.exit(1) end