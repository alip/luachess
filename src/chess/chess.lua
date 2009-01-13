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
local tonumber = tonumber
local type = type
local unpack = unpack

--XXX for debugging
local print = print
local tostring = tostring

-- Builtin modules
local math = math
local string = string
local table = table

-- Other required modules
local bit = require "bit"

-- Internal modules
require "chess.bitboard"
require "chess.attack"
require "chess.move"
local bitboard = chess.bitboard
local attack = chess.attack
local move = chess.move
--}}}
--{{{Shortcuts to module functions
local band, bnot, bor, bxor, lshift, rshift = bit.band, bit.bnot, bit.bor, bit.bxor,
    bit.lshift, bit.rshift
local bb = bitboard.bb
local atak = attack.atak
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
KINGPRM   = 0x00006000 -- Possible in suicide
PROMOTION = 0x00007000
PAWNCAP   = 0x00008000
KNIGHTCAP = 0x00010000
BISHOPCAP = 0x00018000
ROOKCAP   = 0x00020000
QUEENCAP  = 0x00028000
KINGCAP   = 0x00030000 -- Possible in suicide and giveaway
CAPTURE   = 0x00038000
NULLMOVE  = 0x00100000
CASTLING  = 0x00200000
ENPASSANT = 0x00400000
MOVEMASK  = bor(CASTLING, ENPASSANT, PROMOTION, 0x0FFF)
function tosq(move) return band(move, 0x003F) end
function fromsq(move) return band(rshift(move, 6), 0x003F) end
function MOVE(from, to) return bor(lshift(from, 6), to) end
function capture_piece(move) return band(rshift(move, 15), 0x0007) end
function promote_piece(move) return band(rshift(move, 12), 0x0007) end
--}}}
--{{{Castling flags
WKINGCASTLE = 0x0001
WQUEENCASTLE = 0x0002
BKINGCASTLE = 0x0004
BQUEENCASTLE = 0x0008
WCASTLE = bor(WKINGCASTLE, WQUEENCASTLE)
BCASTLE = bor(BKINGCASTLE, BQUEENCASTLE)
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
        if argtable.flag then
            argtable.flag = assert(tonumber(argtable.flag), "flag not a number")
        end
        assert(not argtable.li_king or (argtable.li_king > -1 and argtable.li_king < 64),
            "li_king is an invalid square")
        assert(not argtable.li_rook or type(argtable.li_rook) == "table",
            "li_rooks not a table")
        if argtable.li_rook then
            assert(argtable.li_rook[1] > -1 and argtable.li_rook[1] < 64,
                "li_rooks[1] is an invalid square")
            assert(argtable.li_rook[2] > -1 and argtable.li_rook[2] < 64,
                "li_rooks[2] is an invalid square")
        end
        if argtable.rhmc then
            argtable.rhmc = assert(tonumber(argtable.rhmc), "rhmove not a number")
        end
        if argtable.fmc then
            argtable.fmc = assert(tonumber(argtable.fmc), "fmove not a number")
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
            -- Castling flags
            flag = argtable.flag or 0,
            -- Initial locations for white rooks and white king.
            -- This is needed to implement fischerandom castling easily.
            li_king = argtable.li_king or squarei"e1",
            li_rook = argtable.li_rook or {squarei"h1", squarei"a1"},
            -- Move counts
            rhmc = argtable.rhmc or 0, -- reversible half move counter
            fmc = argtable.fmc or 1, -- full move counter
            -- Move list
            movelist = {},
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
                        if tstbit(board.flag, WKINGCASTLE) then
                            castles = castles .. "ws=true, "
                        else
                            castles = castles .. "ws=false, "
                        end
                        if tstbit(board.flag, WQUEENCASTLE) then
                            castles = castles .. "wl=true, "
                        else
                            castles = castles .. "wl=false, "
                        end
                        if tstbit(board.flag, BKINGCASTLE) then
                            castles = castles .. "bs=true, "
                        else
                            castles = castles .. "bs=false, "
                        end
                        if tstbit(board.flag, BQUEENCASTLE) then
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
                    elseif rank == 5 then
                        s = s .. "\tReversible half move counter: " .. board.rhmc
                    elseif rank == 4 then
                        s = s .. "\tFull move counter: " .. board.fmc
                    end
                end
                return s
            end
--}}}
        })
    end
    })
--[[ No longer needed
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
--]]
function Board:set_piece(square, piece, side) --{{{
    assert(square > -1 and square < 64, "invalid square")
    assert(piece >= PAWN and piece <= KING, "invalid piece")
    assert(side == WHITE or side == BLACK, "invalid side")
    self.bitboard.pieces[side][piece]:setbit(square)
    self.bitboard.occupied[side]:setbit(square)
    self.bitboard.occupied[3]:setbit(square)
    self.bitboard.occupied[4]:clrbit(square)
    self.cboard[square + 1] = piece
end --}}}
function Board:get_piece(square) --{{{
    assert(square > -1 and square < 64, "invalid square")
    local piece = self.cboard[square + 1]
    if piece == 0 then return nil end
    if self.bitboard.pieces[WHITE][piece]:tstbit(square) then
        return piece, WHITE
    end
    return piece, BLACK
end --}}}
function Board:clear_piece(square, piece, side) --{{{
    assert(square > -1 and square < 64, "invalid square")
    assert(piece >= PAWN and piece <= KING, "invalid piece")
    assert(side == WHITE or side == BLACK, "invalid side")
    self.bitboard.pieces[side][piece]:clrbit(square)
    self.bitboard.occupied[side]:clrbit(square)
    self.bitboard.occupied[3]:clrbit(square)
    self.bitboard.occupied[4]:setbit(square)
    self.cboard[square + 1] = 0
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
    self.ep = -1
    self.flag = 0
    self.rhmc = 0
    self.fmc = 1
    self.movelist = {}
end --}}}
function Board:has_piece(square, side) --{{{
    assert(square > -1 and square < 64, "invalid square")
    assert(not side or side == WHITE or side == BLACK, "invalid side")
    if not side then return self.bitboard.occupied[3]:tstbit(square)
    else return self.bitboard.occupied[side]:tstbit(square) end
end --}}}
function Board:fen() --{{{
    local fen = ""
    for r=8,1,-1 do
        local rank = ""
        local empty_count = 0
        for f=1,8 do
            local square = squarei(string.char(f + 96) .. r)
            local piece, side = self:get_piece(square)
            if not piece then
                empty_count = empty_count + 1
            else
                if empty_count > 0 then
                    rank = rank .. empty_count
                    empty_count = 0
                end
                rank = rank .. piece_tostring(piece, side)
            end
        end
        if empty_count > 0 then rank = rank .. empty_count end
        fen = fen .. rank
        if r ~= 1 then fen = fen .. "/" end
    end

    -- Side to move
    if self.side == WHITE then fen = fen .. " w"
    else fen = fen .. " b" end

    -- Castling rights
    local crights = ""
    if tstbit(self.flag, WKINGCASTLE) then crights = crights .. "K" end
    if tstbit(self.flag, WQUEENCASTLE) then crights = crights .. "Q" end
    if tstbit(self.flag, BKINGCASTLE) then crights = crights .. "k" end
    if tstbit(self.flag, BQUEENCASTLE) then crights = crights .. "q" end
    if crights == "" then crights = "-" end
    fen = fen .. " " .. crights

    -- En passant square
    if self.ep == -1 then fen = fen .. " -"
    else fen = fen .. " " .. squarec(self.ep) end

    -- Move counters
    fen = fen .. " " .. self.rhmc .. " " .. self.fmc

    return fen
end --}}}
function Board:loadfen(fen) --{{{
    fen = fen or "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    local pieces, side, castles, ep, rhmc, fmc = move.fen:match(fen)
    assert(pieces and side and castles and ep and rhmc and fmc, "invalid fen")

    -- Set the pieces
    self:clear_all()
    local sq = 63
    for _, element in pieces() do
        if type(element) == "number" then
            sq = sq - element
        else
            self:set_piece(sq, element[1], element[2])
            sq = sq - 1
        end
    end

    -- Castles
    for _, element in castles() do
        if element == "-" then break
        elseif element[1] == KING then
            if element[2] == WHITE then
                self.flag = bor(self.flag, WKINGCASTLE)
            else
                self.flag = bor(self.flag, BKINGCASTLE)
            end
        else -- QUEEN
            if element[2] == WHITE then
                self.flag = bor(self.flag, WQUEENCASTLE)
            else
                self.flag = bor(self.flag, BQUEENCASTLE)
            end
        end
    end

    self.side = side
    if ep == "-" then self.ep = -1
    else self.ep = squarei(ep) end

    self.rhmc = rhmc
    self.fmc = fmc
end --}}}
function Board:make_move(move) --{{{
    local iswhite = self.side == WHITE
    local xside = switch_side(self.side)
    local f, t = fromsq(move), tosq(move)
    local fpiece = self:get_piece(f)
    local cpiece

    -- Initialize movelist
    if #self.movelist == 0 then
        table.insert(self.movelist, {NULLMOVE, self.flag, self.ep, self.rhmc})
    end

    -- Clear pieces
    self:clear_piece(f, fpiece, self.side)
    if tstbit(move, CAPTURE) then
        cpiece = capture_piece(move)
        self:clear_piece(t, cpiece, xside)
    elseif tstbit(move, ENPASSANT) then
        local epsq = iswhite and t - 8 or t + 8
        self:clear_piece(epsq, PAWN, xside)
    end

    -- Set pieces
    if tstbit(move, PROMOTION) then
        self:set_piece(t, promote_piece(move), self.side)
    else
        self:set_piece(t, fpiece, self.side)
    end

    -- Castling
    if tstbit(move, CASTLING) then
        local rl, rf
        if t > f then -- Castle kingside
            rl = iswhite and self.li_rook[1] or self.li_rook[1] + 56
            rf = iswhite and squarei"f1" or squarei"f8"
        else -- Castle queenside
            rl = iswhite and self.li_rook[2] or self.li_rook[2] + 56
            rf = iswhite and squarei"d1" or squarei"d8"
        end
        self:clear_piece(rl, ROOK, self.side)
        self:set_piece(rf, ROOK, self.side)
        -- Clear castling rights
        if iswhite then self.flag = band(self.flag, bnot(WCASTLE))
        else self.flag = band(self.flag, bnot(BCASTLE)) end
    elseif fpiece == KING then
        -- Clear castling rights
        if iswhite then self.flag = band(self.flag, bnot(WCASTLE))
        else self.flag = band(self.flag, bnot(BCASTLE)) end
    end

    -- Clear the appropriate castling flag if a rook has moved.
    if fpiece == ROOK then
        if iswhite then
            if tstbit(self.flag, WKINGCASTLE) and f == self.li_rook[1] then
                self.flag = band(self.flag, bnot(WKINGCASTLE))
            elseif tstbit(self.flag, WQUEENCASTLE) and f == self.li_rook[2] then
                self.flag = band(self.flag, bnot(WQUEENCASTLE))
            end
        else
            if tstbit(self.flag, BKINGCASTLE) and f == self.li_rook[1] + 56 then
                self.flag = band(self.flag, bnot(BKINGCASTLE))
            elseif tstbit(self.flag, BQUEENCASTLE) and f == self.li_rook[2] + 56 then
                self.flag = band(self.flag, bnot(BQUEENCASTLE))
            end
        end
    end

    -- Clear the appropriate castling flag if a rook has been captured.
    if cpiece == ROOK then
        if xside == WHITE then -- A white rook has been captured.
            if tstbit(self.flag, WKINGCASTLE) and t == self.li_rook[1] then
                self.flag = band(self.flag, bnot(WKINGCASTLE))
            elseif tstbit(self.flag, WQUEENCASTLE) and t == self.li_rook[2] then
                self.flag = band(self.flag, bnot(WQUEENCASTLE))
            end
        else -- A black rook has been captured
            if tstbit(self.flag, BKINGCASTLE) and t == self.li_rook[1] + 56 then
                self.flag = band(self.flag, bnot(BKINGCASTLE))
            elseif tstbit(self.flag, BQUEENCASTLE) and t == self.li_rook[2] + 56 then
                self.flag = band(self.flag, bnot(BQUEENCASTLE))
            end
        end
    elseif cpiece == KING then -- only happens in some wild variants.
        if iswhite then self.flag = band(self.flag, bnot(WCASTLE))
        else self.flag = band(self.flag, bnot(BCASTLE)) end
    end

    -- If pawn moved two squares set the enpassant square.
    if fpiece == PAWN and math.abs(f - t) == 16 then
        self.ep = (f + t) / 2
    else
        self.ep = -1
    end

    -- Update move counters
    if fpiece == PAWN or tstbit(move, CAPTURE) then
        self.rhmc = 0
    else
        self.rhmc = self.rhmc + 1
    end
    if self.side == BLACK then self.fmc = self.fmc + 1 end

    self.side = xside
    table.insert(self.movelist, {move, self.flag, self.ep, self.rhmc})
    return move
end --}}}
function Board:unmake_move() --{{{
    -- If side is black, black is about to move, but we will be undoing a move
    -- by white, not black.
    local mllen = #self.movelist
    assert(mllen > 0, "no moves made yet")
    assert(self.movelist[mllen][1] ~= NULLMOVE, "initial position")
    local move = table.remove(self.movelist)[1]
    local lastmove = self.movelist[mllen - 1]
    local f, t = fromsq(move), tosq(move)
    local fpiece = self:get_piece(t)
    local cpiece = capture_piece(move)
    local side = switch_side(self.side)
    local xside = self.side
    local iswhite = side == WHITE

    self:clear_piece(t, fpiece, side)
    self:set_piece(f, fpiece, side)

    -- If capture, put back the captured piece
    if tstbit(move, CAPTURE) then
        self:set_piece(t, cpiece, xside)
    end

    -- Undo promotion
    if tstbit(move, PROMOTION) then
        self:clear_piece(f, fpiece, side)
        self:set_piece(f, PAWN, side)
    end

    -- Undo enpassant
    if tstbit(move, ENPASSANT) then
        local epsq = iswhite and t - 8 or t + 8
        self:set_piece(epsq, PAWN, xside)
    end

    -- If castling, undo rook move
    if tstbit(move, CASTLING) then
        if iswhite then
            if t == squarei"g1" then -- castle kingside
                self:clear_piece(squarei"f1", ROOK, side)
                self:set_piece(self.li_rook[1], ROOK, side)
            else -- castle queenside
                self:clear_piece(squarei"d1", ROOK, side)
                self:set_piece(self.li_rook[2], ROOK, side)
            end
        else
            if t == squarei"g8" then -- castle kingside
                self:clear_piece(squarei"f8", ROOK, side)
                self:set_piece(self.li_rook[1] + 56, ROOK, side)
            else -- castle queenside
                self:clear_piece(squarei"d8", ROOK, side)
                self:set_piece(self.li_rook[2] + 56, ROOK, side)
            end
        end
    end

    -- Restore castling flags, enpassant square and move counters
    self.flag = lastmove[2]
    self.ep = lastmove[3]
    self.rhmc = lastmove[4]
    if not iswhite then self.fmc = self.fmc - 1 end

    self.side = side
    return move
end --}}}
function Board:move_san(smove) --{{{
    local parsed = move.san_move:match(smove)
    assert(parsed, "invalid SAN move '" .. smove .. "'")

    local xside = switch_side(self.side)
    local iswhite = self.side == WHITE
    local iscastle = parsed.castle_short or parsed.castle_long
    local m, f, t, ffile, frank, ep

    if not iscastle then
        t = squarei(parsed.to)
    end
    -- Determine the origin square.
    if parsed.from then
        if #parsed.from == 2 then
            -- Sweet! Origin square is given :)
            f = squarei(parsed.from)
        elseif #parsed.from == 1 then
            frank = tonumber(parsed.from)
            if not frank then ffile = parsed.from end
        end
    end

    if parsed.castle_short then
        f = iswhite and self.li_king or self.li_king + 56
        t = iswhite and squarei"g1" or squarei"g8"
    elseif parsed.castle_long then
        f = iswhite and self.li_king or self.li_king + 56
        t = iswhite and squarei"c1" or squarei"c8"
    elseif parsed.piece == PAWN then
        local pbb = self.bitboard.pieces[self.side][PAWN]
        if ffile then -- capture
            -- Check the two possible squares
            if iswhite then
                if file(t) ~= 1 then
                    local p1 = t - 9
                    if ffile == filec(p1) and pbb:tstbit(p1) then f = p1 end
                end
                if not f and file(t) ~= 8 then
                    local p2 = t - 7
                    if ffile == filec(p2) and pbb:tstbit(p2) then f = p2 end
                end
            else
                if file(t) ~= 1 then
                    local p1 = t + 7
                    if ffile == filec(p1) and pbb:tstbit(p1) then f = p1 end
                end
                if not f and file(t) ~= 8 then
                    local p2 = t + 9
                    if ffile == filec(p2) and pbb:tstbit(p2) then f = p2 end
                end
            end
            -- Check if this is an enpassant capture.
            if t == self.ep then ep = true end
        else
            -- Simply move down/up until we find another pawn.
            local inc = iswhite and -8 or 8
            local last = iswhite and 0 or 63
            for i=t,last,inc do
                if pbb:tstbit(i) then f = i ; break end
            end
        end
        assert(f, "bad move '" .. smove .. "' no pawn can move to " .. squarec(t))
    else -- piece is either knight, bishop, rook, queen or king.
        if not f then
            local pbb = self.bitboard.pieces[self.side][parsed.piece]
            local attackbb = atak(parsed.piece, t, nil, self.bitboard.occupied[3])
            for sq=0,63 do
                if attackbb:tstbit(sq) then
                    if ((not ffile and not frank) or
                        (ffile and ffile == filec(sq)) or
                        (frank and frank == rank(sq))) and
                        pbb:tstbit(sq) then
                        f = sq
                        break
                    end
                end
            end
        end
        assert(f, "bad move '" .. smove ..
            "' specified piece can't move to " .. squarec(t))
    end

    m = MOVE(f, t)
    if ep then m = bor(m, ENPASSANT) end
    if parsed.capture and not ep then
        local cpiece = self:get_piece(t)
        if cpiece == PAWN then m = bor(m, PAWNCAP)
        elseif cpiece == KNIGHT then m = bor(m, KNIGHTCAP)
        elseif cpiece == BISHOP then m = bor(m, BISHOPCAP)
        elseif cpiece == ROOK then m = bor(m, ROOKCAP)
        elseif cpiece == QUEEN then m = bor(m, QUEENCAP)
        elseif cpiece == KING then m = bor(m, KINGCAP) end
    end
    if parsed.promotion then
        if parsed.promotion == KNIGHT then m = bor(m, KNIGHTPRM)
        elseif parsed.promotion == BISHOP then m = bor(m, BISHOPPRM)
        elseif parsed.promotion == ROOK then m = bor(m, ROOKPRM)
        elseif parsed.promotion == QUEEN then m = bor(m, QUEENPRM) end
    end
    if iscastle then m = bor(m, CASTLING) end

    return self:make_move(m)
end --}}}
