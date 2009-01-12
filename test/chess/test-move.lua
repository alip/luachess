#!/usr/bin/env lua
-- vim: set et sts=4 sw=4 ts=4 tw=80 fdm=marker:
--[[
  Copyright (c) 2009 Ali Polatel <polatel@gmail.com>

  This file is part of LuaChess. LuaChess is free software; you can redistribute
  it and/or modify it under the terms of the GNU General Public License version
  KNIGHT, as published by the Free Software Foundation.

  LuaChess is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
  Place, Suite 330, Boston, MA  02111-1307  USA
--]]

-- Unit tests for move parsing module.
-- Requires luaunit.

require "luaunit"
require "customloaders"

require "chess"

local WHITE = chess.attack.WHITE
local BLACK = chess.attack.BLACK

local KING = chess.attack.KING
local QUEEN = chess.attack.QUEEN
local ROOK = chess.attack.ROOK
local BISHOP = chess.attack.BISHOP
local KNIGHT = chess.attack.KNIGHT
local PAWN = chess.attack.PAWN

local move = chess.move

-- Helper functions
local function assert_move(m, piece, to, from, capture, check, promotion)
    local _for = " for '" .. m .. "'"
    local ts = tostring
    local p = assert(move.san_move:match(m), "failed to parse '" .. m .. "'")
    assert(type(p) == "table", "didn't create table capture" .. _for)
    assert(p.piece == piece, "c.piece='" .. ts(p.piece) .. "'" .. _for)
    assert(p.to == to, "c.to='" .. ts(p.to) .. "'" .. _for)
    assert(not from or p.from == from, "c.from='" .. ts(p.from) .. "'" .. _for)
    assert(not capture or p.capture, "c.capture='" .. ts(p.capture) .. "'" .. _for)
    assert(not check or p.check == check, "c.check='" .. ts(p.check) .. "'" .. _for)
    assert(not promotion or p.promotion == promotion, "c.promotion='" ..
        ts(p.promotion) .. "'" .. _for)
end
local function assert_castle(m, short, long)
    local p = assert(move.san_move:match(m), "failed to parse '" .. m .. "'")
    assert(type(p) == "table", "didn't create table capture for '" ..m .. "'")
    assert(not short or p.castle_short, "failed to parse short castle")
    assert(not long or p.castle_long, "failed to parse long castle")
end
local function assert_fen_piece(m, pattern, piece, colour)
    assert(pattern:match(m) == piece)
    assert(select(2, pattern:match(m)) == colour)
    assert(select("#", pattern:match(m)) == 2)
end

TestMove = {} -- class
    function TestMove:test_01_number()
        assert(type(move.number:match"13") == "number", "failed to grab number")
        assert(not move.number:match"foo", "parsed 'foo'")
    end
    function TestMove:test_02_coord()
        for c=string.byte"a",string.byte"h" do
            assert(move.coord:match(string.char(c)),
                "failed to parse '" .. string.char(c) .. "'")
        end
        assert(not move.coord:match"i", "parsed 'i'")
    end
    function TestMove:test_03_rank()
        for c=1,8 do
            assert(move.rank:match(tostring(c)), "failed to parse '" .. c .. "'")
        end
        assert(not move.rank:match"foo", "parsed 'foo'")
    end
    function TestMove:test_04_coord_only()
        for c=string.byte"a",string.byte"h" do
            assert(move.coord_only:match(string.char(c)),
                "failed to parse '" .. string.char(c) .. "'")
        end
        assert(not move.coord_only:match"e4", "parsed 'e4'")
    end
    function TestMove:test_05_square()
        for file=string.byte"a",string.byte"h" do
            for rank=1,8 do
                assert(move.square:match(string.char(file) .. rank),
                    "failed to parse '" .. string.char(file) .. rank .. "'")
            end
        end
        assert(not move.square:match"E4", "parsed 'E4'")
    end
    function TestMove:test_08_san_king()
        assert(move.san_king:match"K" == KING, "failed to parse 'K'")
        assert(not move.san_king:match"k", "parsed 'k'")
        assert(not move.san_king:match"foo", "parsed 'foo'")
    end
    function TestMove:test_09_san_queen()
        assert(move.san_queen:match"Q" == QUEEN, "failed to parse 'Q'")
        assert(not move.san_queen:match"q", "parsed 'k'")
        assert(not move.san_queen:match"bar", "parsed 'bar'")
    end
    function TestMove:test_10_san_rook()
        assert(move.san_rook:match"R" == ROOK, "failed to parse 'R'")
        assert(not move.san_rook:match"r", "parsed 'r'")
        assert(not move.san_rook:match"baz", "parsed 'baz'")
    end
    function TestMove:test_11_san_bishop()
        assert(move.san_bishop:match"B" == BISHOP, "failed to parse 'B'")
        assert(not move.san_bishop:match"b", "parsed 'b'")
        assert(not move.san_bishop:match"lucy", "parsed 'lucy'")
    end
    function TestMove:test_12_san_knight()
        assert(move.san_knight:match"N" == KNIGHT, "failed to parse 'N'")
        assert(not move.san_knight:match"b", "parsed 'n'")
        assert(not move.san_knight:match"arnold", "parsed 'arnold'")
    end
    function TestMove:test_13_san_pawn()
        assert(move.san_pawn:match"" == PAWN, "failed to parse ''")
    end
    function TestMove:test_14_san_piece()
        assert(move.san_piece:match"K" == KING, "failed to parse 'K'")
        assert(move.san_piece:match"Q" == QUEEN, "failed to parse 'Q'")
        assert(move.san_piece:match"R" == ROOK, "failed to parse 'R'")
        assert(move.san_piece:match"B" == BISHOP, "failed to parse 'B'")
        assert(move.san_piece:match"N" == KNIGHT, "failed to parse 'N'")
    end
    function TestMove:test_15_san_capture()
        assert(move.san_capture:match"x", "failed to parse 'x'")
        assert(not move.san_capture:match"X", "parsed 'X'")
        assert(not move.san_capture:match":", "parsed ':'")
    end
    function TestMove:test_16_san_check()
        assert(move.san_check:match"+" == "+", "failed to parse '+'")
        assert(not move.san_check:match"-", "parsed '-'")
    end
    function TestMove:test_17_san_checkmate()
        assert(move.san_checkmate:match"#" == "#", "failed to parse '#'")
        assert(not move.san_checkmate:match"++", "parsed '++'")
    end
    function TestMove:test_18_san_checkormate()
        assert(move.san_checkormate:match"+" == "+", "failed to parse '+'")
        assert(move.san_checkormate:match"#" == "#", "failed to parse '#'")
    end
    function TestMove:test_19_san_castle_short()
        assert(move.san_castle_short:match"O-O" == "O-O", "failed to parse 'O-O'")
        assert(not move.san_castle_short:match"o-o", "parsed 'o-o'")
        assert(not move.san_castle_short:match"0-0", "parsed '0-0'")
    end
    function TestMove:test_20_san_castle_long()
        assert(move.san_castle_long:match"O-O-O" == "O-O-O", "failed to parse 'O-O-O'")
        assert(not move.san_castle_long:match"o-o-o", "parsed 'o-o-o'")
        assert(not move.san_castle_long:match"0-0-0", "parsed '0-0-0'")
    end
    function TestMove:test_21_san_disambiguity()
        for file=string.byte"a",string.byte"h" do
            for rank=1,8 do
                assert(move.san_disambiguity:match(string.char(file)),
                    "failed to parse '" .. string.char(file) .. "'")
                assert(move.san_disambiguity:match(rank),
                    "failed to parse '" .. rank .. "'")
                assert(move.san_disambiguity:match(string.char(file) .. rank),
                    "failed to parse '" .. string.char(file) .. rank .. "'")
            end
        end
        assert(not move.san_disambiguity:match"E4", "parsed 'E4'")
    end
    function TestMove:test_22_san_promotion()
        assert(move.san_promotion:match"=Q" == QUEEN, "failed to parse '=Q'")
        assert(move.san_promotion:match"=R" == ROOK, "failed to parse '=R'")
        assert(move.san_promotion:match"=B" == BISHOP, "failed to parse '=B'")
        assert(move.san_promotion:match"=N" == KNIGHT, "failed to parse '=N'")
        assert(not move.san_promotion:match"=K", "parsed '=K'")
        assert(not move.san_promotion:match"=P", "parsed '=P'")
    end
    function TestMove:test_23_san_move_pawn()
        assert_move("a8", PAWN, "a8")
        assert_move("b7", PAWN, "b7")
        assert_move("c6", PAWN, "c6")
        assert_move("d5", PAWN, "d5")
        assert_move("e4", PAWN, "e4")
        assert_move("f3", PAWN, "f3")
        assert_move("g2", PAWN, "g2")
        assert_move("h1", PAWN, "h1")
    end
    function TestMove:test_24_san_move_pawn_capture()
        assert_move("axb7", PAWN, "b7", "a", true)
        assert_move("bxc6", PAWN, "c6", "b", true)
        assert_move("cxd5", PAWN, "d5", "c", true)
        assert_move("dxe4", PAWN, "e4", "d", true)
        assert_move("exf3", PAWN, "f3", "e", true)
        assert_move("fxg2", PAWN, "g2", "f", true)
        assert_move("gxh1", PAWN, "h1", "g", true)
        assert_move("hxg2", PAWN, "g2", "h", true)
    end
    function TestMove:test_25_san_move_pawn_check()
        assert_move("a8+", PAWN, "a8", nil, nil, "+")
        assert_move("b7#", PAWN, "b7", nil, nil, "#")
        assert_move("c6+", PAWN, "c6", nil, nil, "+")
        assert_move("d5#", PAWN, "d5", nil, nil, "#")
        assert_move("e4+", PAWN, "e4", nil, nil, "+")
        assert_move("f3#", PAWN, "f3", nil, nil, "#")
        assert_move("g2+", PAWN, "g2", nil, nil, "+")
        assert_move("h1#", PAWN, "h1", nil, nil, "#")
    end
    function TestMove:test_26_san_move_pawn_promotion()
        assert_move("a8=Q", PAWN, "a8", nil, nil, nil, QUEEN)
        assert_move("b1=R", PAWN, "b1", nil, nil, nil, ROOK)
        assert_move("c8=B", PAWN, "c8", nil, nil, nil, BISHOP)
        assert_move("d1=N", PAWN, "d1", nil, nil, nil, KNIGHT)
    end
    function TestMove:test_27_san_move_pawn_capture_check()
        assert_move("axb7+", PAWN, "b7", "a", true, "+")
        assert_move("bxc6#", PAWN, "c6", "b", true, "#")
        assert_move("cxd5+", PAWN, "d5", "c", true, "+")
        assert_move("dxe4#", PAWN, "e4", "d", true, "#")
        assert_move("exf3+", PAWN, "f3", "e", true, "+")
        assert_move("fxg2#", PAWN, "g2", "f", true, "#")
        assert_move("gxh1+", PAWN, "h1", "g", true, "+")
        assert_move("hxg2#", PAWN, "g2", "h", true, "#")
    end
    function TestMove:test_28_san_move_pawn_capture_promotion()
        assert_move("axb7=Q", PAWN, "b7", "a", true, nil, QUEEN)
        assert_move("bxc6=R", PAWN, "c6", "b", true, nil, ROOK)
        assert_move("cxd5=B", PAWN, "d5", "c", true, nil, BISHOP)
        assert_move("dxe4=N", PAWN, "e4", "d", true, nil, KNIGHT)
    end
    function TestMove:test_29_san_move_pawn_check_promotion()
        assert_move("a8=Q+", PAWN, "a8", nil, nil, "+", QUEEN)
        assert_move("b7=R#", PAWN, "b7", nil, nil, "#", ROOK)
        assert_move("c6=B+", PAWN, "c6", nil, nil, "+", BISHOP)
        assert_move("d5=N#", PAWN, "d5", nil, nil, "#", KNIGHT)
    end
    function TestMove:test_30_san_move_pawn_capture_check_promotion()
        assert_move("bxa8=Q+", PAWN, "a8", "b", true, "+", QUEEN)
        assert_move("cxb7=R#", PAWN, "b7", "c", true, "#", ROOK)
        assert_move("dxc6=B+", PAWN, "c6", "d", true, "+", BISHOP)
        assert_move("exd5=N#", PAWN, "d5", "e", true, "#", KNIGHT)
    end
    function TestMove:test_31_san_move_piece()
        assert_move("Ke1", KING, "e1")
        assert_move("Qd5", QUEEN, "d5")
        assert_move("Re8", ROOK, "e8")
        assert_move("Bg2", BISHOP, "g2")
        assert_move("Nf3", KNIGHT, "f3")
    end
    function TestMove:test_32_san_move_piece_capture()
        assert_move("Kxf3", KING, "f3", nil, true)
        assert_move("Qxf8", QUEEN, "f8", nil, true)
        assert_move("Rxh5", ROOK, "h5", nil, true)
        assert_move("Bxd4", BISHOP, "d4", nil, true)
        assert_move("Nxd8", KNIGHT, "d8", nil, true)
    end
    function TestMove:test_32_san_move_piece_check()
        assert_move("Kf3#", KING, "f3", nil, nil, "#")
        assert_move("Qf8+", QUEEN, "f8", nil, nil, "+")
        assert_move("Rh5#", ROOK, "h5", nil, nil, "#")
        assert_move("Bd4+", BISHOP, "d4", nil, nil, "+")
        assert_move("Nd8#", KNIGHT, "d8", nil, nil, "#")
    end
    function TestMove:test_33_san_move_piece_capture_check()
        assert_move("Kxf3+", KING, "f3", nil, true, "+")
        assert_move("Qxf8#", QUEEN, "f8", nil, true, "#")
        assert_move("Rxh5+", ROOK, "h5", nil, true, "+")
        assert_move("Bxd4#", BISHOP, "d4", nil, true, "#")
        assert_move("Nxd8+", KNIGHT, "d8", nil, true, "+")
    end
    function TestMove:test_34_san_move_piece_amb_file()
        assert_move("Qad1", QUEEN, "d1", "a")
        assert_move("Rfe8", ROOK, "e8", "f")
        assert_move("Baf3", BISHOP, "f3", "a")
        assert_move("Nge2", KNIGHT, "e2", "g")
    end
    function TestMove:test_35_san_move_piece_amb_file_capture()
        assert_move("Qaxd1", QUEEN, "d1", "a", true)
        assert_move("Rfxe8", ROOK, "e8", "f", true)
        assert_move("Baxf3", BISHOP, "f3", "a", true)
        assert_move("Ngxe2", KNIGHT, "e2", "g", true)
    end
    function TestMove:test_35_san_move_piece_amb_file_check()
        assert_move("Qad1+", QUEEN, "d1", "a", nil, "+")
        assert_move("Rfe8#", ROOK, "e8", "f", nil, "#")
        assert_move("Baf3+", BISHOP, "f3", "a", nil, "+")
        assert_move("Nge2#", KNIGHT, "e2", "g", nil, "#")
    end
    function TestMove:test_36_san_move_piece_amb_file_capture_check()
        assert_move("Qaxd1+", QUEEN, "d1", "a", true, "+")
        assert_move("Rfxe8#", ROOK, "e8", "f", true, "#")
        assert_move("Baxf3+", BISHOP, "f3", "a", true, "+")
        assert_move("Ngxe2#", KNIGHT, "e2", "g", true, "#")
    end
    function TestMove:test_37_san_move_piece_amb_rank()
        assert_move("Q1f3", QUEEN, "f3", "1")
        assert_move("R2d7", ROOK, "d7", "2")
        assert_move("B3f8", BISHOP, "f8", "3")
        assert_move("N1e2", KNIGHT, "e2", "1")
    end
    function TestMove:test_38_san_move_piece_amb_rank_capture()
        assert_move("Q1xf3", QUEEN, "f3", "1", true)
        assert_move("R2xd7", ROOK, "d7", "2", true)
        assert_move("B3xf8", BISHOP, "f8", "3", true)
        assert_move("N1xe2", KNIGHT, "e2", "1", true)
    end
    function TestMove:test_39_san_move_piece_amb_rank_check()
        assert_move("Q1f3+", QUEEN, "f3", "1", nil, "+")
        assert_move("R2d7#", ROOK, "d7", "2", nil, "#")
        assert_move("B3f8+", BISHOP, "f8", "3", nil, "+")
        assert_move("N1e2#", KNIGHT, "e2", "1", nil, "#")
    end
    function TestMove:test_40_san_move_piece_amb_rank_capture_check()
        assert_move("Q1xf3+", QUEEN, "f3", "1", true, "+")
        assert_move("R2xd7#", ROOK, "d7", "2", true, "#")
        assert_move("B3xf8+", BISHOP, "f8", "3", true, "+")
        assert_move("N1xe2#", KNIGHT, "e2", "1", true, "#")
    end
    function TestMove:test_41_san_move_piece_amb_square()
        assert_move("Qa8d8", QUEEN, "d8", "a8")
        assert_move("Rd1f1", ROOK, "f1", "d1")
        assert_move("Be5g7", BISHOP, "g7", "e5")
        assert_move("Nf8h7", KNIGHT, "h7", "f8")
    end
    function TestMove:test_42_san_move_piece_amb_square_capture()
        assert_move("Qa8xd8", QUEEN, "d8", "a8", true)
        assert_move("Rd1xf1", ROOK, "f1", "d1", true)
        assert_move("Be5xg7", BISHOP, "g7", "e5", true)
        assert_move("Nf8xh7", KNIGHT, "h7", "f8", true)
    end
    function TestMove:test_43_san_move_piece_amb_square_check()
        assert_move("Qa8d8+", QUEEN, "d8", "a8", nil, "+")
        assert_move("Rd1f1#", ROOK, "f1", "d1", nil, "#")
        assert_move("Be5g7+", BISHOP, "g7", "e5", nil, "+")
        assert_move("Nf8h7#", KNIGHT, "h7", "f8", nil, "#")
    end
    function TestMove:test_44_san_move_piece_amb_square_capture_check()
        assert_move("Qa8xd8+", QUEEN, "d8", "a8", true, "+")
        assert_move("Rd1xf1#", ROOK, "f1", "d1", true, "#")
        assert_move("Be5xg7+", BISHOP, "g7", "e5", true, "+")
        assert_move("Nf8xh7#", KNIGHT, "h7", "f8", true, "#")
    end
    function TestMove:test_45_san_move_castle()
        assert_castle("O-O", true)
        assert_castle("O-O-O", nil, true)
    end
    function TestMove:test_46_fen_king()
        assert_fen_piece("K", move.fen_king, KING, WHITE)
        assert_fen_piece("k", move.fen_king, KING, BLACK)
    end
    function TestMove:test_47_fen_queen()
        assert_fen_piece("Q", move.fen_queen, QUEEN, WHITE)
        assert_fen_piece("q", move.fen_queen, QUEEN, BLACK)
    end
    function TestMove:test_48_fen_rook()
        assert_fen_piece("R", move.fen_rook, ROOK, WHITE)
        assert_fen_piece("r", move.fen_rook, ROOK, BLACK)
    end
    function TestMove:test_49_fen_bishop()
        assert_fen_piece("B", move.fen_bishop, BISHOP, WHITE)
        assert_fen_piece("b", move.fen_bishop, BISHOP, BLACK)
    end
    function TestMove:test_50_fen_knight()
        assert_fen_piece("N", move.fen_knight, KNIGHT, WHITE)
        assert_fen_piece("n", move.fen_knight, KNIGHT, BLACK)
    end
    function TestMove:test_51_fen_pawn()
        assert_fen_piece("P", move.fen_pawn, PAWN, WHITE)
        assert_fen_piece("p", move.fen_pawn, PAWN, BLACK)
    end
    function TestMove:test_52_fen_piece()
        local c = move.fen_piece:match"K"
        assert(c)
        assert(type(c) == "table")
        assert(#c == 2)
        assert(c[1] == KING)
        assert(c[2] == WHITE)
    end
    function TestMove:test_53_fen_piece_placement()
        local expected = {
            {ROOK, BLACK}, {KNIGHT, BLACK}, {BISHOP, BLACK}, {KING, BLACK},
            {QUEEN, BLACK}, {BISHOP, BLACK}, {KNIGHT, BLACK}, {ROOK, BLACK},
            {PAWN, BLACK}, {PAWN, BLACK}, {PAWN, BLACK}, {PAWN, BLACK},
            {PAWN, BLACK}, {PAWN, BLACK}, {PAWN, BLACK}, {PAWN, BLACK},
            8, 8, 8, 8,
            {PAWN, WHITE}, {PAWN, WHITE}, {PAWN, WHITE}, {PAWN, WHITE},
            {PAWN, WHITE}, {PAWN, WHITE}, {PAWN, WHITE}, {PAWN, WHITE},
            {ROOK, WHITE}, {KNIGHT, WHITE}, {BISHOP, WHITE}, {KING, WHITE},
            {QUEEN, WHITE}, {BISHOP, WHITE}, {KNIGHT, WHITE}, {ROOK, WHITE},
        }
        local c = move.fen_piece_placement:match
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR"
        assert(c)
        assert(type(c) == "function")
        for i, piece in c() do
            assert(type(piece) == "number" or type(piece) == "table")
            if type(piece) == "table" then
                assert(#piece == 2)
                assert(piece[1] == expected[i][1])
                assert(piece[2] == expected[i][2])
            else
                assert(piece == expected[i])
            end
        end
    end
    function TestMove:test_54_fen_side()
        assert(move.fen_side:match"w" == WHITE)
        assert(move.fen_side:match"b" == BLACK)
    end
    function TestMove:test_55_fen_castle_white()
        local expected = {{KING, WHITE}, {QUEEN, WHITE}}
        local c = move.fen_castle:match"KQ"
        assert(c)
        assert(type(c) == "function")
        for i, piece in c() do
            assert(type(piece) == "table")
            assert(#piece == 2)
            assert(piece[1] == expected[i][1])
            assert(piece[2] == expected[i][2])
        end
    end
    function TestMove:test_56_fen_castle_black()
        local expected = {{KING, BLACK}, {QUEEN, BLACK}}
        local c = move.fen_castle:match"kq"
        assert(c)
        assert(type(c) == "function")
        for i, piece in c() do
            assert(type(piece) == "table")
            assert(#piece == 2)
            assert(piece[1] == expected[i][1])
            assert(piece[2] == expected[i][2])
        end
    end
    function TestMove:test_57_fen_castle_none()
        local c = move.fen_castle:match"-"
        assert(c)
        assert(type(c) == "function")
        for i, castle in c() do
            assert(i == 1)
            assert(castle == "-")
        end
    end
    function TestMove:test_58_fen_epsquare()
        assert(move.fen_epsquare:match"-" == "-")
        assert(move.fen_epsquare:match"e3" == "e3")
        assert(move.fen_epsquare:match"d6" == "d6")
        assert(not move.fen_epsquare:match"e5")
        assert(not move.fen_epsquare:match"f4")
    end
    function TestMove:test_59_fen_rhc()
        assert(move.fen_rhc:match"10" == 10)
        assert(not move.fen_rhc:match"foo")
    end
    function TestMove:test_60_fen_fmc()
        assert(move.fen_fmc:match"10" == 10)
        assert(not move.fen_fmc:match"foo")
    end
    function TestMove:test_61_fen()
        assert(move.fen:match"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        assert(move.fen:match"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        assert(move.fen:match
            "rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2")
        assert(move.fen:match
            "rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2")
    end
-- class

ret = LuaUnit:run()
if ret > 0 then os.exit(1) end
