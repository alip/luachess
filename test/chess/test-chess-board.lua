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
    function TestChessBoard:assert_move(move, initial_fen, expected_fen)
        self.loadfen(initial_fen)
        self.board:make_move(move)
        local f = self.board:fen()
        assert(f == expected_fen, "\nmake_move(): Expected:\n'" .. expected_fen ..
            "'\nGot:\n'" .. f .. "'")
        self.board:unmake_move()
        local f = self.board:fen()
        assert(f == initial_fen, "\nunmake_move(): Expected:\n'" .. initial_fen ..
            "'\nGot:\n'" .. f .. "'")
    end
    function TestChessBoard:assert_move_san(move, initial_fen, expected_fen)
        self.loadfen(initial_fen)
        self.board:move_san(move)
        local f = self.board:fen()
        assert(f == expected_fen, "\nExpected:\n'" .. expected_fen ..
            "'\nGot:\n'" .. f .. "'")
    end
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

        local b2 = chess.Board{side = BLACK,
            flag = 3, ep = squarei"e3", li_king = squarei"a1",
            li_rook = {squarei"g1", squarei"c1"},
            rhmc = 3, fmc = 6}
        assert(type(b2) == "table")
        assert(b2.side == BLACK)
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
            self.clear_piece(11, KNIGHT, WHITE)
            assert(not self.get_piece(11), sq)
        end
    end
    --[[
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
    --]]
    function TestChessBoard:test_07_board_has_piece()
        assert(not pcall(self.has_piece, -1))
        assert(not pcall(self.has_piece, 65))
        assert(not pcall(self.has_piece, 13, BLACK + 1))
        for sq=0,63 do
            self.set_piece(sq, BISHOP, WHITE)
            assert(self.has_piece(sq, WHITE), sq)
            assert(not self.has_piece(sq, BLACK), sq)
            assert(self.has_piece(sq), sq)
            self.clear_piece(sq, BISHOP, WHITE)
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
    function TestChessBoard:test_11_make_move_pawn()
        --- Normal pawn moves
        -- Tal,M - Botvinnik,M World Championship Match Moscow 1960 1st game.
        self:assert_move(chess.MOVE(squarei"h4", squarei"h5"),
            "6q1/p1k5/1pb3n1/5pB1/3R3P/P3P3/6P1/3QK3 w - - 0 32",
            "6q1/p1k5/1pb3n1/5pBP/3R4/P3P3/6P1/3QK3 b - - 0 32")
        -- Botvinnik,M - Tal,M World Championship Match Moscow 1960 5th game
        self:assert_move(chess.MOVE(squarei"c4", squarei"c3"),
            "8/R6p/6p1/3k4/2p2P2/6KP/8/4r3 b - - 2 45",
            "8/R6p/6p1/3k4/5P2/2p3KP/8/4r3 w - - 0 46")
        --- Pawn moves two square forward.
        -- Tal,M - Botvinnik,M World Championship Match Moscow 1960 6th game
        self:assert_move(chess.MOVE(squarei"f2", squarei"f4"),
            "8/1p6/2pk1N2/6N1/8/1r6/5PP1/5K2 w - - 0 35",
            "8/1p6/2pk1N2/6N1/5P2/1r6/6P1/5K2 b - f3 0 35")
        -- Tal,M - Petrosian,T Riga 1958
        self:assert_move(chess.MOVE(squarei"f7", squarei"f5"),
            "3q1rk1/b4pp1/p2P3p/P6P/1pp1N1Q1/3n4/1P4P1/3R1R1K b - - 4 41",
            "3q1rk1/b5p1/p2P3p/P4p1P/1pp1N1Q1/3n4/1P4P1/3R1R1K w - f6 0 42")
        --- Pawn captures
        -- Thorbergsson,F - Tal,M Reykjavik 1964
        self:assert_move(bor(chess.MOVE(squarei"g3", squarei"f4"), KNIGHTCAP),
            "2b3k1/4qp1p/p2p2p1/3P4/2Pp1nn1/3BrNP1/PPQB2KP/4R3 w - - 0 28",
            "2b3k1/4qp1p/p2p2p1/3P4/2Pp1Pn1/3BrN2/PPQB2KP/4R3 b - - 0 28")
        -- Tal,M - Taimanov,M Kislovodsk 1966
        self:assert_move(bor(chess.MOVE(squarei"e5", squarei"f4"), PAWNCAP),
            "1kbR4/r1r5/p4PP1/1pq1p3/4QP2/8/PPP5/2KR4 b - - 0 31",
            "1kbR4/r1r5/p4PP1/1pq5/4Qp2/8/PPP5/2KR4 w - - 0 32")
        --- En passant captures
        -- Pedzich,D - Wojcieszyn,J Lubniewice 1998
        self:assert_move(bor(chess.MOVE(squarei"d5", squarei"e6"), ENPASSANT),
            "r1bqk2r/1p3pbp/p2p1p2/3Pp3/3NN3/7P/PP3PP1/R2QR1K1 w kq e6 0 17",
            "r1bqk2r/1p3pbp/p2pPp2/8/3NN3/7P/PP3PP1/R2QR1K1 b kq - 0 17")
        -- Gerstner,W - Cuchelov,V Deizisau 1999
        self:assert_move(bor(chess.MOVE(squarei"g4", squarei"f3"), ENPASSANT),
            "2r4r/1p1bkpb1/p1npp3/6q1/PPNPPPpp/2QB4/4N1PP/R4RK1 b - f3 0 23",
            "2r4r/1p1bkpb1/p1npp3/6q1/PPNPP2p/2QB1p2/4N1PP/R4RK1 w - - 0 24")
        --- Promotions
        self:assert_move(bor(chess.MOVE(squarei"h7", squarei"h8"), QUEENPRM),
            "rnbqkbr1/ppppp2P/5n2/8/8/8/PPPP1PPP/RNBQKBNR w KQq - 0 5",
            "rnbqkbrQ/ppppp3/5n2/8/8/8/PPPP1PPP/RNBQKBNR b KQq - 0 5")
        self:assert_move(bor(chess.MOVE(squarei"a2", squarei"a1"), ROOKPRM),
            "rnbqkbnr/ppp1pppp/8/8/4P3/2N5/p2P1PPP/1RBQKBNR b Kkq - 0 5",
            "rnbqkbnr/ppp1pppp/8/8/4P3/2N5/3P1PPP/rRBQKBNR w Kkq - 0 6")
        --- Promotion + Capture
        self:assert_move(bor(chess.MOVE(squarei"b7", squarei"a8"), ROOKCAP, BISHOPPRM),
            "rn1qkbnr/pP2pppp/8/8/8/8/PPbP1PPP/RNBQKBNR w KQkq - 0 5",
            "Bn1qkbnr/p3pppp/8/8/8/8/PPbP1PPP/RNBQKBNR b KQk - 0 5")
        self:assert_move(bor(chess.MOVE(squarei"g2", squarei"h1"), ROOKCAP, KNIGHTPRM),
            "rnbqkbnr/ppp1pppB/8/8/2P5/8/PP1P2pP/RNBQK1NR b KQkq - 0 5",
            "rnbqkbnr/ppp1pppB/8/8/2P5/8/PP1P3P/RNBQK1Nn w Qkq - 0 6")
    end
    function TestChessBoard:test_12_make_move_knight()
        --- Normal knight moves
        -- Shirov,A - Shulman,Y World World Cup 2007
        self:assert_move(chess.MOVE(squarei"g1", squarei"e2"),
            "rnb1k1r1/ppq1np1Q/4p3/3pP3/3p4/P1P5/2P2PPP/R1B1KBNR w KQq - 1 10",
            "rnb1k1r1/ppq1np1Q/4p3/3pP3/3p4/P1P5/2P1NPPP/R1B1KB1R b KQq - 2 10")
        -- Sasikiran,K - Shirov,A AeroSvit 2007
        self:assert_move(chess.MOVE(squarei"c5", squarei"d3"),
            "2rq1rk1/p4ppp/1pP5/2n3b1/2Q5/6P1/PB3PBP/R3R1K1 b - - 0 21",
            "2rq1rk1/p4ppp/1pP5/6b1/2Q5/3n2P1/PB3PBP/R3R1K1 w - - 1 22")
        --- Knight captures
        -- Eljanov,P - Shirov,A Aerosvit 2007
        self:assert_move(bor(chess.MOVE(squarei"f3", squarei"d2"), QUEENCAP),
            "r4rk1/p3ppbp/2p3p1/8/3PP1b1/4BN2/P2q1PPP/2R2RK1 w - - 0 15",
            "r4rk1/p3ppbp/2p3p1/8/3PP1b1/4B3/P2N1PPP/2R2RK1 b - - 0 15")
        -- Shirov,A - Ivanchuk,V Russian Team 2008
        self:assert_move(bor(chess.MOVE(squarei"g4", squarei"e5"), KNIGHTCAP),
            "r3k2r/1p1bbp2/p2pp3/2q1N1p1/4P1n1/2NB2B1/PPP1Q1PP/2KR1R2 b kq - 0 17",
            "r3k2r/1p1bbp2/p2pp3/2q1n1p1/4P3/2NB2B1/PPP1Q1PP/2KR1R2 w kq - 0 18")
    end
    function TestChessBoard:test_13_make_move_bishop()
        --- Normal bishop moves
        -- Sasikiran - Shirov Aerosvit 2007
        self:assert_move(chess.MOVE(squarei"b7", squarei"a6"),
            "2r1r1k1/1BP2p2/2R3p1/7p/7P/1p4P1/3K1P2/8 w - - 2 36",
            "2r1r1k1/2P2p2/B1R3p1/7p/7P/1p4P1/3K1P2/8 b - - 3 36")
        -- Shirov - Nisipeanu Aerosvit 2007
        self:assert_move(chess.MOVE(squarei"c8", squarei"e6"),
            "r1b1k2r/1p2pp1p/1pp3p1/4P1P1/4N3/1P2B3/P4KBP/R7 b kq - 1 23",
            "r3k2r/1p2pp1p/1pp1b1p1/4P1P1/4N3/1P2B3/P4KBP/R7 w kq - 2 24")
        --- Bishop captures
        -- Karjakin - Shirov ? 2007
        self:assert_move(bor(chess.MOVE(squarei"g3", squarei"f4"), KNIGHTCAP),
            "r5k1/2q2pp1/2p3r1/p3pQ2/PnP2n1p/1R3PBP/1P4PK/4RN2 w - - 0 31",
            "r5k1/2q2pp1/2p3r1/p3pQ2/PnP2B1p/1R3P1P/1P4PK/4RN2 b - - 0 31")
        -- Speelman,J - Shirov,A Gibraltar 2006
        self:assert_move(bor(chess.MOVE(squarei"g7", squarei"c3"), PAWNCAP),
            "2r2rk1/pp1nppbp/6p1/3P4/4PP2/2P1N1PP/P5B1/1RR3K1 b - - 0 25",
            "2r2rk1/pp1npp1p/6p1/3P4/4PP2/2b1N1PP/P5B1/1RR3K1 w - - 0 26")
    end
    function TestChessBoard:test_14_make_move_rook()
        --- Normal rook moves
        -- Bareev,E - Shirov,A Poikovsky 2006
        self:assert_move(chess.MOVE(squarei"c3", squarei"c8"),
            "8/8/8/8/8/2RK4/3n4/3k4 w - - 24 90",
            "2R5/8/8/8/8/3K4/3n4/3k4 b - - 25 90")
        -- Shirov - Bologan Poikovsky 2006
        self:assert_move(chess.MOVE(squarei"f7", squarei"d7"),
            "r2q3k/5rbp/3p2p1/p2NpbN1/2P5/Q5RP/1P3PP1/3R2K1 b - - 7 25",
            "r2q3k/3r2bp/3p2p1/p2NpbN1/2P5/Q5RP/1P3PP1/3R2K1 w - - 8 26")
        --- Rook captures
        -- Najer - Shirov Poikovsky 2006
        self:assert_move(bor(chess.MOVE(squarei"a1", squarei"d1"), BISHOPCAP),
            "r3k2r/ppp1qppp/8/2bBn3/3NP3/2NPB3/PPP2PPP/R2bK2R w KQkq - 0 12",
            "r3k2r/ppp1qppp/8/2bBn3/3NP3/2NPB3/PPP2PPP/3RK2R b Kkq - 0 12")
        -- Miton - Shirov Russian Club Championship 2006
        self:assert_move(bor(chess.MOVE(squarei"e4", squarei"e1"), ROOKCAP),
            "5rk1/4pp1p/b2q2p1/p2P4/1p2r3/1P5P/PB1Q1PP1/R3R1K1 b - - 3 24",
            "5rk1/4pp1p/b2q2p1/p2P4/1p6/1P5P/PB1Q1PP1/R3r1K1 w - - 0 25")
    end
    function TestChessBoard:test_15_make_move_queen()
        --- Normal queen moves
        -- Rublevsky - Shirov Russian Club Championship 2006
        self:assert_move(chess.MOVE(squarei"d1", squarei"d2"),
            "rnbq1rk1/ppp1bppp/3p4/8/5B2/2P2N2/PPP2PPP/R2QKB1R w KQ - 0 8",
            "rnbq1rk1/ppp1bppp/3p4/8/5B2/2P2N2/PPPQ1PPP/R3KB1R b KQ - 1 8")
        -- Rublevsky - Shirov Russian Club Championship 2006
        self:assert_move(chess.MOVE(squarei"f5", squarei"f6"),
            "4rk2/2p2pp1/3p3p/5q2/1P3B1P/1P3P2/1K1Q4/r2R2R1 b - - 2 27",
            "4rk2/2p2pp1/3p1q1p/8/1P3B1P/1P3P2/1K1Q4/r2R2R1 w - - 3 28")
        --- Queen captures
        -- Sokolov - Shirov Poikovsky 2006
        self:assert_move(bor(chess.MOVE(squarei"a4", squarei"c4"), PAWNCAP),
            "r4rk1/pq1n1pp1/1p2pn1p/2p5/Q1pP3B/P1N1P3/1P3PPP/3R1RK1 w - - 1 18",
            "r4rk1/pq1n1pp1/1p2pn1p/2p5/2QP3B/P1N1P3/1P3PPP/3R1RK1 b - - 0 18")
        -- Glek,I - Shirov,A Mainz 2005
        self:assert_move(bor(chess.MOVE(squarei"a7", squarei"a3"), PAWNCAP),
            "b7/q3p1kp/5pp1/1Q6/1P4NP/P5P1/5P2/2R3K1 b - - 0 44",
            "b7/4p1kp/5pp1/1Q6/1P4NP/q5P1/5P2/2R3K1 w - - 0 45")
    end
    function TestChessBoard:test_16_make_move_king()
        --- Normal king moves
        -- Shirov - Scalcione Mainz 2005
        self:assert_move(chess.MOVE(squarei"g4", squarei"g5"),
            "8/6k1/6P1/5P2/r4NK1/8/4R3/8 w - - 1 63",
            "8/6k1/6P1/5PK1/r4N2/8/4R3/8 b - - 2 63")
        -- Osmanovic - Shirov Mainz 2005
        self:assert_move(chess.MOVE(squarei"c5", squarei"b5"),
            "4r3/p5pp/1n6/2k1p3/p2r4/2R1B3/1P2K1PP/8 b - - 1 29",
            "4r3/p5pp/1n6/1k2p3/p2r4/2R1B3/1P2K1PP/8 w - - 2 30")
        --- King captures
        -- Marshall - Lasker NewYork 1924
        self:assert_move(bor(chess.MOVE(squarei"g1", squarei"f1"), ROOKCAP),
            "4b2k/2q5/3bQ3/3p4/3P2N1/1P6/6R1/5rK1 w - - 0 45",
            "4b2k/2q5/3bQ3/3p4/3P2N1/1P6/6R1/5K2 b - - 0 45")
        -- Reti - Capablanca NewYork 1924
        self:assert_move(bor(chess.MOVE(squarei"g8", squarei"g7"), BISHOPCAP),
            "r3rnk1/3n1pB1/1p1p2pp/pP6/2q1b3/P4NP1/3Q1PBP/R2R1NK1 b - - 0 21",
            "r3rn2/3n1pk1/1p1p2pp/pP6/2q1b3/P4NP1/3Q1PBP/R2R1NK1 w - - 0 22")
    end
    function TestChessBoard:test_17_make_move_castle()
        --- Castle kingside
        self:assert_move(bor(chess.MOVE(squarei"e1", squarei"g1"), CASTLING),
            "r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
            "r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQ1RK1 b kq - 5 4")
        -- Steinitz - Zukertort ? ?
        self:assert_move(bor(chess.MOVE(squarei"e8", squarei"g8"), CASTLING),
            "r1bqk2r/ppppbppp/2nn4/4N3/8/3B4/PPPP1PPP/RNBQR1K1 b kq - 2 7",
            "r1bq1rk1/ppppbppp/2nn4/4N3/8/3B4/PPPP1PPP/RNBQR1K1 w - - 3 8")
        --- Castle queenside
        self:assert_move(bor(chess.MOVE(squarei"e1", squarei"c1"), CASTLING),
            "r1b1kb1r/1pqn1ppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/R3KB1R w KQkq - 3 9",
            "r1b1kb1r/1pqn1ppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/2KR1B1R b kq - 4 9")
        self:assert_move(bor(chess.MOVE(squarei"e8", squarei"c8"), CASTLING),
            "r3k2r/pppbqpb1/2npp2p/6p1/3PP1P1/2N2PN1/PPPQ2P1/2KR1B1R b kq - 2 13",
            "2kr3r/pppbqpb1/2npp2p/6p1/3PP1P1/2N2PN1/PPPQ2P1/2KR1B1R w - - 3 14")
        -- Test for moves that make castling not possible.
        -- King moves
        self:assert_move(chess.MOVE(squarei"e1", squarei"f1"),
            "r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 5",
            "r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQ1K1R b kq - 3 5")
        self:assert_move(chess.MOVE(squarei"e8", squarei"f8"),
            "r1bqk2r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 b kq - 1 7",
            "r1bq1k1r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 w - - 2 8")
        -- Rook moves
        self:assert_move(chess.MOVE(squarei"h1", squarei"h3"),
            "r1bqk2r/1ppp1ppp/p1n2n2/2b1p3/B3P2P/5N2/PPPP1PP1/RNBQK2R w KQkq - 1 6",
            "r1bqk2r/1ppp1ppp/p1n2n2/2b1p3/B3P2P/5N1R/PPPP1PP1/RNBQK3 b Qkq - 2 6")
        self:assert_move(chess.MOVE(squarei"h8", squarei"g8"),
            "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQR1K1 b kq - 2 5",
            "r1bqk1r1/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQR1K1 w q - 3 6")
        self:assert_move(chess.MOVE(squarei"a1", squarei"d1"),
            "rnbq1rk1/1p2bppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/R3KB1R w KQ - 0 9",
            "rnbq1rk1/1p2bppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/3RKB1R b K - 1 9")
        self:assert_move(chess.MOVE(squarei"a8", squarei"c8"),
            "r2qkb1r/pp1bpppp/2np1n2/6B1/3NP3/2N5/PPPQ1PPP/R3KB1R b KQkq - 3 7",
            "2rqkb1r/pp1bpppp/2np1n2/6B1/3NP3/2N5/PPPQ1PPP/R3KB1R w KQk - 4 8")
        -- Rook captured by an enemy piece
        self:assert_move(bor(chess.MOVE(squarei"b7", squarei"h1"), ROOKCAP),
            "rn1qkbnr/pbpppppp/1p6/8/3P2P1/2N5/PPP1PP1P/R1BQKBNR b KQkq d3 0 3",
            "rn1qkbnr/p1pppppp/1p6/8/3P2P1/2N5/PPP1PP1P/R1BQKBNb w Qkq - 0 4")
        self:assert_move(bor(chess.MOVE(squarei"b2", squarei"h8"), ROOKCAP),
            "rnbqkbnr/pp1ppp1p/6p1/2p5/8/1P6/PBPPPPPP/RN1QKBNR w KQkq c6 0 3",
            "rnbqkbnB/pp1ppp1p/6p1/2p5/8/1P6/P1PPPPPP/RN1QKBNR b KQq - 0 3")
        self:assert_move(bor(chess.MOVE(squarei"g7", squarei"a1"), ROOKCAP),
            "rnbqk1nr/ppppppbp/6p1/8/4P3/1P3N2/P1PP1PPP/RNBQKB1R b KQkq - 2 3",
            "rnbqk1nr/pppppp1p/6p1/8/4P3/1P3N2/P1PP1PPP/bNBQKB1R w Kkq - 0 4")
        self:assert_move(bor(chess.MOVE(squarei"g2", squarei"a8"), ROOKCAP),
            "rnbqkb1r/p1pppppp/1p3n2/8/8/6P1/PPPPPPBP/RNBQK1NR w KQkq - 2 3",
            "Bnbqkb1r/p1pppppp/1p3n2/8/8/6P1/PPPPPP1P/RNBQK1NR b KQk - 0 3")
    end
    function TestChessBoard:test_18_move_san_pawn()
        --- Normal pawn moves
        -- Tal,M - Botvinnik,M World Championship Match Moscow 1960 1st game.
        self:assert_move_san("h5",
            "6q1/p1k5/1pb3n1/5pB1/3R3P/P3P3/6P1/3QK3 w - - 0 32",
            "6q1/p1k5/1pb3n1/5pBP/3R4/P3P3/6P1/3QK3 b - - 0 32")
        -- Botvinnik,M - Tal,M World Championship Match Moscow 1960 5th game
        self:assert_move_san("c3",
            "8/R6p/6p1/3k4/2p2P2/6KP/8/4r3 b - - 2 45",
            "8/R6p/6p1/3k4/5P2/2p3KP/8/4r3 w - - 0 46")
        --- Pawn moves two squares forward
        -- Tal,M - Botvinnik,M World Championship Match Moscow 1960 6th game
        self:assert_move_san("f4",
            "8/1p6/2pk1N2/6N1/8/1r6/5PP1/5K2 w - - 0 35",
            "8/1p6/2pk1N2/6N1/5P2/1r6/6P1/5K2 b - f3 0 35")
        -- Tal,M - Petrosian,T Riga 1958
        self:assert_move_san("f5",
            "3q1rk1/b4pp1/p2P3p/P6P/1pp1N1Q1/3n4/1P4P1/3R1R1K b - - 4 41",
            "3q1rk1/b5p1/p2P3p/P4p1P/1pp1N1Q1/3n4/1P4P1/3R1R1K w - f6 0 42")
        --- Pawn captures
        -- Thorbergsson,F - Tal,M Reykjavik 1964
        self:assert_move_san("gxf4",
            "2b3k1/4qp1p/p2p2p1/3P4/2Pp1nn1/3BrNP1/PPQB2KP/4R3 w - - 0 28",
            "2b3k1/4qp1p/p2p2p1/3P4/2Pp1Pn1/3BrN2/PPQB2KP/4R3 b - - 0 28")
        -- Tal,M - Taimanov,M Kislovodsk 1966
        self:assert_move_san("exf4",
            "1kbR4/r1r5/p4PP1/1pq1p3/4QP2/8/PPP5/2KR4 b - - 0 31",
            "1kbR4/r1r5/p4PP1/1pq5/4Qp2/8/PPP5/2KR4 w - - 0 32")
        --- En passant
        -- Pedzich,D - Wojcieszyn,J Lubniewice 1998
        self:assert_move_san("dxe6",
            "r1bqk2r/1p3pbp/p2p1p2/3Pp3/3NN3/7P/PP3PP1/R2QR1K1 w kq e6 0 17",
            "r1bqk2r/1p3pbp/p2pPp2/8/3NN3/7P/PP3PP1/R2QR1K1 b kq - 0 17")
        -- Gerstner,W - Cuchelov,V Deizisau 1999
        self:assert_move_san("gxf3",
            "2r4r/1p1bkpb1/p1npp3/6q1/PPNPPPpp/2QB4/4N1PP/R4RK1 b - f3 0 23",
            "2r4r/1p1bkpb1/p1npp3/6q1/PPNPP2p/2QB1p2/4N1PP/R4RK1 w - - 0 24")
        --- Promotion
        self:assert_move_san("h8=Q",
            "rnbqkbr1/ppppp2P/5n2/8/8/8/PPPP1PPP/RNBQKBNR w KQq - 0 5",
            "rnbqkbrQ/ppppp3/5n2/8/8/8/PPPP1PPP/RNBQKBNR b KQq - 0 5")
        self:assert_move_san("a1=R",
            "rnbqkbnr/ppp1pppp/8/8/4P3/2N5/p2P1PPP/1RBQKBNR b Kkq - 0 5",
            "rnbqkbnr/ppp1pppp/8/8/4P3/2N5/3P1PPP/rRBQKBNR w Kkq - 0 6")
        --- Capture + promotion
        self:assert_move_san("bxa8=B",
            "rn1qkbnr/pP2pppp/8/8/8/8/PPbP1PPP/RNBQKBNR w KQkq - 0 5",
            "Bn1qkbnr/p3pppp/8/8/8/8/PPbP1PPP/RNBQKBNR b KQk - 0 5")
        self:assert_move_san("gxh1=N",
            "rnbqkbnr/ppp1pppp/8/8/2B5/2N2N2/PPPP2pP/R1BQK2R b KQkq - 1 5",
            "rnbqkbnr/ppp1pppp/8/8/2B5/2N2N2/PPPP3P/R1BQK2n w Qkq - 0 6")
    end
    function TestChessBoard:test_19_move_san_knight()
        --- Normal knight moves
        -- Shirov,A - Shulman,Y World World Cup 2007
        self:assert_move_san("Ne2",
            "rnb1k1r1/ppq1np1Q/4p3/3pP3/3p4/P1P5/2P2PPP/R1B1KBNR w KQq - 1 10",
            "rnb1k1r1/ppq1np1Q/4p3/3pP3/3p4/P1P5/2P1NPPP/R1B1KB1R b KQq - 2 10")
        -- Sasikiran,K - Shirov,A AeroSvit 2007
        self:assert_move_san("Nd3",
            "2rq1rk1/p4ppp/1pP5/2n3b1/2Q5/6P1/PB3PBP/R3R1K1 b - - 0 21",
            "2rq1rk1/p4ppp/1pP5/6b1/2Q5/3n2P1/PB3PBP/R3R1K1 w - - 1 22")
        --- Knight captures
        -- Eljanov,P - Shirov,A Aerosvit 2007
        self:assert_move_san("Nxd2",
            "r4rk1/p3ppbp/2p3p1/8/3PP1b1/4BN2/P2q1PPP/2R2RK1 w - - 0 15",
            "r4rk1/p3ppbp/2p3p1/8/3PP1b1/4B3/P2N1PPP/2R2RK1 b - - 0 15")
        -- Shirov,A - Ivanchuk,V Russian Team 2008
        self:assert_move_san("Nxe5",
            "r3k2r/1p1bbp2/p2pp3/2q1N1p1/4P1n1/2NB2B1/PPP1Q1PP/2KR1R2 b kq - 0 17",
            "r3k2r/1p1bbp2/p2pp3/2q1n1p1/4P3/2NB2B1/PPP1Q1PP/2KR1R2 w kq - 0 18")
    end
    function TestChessBoard:test_20_move_san_bishop()
        --- Normal bishop moves
        -- Sasikiran - Shirov Aerosvit 2007
        self:assert_move_san("Ba6",
            "2r1r1k1/1BP2p2/2R3p1/7p/7P/1p4P1/3K1P2/8 w - - 2 36",
            "2r1r1k1/2P2p2/B1R3p1/7p/7P/1p4P1/3K1P2/8 b - - 3 36")
        -- Shirov - Nisipeanu Aerosvit 2007
        self:assert_move_san("Be6",
            "r1b1k2r/1p2pp1p/1pp3p1/4P1P1/4N3/1P2B3/P4KBP/R7 b kq - 1 23",
            "r3k2r/1p2pp1p/1pp1b1p1/4P1P1/4N3/1P2B3/P4KBP/R7 w kq - 2 24")
        --- Bishop captures
        -- Karjakin - Shirov ? 2007
        self:assert_move_san("Bxf4",
            "r5k1/2q2pp1/2p3r1/p3pQ2/PnP2n1p/1R3PBP/1P4PK/4RN2 w - - 0 31",
            "r5k1/2q2pp1/2p3r1/p3pQ2/PnP2B1p/1R3P1P/1P4PK/4RN2 b - - 0 31")
        -- Speelman,J - Shirov,A Gibraltar 2006
        self:assert_move_san("Bxc3",
            "2r2rk1/pp1nppbp/6p1/3P4/4PP2/2P1N1PP/P5B1/1RR3K1 b - - 0 25",
            "2r2rk1/pp1npp1p/6p1/3P4/4PP2/2b1N1PP/P5B1/1RR3K1 w - - 0 26")
    end
    function TestChessBoard:test_21_move_san_rook()
        --- Normal rook moves
        -- Bareev,E - Shirov,A Poikovsky 2006
        self:assert_move_san("Rc8",
            "8/8/8/8/8/2RK4/3n4/3k4 w - - 24 90",
            "2R5/8/8/8/8/3K4/3n4/3k4 b - - 25 90")
        -- Shirov - Bologan Poikovsky 2006
        self:assert_move_san("Rd7",
            "r2q3k/5rbp/3p2p1/p2NpbN1/2P5/Q5RP/1P3PP1/3R2K1 b - - 7 25",
            "r2q3k/3r2bp/3p2p1/p2NpbN1/2P5/Q5RP/1P3PP1/3R2K1 w - - 8 26")
        --- Rook captures
        -- Najer - Shirov Poikovsky 2006
        self:assert_move_san("Rxd1",
            "r3k2r/ppp1qppp/8/2bBn3/3NP3/2NPB3/PPP2PPP/R2bK2R w KQkq - 0 12",
            "r3k2r/ppp1qppp/8/2bBn3/3NP3/2NPB3/PPP2PPP/3RK2R b Kkq - 0 12")
        -- Miton - Shirov Russian Club Championship 2006
        self:assert_move_san("Rxe1",
            "5rk1/4pp1p/b2q2p1/p2P4/1p2r3/1P5P/PB1Q1PP1/R3R1K1 b - - 3 24",
            "5rk1/4pp1p/b2q2p1/p2P4/1p6/1P5P/PB1Q1PP1/R3r1K1 w - - 0 25")
    end
    function TestChessBoard:test_22_move_san_queen()
        --- Normal queen moves
        -- Rublevsky - Shirov Russian Club Championship 2006
        self:assert_move_san("Qd2",
            "rnbq1rk1/ppp1bppp/3p4/8/5B2/2P2N2/PPP2PPP/R2QKB1R w KQ - 0 8",
            "rnbq1rk1/ppp1bppp/3p4/8/5B2/2P2N2/PPPQ1PPP/R3KB1R b KQ - 1 8")
        -- Rublevsky - Shirov Russian Club Championship 2006
        self:assert_move_san("Qf6+",
            "4rk2/2p2pp1/3p3p/5q2/1P3B1P/1P3P2/1K1Q4/r2R2R1 b - - 2 27",
            "4rk2/2p2pp1/3p1q1p/8/1P3B1P/1P3P2/1K1Q4/r2R2R1 w - - 3 28")
        --- Queen captures
        -- Sokolov - Shirov Poikovsky 2006
        self:assert_move_san("Qxc4",
            "r4rk1/pq1n1pp1/1p2pn1p/2p5/Q1pP3B/P1N1P3/1P3PPP/3R1RK1 w - - 1 18",
            "r4rk1/pq1n1pp1/1p2pn1p/2p5/2QP3B/P1N1P3/1P3PPP/3R1RK1 b - - 0 18")
        -- Glek,I - Shirov,A Mainz 2005
        self:assert_move_san("Qxa3",
            "b7/q3p1kp/5pp1/1Q6/1P4NP/P5P1/5P2/2R3K1 b - - 0 44",
            "b7/4p1kp/5pp1/1Q6/1P4NP/q5P1/5P2/2R3K1 w - - 0 45")
    end
    function TestChessBoard:test_23_move_san_king()
        --- Normal king moves
        -- Shirov - Scalcione Mainz 2005
        self:assert_move_san("Kg5",
            "8/6k1/6P1/5P2/r4NK1/8/4R3/8 w - - 1 63",
            "8/6k1/6P1/5PK1/r4N2/8/4R3/8 b - - 2 63")
        -- Osmanovic - Shirov Mainz 2005
        self:assert_move_san("Kb5",
            "4r3/p5pp/1n6/2k1p3/p2r4/2R1B3/1P2K1PP/8 b - - 1 29",
            "4r3/p5pp/1n6/1k2p3/p2r4/2R1B3/1P2K1PP/8 w - - 2 30")
        --- King captures
        -- Marshall - Lasker NewYork 1924
        self:assert_move_san("Kxf1",
            "4b2k/2q5/3bQ3/3p4/3P2N1/1P6/6R1/5rK1 w - - 0 45",
            "4b2k/2q5/3bQ3/3p4/3P2N1/1P6/6R1/5K2 b - - 0 45")
        -- Reti - Capablanca NewYork 1924
        self:assert_move_san("Kxg7",
            "r3rnk1/3n1pB1/1p1p2pp/pP6/2q1b3/P4NP1/3Q1PBP/R2R1NK1 b - - 0 21",
            "r3rn2/3n1pk1/1p1p2pp/pP6/2q1b3/P4NP1/3Q1PBP/R2R1NK1 w - - 0 22")
    end
    function TestChessBoard:test_24_move_san_castle()
        --- Castle kingside
        self:assert_move_san("O-O",
            "r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
            "r1bqkb1r/pppp1ppp/2n2n2/1B2p3/4P3/5N2/PPPP1PPP/RNBQ1RK1 b kq - 5 4")
        -- Steinitz - Zukertort ? ?
        self:assert_move_san("O-O",
            "r1bqk2r/ppppbppp/2nn4/4N3/8/3B4/PPPP1PPP/RNBQR1K1 b kq - 2 7",
            "r1bq1rk1/ppppbppp/2nn4/4N3/8/3B4/PPPP1PPP/RNBQR1K1 w - - 3 8")
        --- Castle queenside
        self:assert_move_san("O-O-O",
            "r1b1kb1r/1pqn1ppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/R3KB1R w KQkq - 3 9",
            "r1b1kb1r/1pqn1ppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/2KR1B1R b kq - 4 9")
        self:assert_move_san("O-O-O",
            "r3k2r/pppbqpb1/2npp2p/6p1/3PP1P1/2N2PN1/PPPQ2P1/2KR1B1R b kq - 2 13",
            "2kr3r/pppbqpb1/2npp2p/6p1/3PP1P1/2N2PN1/PPPQ2P1/2KR1B1R w - - 3 14")
        -- Test for moves that make castling not possible.
        -- King moves
        self:assert_move_san("Kf1",
            "r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 2 5",
            "r1bqkb1r/1ppp1ppp/p1n2n2/4p3/B3P3/5N2/PPPP1PPP/RNBQ1K1R b kq - 3 5")
        self:assert_move_san("Kf8",
            "r1bqk2r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 b kq - 1 7",
            "r1bq1k1r/2ppbppp/p1n2n2/1p2p3/4P3/1B3N2/PPPP1PPP/RNBQR1K1 w - - 2 8")
        -- Rook moves
        self:assert_move_san("Rh3",
            "r1bqk2r/1ppp1ppp/p1n2n2/2b1p3/B3P2P/5N2/PPPP1PP1/RNBQK2R w KQkq - 1 6",
            "r1bqk2r/1ppp1ppp/p1n2n2/2b1p3/B3P2P/5N1R/PPPP1PP1/RNBQK3 b Qkq - 2 6")
        self:assert_move_san("Rg8",
            "r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQR1K1 b kq - 2 5",
            "r1bqk1r1/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQR1K1 w q - 3 6")
        self:assert_move_san("Rd1",
            "rnbq1rk1/1p2bppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/R3KB1R w KQ - 0 9",
            "rnbq1rk1/1p2bppp/p2ppn2/6B1/3NPP2/2N2Q2/PPP3PP/3RKB1R b K - 1 9")
        self:assert_move_san("Rc8",
            "r2qkb1r/pp1bpppp/2np1n2/6B1/3NP3/2N5/PPPQ1PPP/R3KB1R b KQkq - 3 7",
            "2rqkb1r/pp1bpppp/2np1n2/6B1/3NP3/2N5/PPPQ1PPP/R3KB1R w KQk - 4 8")
        -- Rook captured by an enemy piece
        self:assert_move_san("Bxh1",
            "rn1qkbnr/pbpppppp/1p6/8/3P2P1/2N5/PPP1PP1P/R1BQKBNR b KQkq d3 0 3",
            "rn1qkbnr/p1pppppp/1p6/8/3P2P1/2N5/PPP1PP1P/R1BQKBNb w Qkq - 0 4")
        self:assert_move_san("Bxh8",
            "rnbqkbnr/pp1ppp1p/6p1/2p5/8/1P6/PBPPPPPP/RN1QKBNR w KQkq c6 0 3",
            "rnbqkbnB/pp1ppp1p/6p1/2p5/8/1P6/P1PPPPPP/RN1QKBNR b KQq - 0 3")
        self:assert_move_san("Bxa1",
            "rnbqk1nr/ppppppbp/6p1/8/4P3/1P3N2/P1PP1PPP/RNBQKB1R b KQkq - 2 3",
            "rnbqk1nr/pppppp1p/6p1/8/4P3/1P3N2/P1PP1PPP/bNBQKB1R w Kkq - 0 4")
        self:assert_move_san("Bxa8",
            "rnbqkb1r/p1pppppp/1p3n2/8/8/6P1/PPPPPPBP/RNBQK1NR w KQkq - 2 3",
            "Bnbqkb1r/p1pppppp/1p3n2/8/8/6P1/PPPPPP1P/RNBQK1NR b KQk - 0 3")
    end
    function TestChessBoard:test_25_move_san_ambiguities()
        -- TODO this one could use more tests
        -- File
        self:assert_move_san("Nfd7",
            "rnbqkb1r/ppp2ppp/4pn2/3pP3/3P4/2N5/PPP2PPP/R1BQKBNR b KQkq - 0 4",
            "rnbqkb1r/pppn1ppp/4p3/3pP3/3P4/2N5/PPP2PPP/R1BQKBNR w KQkq - 1 5")
        -- Rank
        self:assert_move_san("R1h2+",
            "8/5R2/2k1p1p1/B3P1p1/7r/1B6/6K1/7r b - - 2 38",
            "8/5R2/2k1p1p1/B3P1p1/7r/1B6/6Kr/8 w - - 3 39")
        -- Square
        self:assert_move_san("Qd4e5",
            "k7/8/3Q4/8/3Q1Q2/8/8/K7 w - - 0 1",
            "k7/8/3Q4/4Q3/5Q2/8/8/K7 b - - 1 1")
    end
-- class

ret = LuaUnit:run()
if ret > 0 then os.exit(1) end
