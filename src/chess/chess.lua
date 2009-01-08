#!/usr/bin/env lua
-- vim: set et sts=4 sw=4 ts=4 tw=80 fdm=marker:
--[[
  Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
    based in part upon GNU Chess 5.0 which is
    Copyright (c) 1999-2002 Free Software Foundation, Inc.

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

-- Main chess module for LuaChess
-- Requires bitlib and lpeg
-- Note: bitop treats integers as 32 bits but we need doubles to represent
-- moves.

--{{{Grab environment
-- Builtin functions
local assert = assert
local error = error
local setmetatable = setmetatable
local type = type
local unpack = unpack

--XXX for debugging
local print = print
local tostring = tostring

-- Builtin modules
local math = math
local string = string

-- Other required modules
local bit = require "bit"

-- Internal modules
local bitboard = require "bitboard"
local attack = require "attack"
local moveparser = require "move"
--}}}
--{{{Shortcuts to module functions
local band, bnot, bor, bxor, lshift, rshift = bit.band, bit.bnot, bit.bor, bit.bxor,
    bit.lshift, bit.rshift
local bb = bitboard.bb
--}}}
module "chess"
_VERSION = bitboard._VERSION
NULL = bb(0)
--{{{Bitwise functions
function setbit(a, b) return bor(a, lshift(1, b)) end
function clrbit(a, b) return band(a, bnot(lshift(1, b))) end
function tstbit(a, b) return band(a, b) ~= 0 end
--}}}
--{{{Sides
WHITE = attack.WHITE
BLACK = attack.BLACK
function switch_side(side) return bxor(1, side - 1) + 1 end
--}}}
--{{{Pieces
PAWN = attack.PAWN
KNIGHT = attack.KNIGHT
BISHOP = attack.BISHOP
ROOK = attack.ROOK
QUEEN = attack.QUEEN
KING = attack.KING
function piece_tostring(piece, side)
    assert(side == WHITE or side == BLACK, "invalid side")
    local s
    if piece == PAWN then s = "P"
    elseif piece == KNIGHT then s = "N"
    elseif piece == BISHOP then s = "B"
    elseif piece == ROOK then s = "R"
    elseif piece == QUEEN then s = "Q"
    elseif piece == KING then s = "K"
    else error "undefined piece" end

    if side == BLACK then s = string.lower(s) end
    return s
end
function piece_toindex(cpiece)
    local lpiece = string.lower(cpiece)
    if lpiece == "p" then return PAWN
    elseif lpiece == "n" then return KNIGHT
    elseif lpiece == "b" then return BISHOP
    elseif lpiece == "r" then return ROOK
    elseif lpiece == "q" then return QUEEN
    elseif lpiece == "k" then return KING
    else error "undefined piece" end
end
--}}}
--{{{Squares
a8, b8, c8, d8, e8, f8, g8, h8 = 56, 57, 58, 59, 60, 61, 62, 63
a7, b7, c7, d7, e7, f7, g7, h7 = 48, 49, 50, 51, 52, 53, 54, 55
a6, b6, c6, d6, e6, f6, g6, h6 = 40, 41, 42, 43, 44, 45, 46, 47
a5, b5, c5, d5, e5, f5, g5, h5 = 32, 33, 34, 35, 36, 37, 38, 39
a4, b4, c4, d4, e4, f4, g4, h4 = 24, 25, 26, 27, 28, 29, 30, 31
a3, b3, c3, d3, e3, f3, g3, h3 = 16, 17, 18, 19, 20, 21, 22, 23
a2, b2, c2, d2, e2, f2, g2, h2 =  8,  9, 10, 11, 12, 13, 14, 15
a1, b1, c1, d1, e1, f1, g1, h1 =  0,  1,  2,  3,  4,  5,  6,  7
function rank(square) return rshift(square, 3) + 1 end
function file(square) return band(square, 7) + 1 end
function filec(square) return string.char(file(square) + 96) end
function squarec(square) return filec(square) .. rank(square) end
function squarei(csquare)
    assert(type(csquare) == "string", "invalid square")
    assert(string.match(csquare, "^[a-h][1-8]$"), "invalid square")
    local file = string.byte(string.sub(csquare, 1, 1)) - 96
    local rank = string.sub(csquare, 2, 2)
    return lshift(rank, 3) + (file % -9)
end
function square_left(square)
    assert(square > -1 and square < 64, "invalid square")
    if square % 8 ~= 0 then return square - 1 end
end
function square_right(square)
    assert(square > -1 and square < 64, "invalid square")
    if square % 8 ~= 7 then return square + 1 end
end
function square_up(square)
    assert(square > -1 and square < 64, "invalid square")
    if square < 55 then return square + 8 end
end
function square_down(square)
    assert(square > -1 and square < 64, "invalid square")
    if square > 7 then return square - 8 end
end
function square_border(square)
    assert(square > -1 and square < 64, "invalid square")
    local f, r = file(square), rank(square)
    return f == 1 or f == 8 or r == 1 or r == 8
end
--}}}
--{{{Moves
-- Constants for move description
KNIGHTPRM = 0x00002000
BISHOPPRM = 0x00003000
ROOKPRM   = 0x00004000
QUEENPRM  = 0x00005000
PROMOTION = 0x00007000
PAWNCAP   = 0x00008000
KNIGHTCAP = 0x00010000
BISHOPCAP = 0x00018000
ROOKCAP   = 0x00020000
QUEENCAP  = 0x00028000
KINGCAP   = 0x00030000 -- Possible in some wild variants
CAPTURE   = 0x00038000
NULLMOVE  = 0x00100000
CASTLING  = 0x00200000
ENPASSANT = 0x00400000
MOVEMASK  = bor(CASTLING, ENPASSANT, PROMOTION, 0x0FFF)
function tosq(move) return band(move, 0x003F) end
function fromsq(move) return band(rshift(move, 6), 0x003F) end
function move(from, to) return bor(lshift(from, 6), to) end
function capture_piece(move) return band(rshift(move, 15), 0x0007) end
function promote_piece(move) return band(rshift(move, 12), 0x0007) end
--}}}
--{{{Board
Board = setmetatable({}, {
    __call = function (self, argtable)
        assert(type(argtable) == "table", "argument not a table")
        assert(not argtable.side or argtable.side == WHITE or argtable.side == BLACK,
            "invalid side")
        assert(argtable.check_legality == nil or
            type(argtable.check_legality) == "boolean",
            "check_legality should be of boolean type")
        if argtable.check_legality == nil then argtable.check_legality = true end
        assert(not argtable.ep or (argtable.ep > -1 and argtable.ep < 64),
            "invalid en passant square")

        assert(not argtable.castle or type(argtable.castle) == "table",
            "castle not a table")
        if argtable.castle then
            assert(type(argtable.castle[1]) == "table", "castle[1] not a table")
            assert(type(argtable.castle[2]) == "table", "castle[2] not a table")
            assert(type(argtable.castle[1][1]) == "boolean", "castle[1][1] not a boolean")
            assert(type(argtable.castle[1][2]) == "boolean", "castle[1][2] not a boolean")
            assert(type(argtable.castle[2][1]) == "boolean", "castle[2][1] not a boolean")
            assert(type(argtable.castle[2][2]) == "boolean", "castle[2][2] not a boolean")
        end

        assert(not argtable.rooks or type(argtable.rooks) == "table",
            "rooks not a table")
        if argtable.rooks then
            assert(argtable.rooks[1] > -1 and argtable.rooks[1] < 64,
                "rooks[1] is an invalid square")
            assert(argtable.rooks[2] > -1 and argtable.rooks[2] < 64,
                "rooks[2] is an invalid square")
        end

        local board = {
            bitboard = {
                -- Occupied squares
                -- First is white, second is black, third is all, fourth is empty.
                occupied = {bb(0), bb(0), bb(0), bb(0)},
                -- Pieces, first table is white pieces (1=pawn,6=king),
                -- second table is black pieces.
                pieces = {
                    {bb(0), bb(0), bb(0), bb(0), bb(0), bb(0)},
                    {bb(0), bb(0), bb(0), bb(0), bb(0), bb(0)},
                },
            },
            -- cboard[sq+1] gives the piece on square sq.
            cboard = {
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
                0, 0, 0, 0, 0, 0, 0, 0,
            },
            side = argtable.side or WHITE,
            check_legality = argtable.check_legality,
            ep = argtable.ep or -1,
            -- Castling
            castle = argtable.castle or {{false, false}, {false, false}},
            -- Initial locations for white rooks.
            -- This is needed to implement fischerandom castling easily.
            rooks = argtable.rooks or {squarei"h1", squarei"a1"}
        }
        return setmetatable(board, {__index = self,
        __tostring = function (board) --{{{
                local s = "  a b c d e f g h"
                for rank=8,1,-1 do
                    s = s .. "\n" .. rank .. " "
                    for file=string.byte"a",string.byte"h" do
                        local sq = string.char(file) .. rank
                        local piece, side = board:get_piece(squarei(sq))
                        if not piece then
                            s = s .. "-" .. " "
                        else
                            s = s .. piece_tostring(piece, side) .. " "
                        end
                    end

                    if rank == 8 then
                        local tomove = "?"
                        if board.side == WHITE then tomove = "White"
                        elseif board.side == BLACK then tomove = "Black" end
                        s = s .. "\tTomove: " .. tomove
                    elseif rank == 7 then
                        local castles = "\tCastles: "
                        if board.castle[WHITE][1] then
                            castles = castles .. "ws=true, "
                        else
                            castles = castles .. "ws=false, "
                        end
                        if board.castle[WHITE][2] then
                            castles = castles .. "wl=true, "
                        else
                            castles = castles .. "wl=false, "
                        end
                        if board.castle[BLACK][1] then
                            castles = castles .. "bs=true, "
                        else
                            castles = castles .. "bs=false, "
                        end
                        if board.castle[BLACK][2] then
                            castles = castles .. "bl=true"
                        else
                            castles = castles .. "bl=false"
                        end
                        s = s .. castles
                    elseif rank == 6 then
                        ep = "\tEn passant: "
                        if board.ep == -1 then ep = ep .. "none"
                        else ep = ep .. squarec(board.ep) end
                        s = s .. ep
                    end
                end
                return s
            end
--}}}
        })
    end
    })
function Board:update_cboard() --{{{
    self.cboard = {
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    }
    for p=PAWN,KING do
        local o = self.bitboard.pieces[WHITE][p] + self.bitboard.pieces[BLACK][p]
        while o ~= NULL do
            local sq = o:leadz()
            o:clrbit63(sq)
            self.cboard[-((sq + 1) % -65)] = p
        end
    end
end --}}}
function Board:update_occupied() --{{{
    self.bitboard.occupied = {bb(0), bb(0), bb(0), bb(0)}
    for side=WHITE,BLACK do
        for piece=PAWN,KING do
            self.bitboard.occupied[side] = self.bitboard.occupied[side] +
                                        self.bitboard.pieces[side][piece]
        end
    end

    self.bitboard.occupied[3] = self.bitboard.occupied[WHITE] +
                                self.bitboard.occupied[BLACK]
    self.bitboard.occupied[4] = -self.bitboard.occupied[3]
end --}}}
function Board:update() --{{{
    self:update_cboard()
    self:update_occupied()
end --}}}
function Board:set_piece(square, piece, side, noupdate) --{{{
    assert(square > -1 and square < 64, "invalid square")
    assert(piece >= PAWN and piece <= KING, "invalid piece")
    assert(side == WHITE or side == BLACK, "invalid side")
    self.bitboard.pieces[side][piece]:setbit(square)
    if not noupdate then self:update() end
end --}}}
function Board:get_piece(square) --{{{
    assert(square > -1 and square < 64, "invalid square")
    local piece = self.cboard[square + 1]
    if piece == PAWN then
        if self.bitboard.pieces[WHITE][PAWN]:tstbit(square) then
            return PAWN, WHITE
        else
            return PAWN, BLACK
        end
    elseif piece == KNIGHT then
        if self.bitboard.pieces[WHITE][KNIGHT]:tstbit(square) then
            return KNIGHT, WHITE
        else
            return KNIGHT, BLACK
        end
    elseif piece == BISHOP then
        if self.bitboard.pieces[WHITE][BISHOP]:tstbit(square) then
            return BISHOP, WHITE
        else
            return BISHOP, BLACK
        end
    elseif piece == ROOK then
        if self.bitboard.pieces[WHITE][ROOK]:tstbit(square) then
            return ROOK, WHITE
        else
            return ROOK, BLACK
        end
    elseif piece == QUEEN then
        if self.bitboard.pieces[WHITE][QUEEN]:tstbit(square) then
            return QUEEN, WHITE
        else
            return QUEEN, BLACK
        end
    elseif piece == KING then
        if self.bitboard.pieces[WHITE][KING]:tstbit(square) then
            return KING, WHITE
        else
            return KING, BLACK
        end
    end
end --}}}
function Board:clear_piece(square, noupdate) --{{{
    -- assert(square > -1 and square < 64, "invalid square")
    -- assert not needed because it calls get_piece() right away.
    local piece, side = self:get_piece(square)
    if not piece then return false
    else self.bitboard.pieces[side][piece]:clrbit(square) end
    if not noupdate then self:update() end
    return true
end --}}}
function Board:clear_all() --{{{
    self.bitboard.occupied = {bb(0), bb(0), bb(0), bb(0)}
    self.bitboard.pieces = {
        {bb(0), bb(0), bb(0), bb(0), bb(0), bb(0)},
        {bb(0), bb(0), bb(0), bb(0), bb(0), bb(0)},
    }
    self.cboard = {
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
    }
end --}}}
function Board:has_piece(square, side) --{{{
    assert(square > -1 and square < 64, "invalid square")
    assert(not side or side == WHITE or side == BLACK, "invalid side")
    if not side then return self.bitboard.occupied[3]:tstbit(square)
    else return self.bitboard.occupied[side]:tstbit(square) end
end --}}}
function Board:loadfen(fen) --{{{
    fen = fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    local pieces, side, castles, ep, hmove, fmove = moveparser.fen:match(fen)
    assert(pieces and side and castles and ep and hmove and fmove, "invalid fen")

    -- Set the pieces
    self:clear_all()
    local sq = 63
    for _, element in pieces() do
        if type(element) == "number" then
            sq = sq - element
        else
            self:set_piece(sq, element[1], element[2], true)
            sq = sq - 1
        end
    end
    self:update()

    -- Castles
    for _, element in castles() do
        if element == "-" then break
        elseif element[1] == KING then
            self.castle[element[2]][1] = true
        else -- QUEEN
            self.castle[element[2]][2] = true
        end
    end

    self.side = side
    if ep == "-" then self.ep = -1
    else self.ep = squarei(ep) end

    --[[ TODO Not used for now
    self.hmove = hmove
    self.fmove = fmove
    --]]
end --}}}
function Board:make_move(move) --{{{
    local xside = switch_side(self.side)
    local f, t = fromsq(move), tosq(move)
    local fpiece = self:get_piece(f)
    local tpiece = self:get_piece(t)

    -- Clear pieces
    self.bitboard.pieces[self.side][fpiece]:clrbit(f)
    if tstbit(move, CAPTURE) then
        self.bitboard.pieces[xside][tpiece]:clrbit(t)
    elseif tstbit(move, ENPASSANT) then
        local epsq
        if self.side == WHITE then epsq = t - 8
        else epsq = t + 8 end
        self.bitboard.pieces[xside][PAWN]:clrbit(epsq)
    end

    -- Set pieces
    if tstbit(move, PROMOTION) then
        self:set_piece(t, promote_piece(move), self.side, true)
    else
        self:set_piece(t, fpiece, self.side, true)
    end

    -- Castling
    if tstbit(move, CASTLING) then
        local rl, rf
        local iswhite = self.side == WHITE
        if t > f then -- Castle kingside
            rl = iswhite and self.rooks[1] or self.rooks[1] + 56
            rf = iswhite and squarei"f1" or squarei"f8"
        else -- Castle queenside
            rl = iswhite and self.rooks[2] or self.rooks[2] + 56
            rf = iswhite and squarei"c1" or squarei"c8"
        end
        self.bitboard.pieces[WHITE][ROOK]:clrbit(rl)
        self:set_piece(rf, ROOK, self.side, true)
    end

    -- If pawn moved two squares set the enpassant square.
    if fpiece == PAWN and math.abs(f - t) == 16 then
        local epsq = (f + t) / 2
        self.ep = epsq
    else
        self.ep = -1
    end

    self.side = xside
    self:update()
    return true
end
--}}}
