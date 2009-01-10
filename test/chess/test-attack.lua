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

-- Unit tests for attack module.
-- Requires luaunit and bitlib/bitop.

require "luaunit"
require "customloaders"

require "bit"
require "chess.bitboard"
require "chess.attack"

local bb = chess.bitboard.bb

local PAWN = chess.attack.PAWN
local KNIGHT = chess.attack.KNIGHT
local BISHOP = chess.attack.BISHOP
local ROOK = chess.attack.ROOK
local QUEEN = chess.attack.QUEEN
local KING = chess.attack.KING

local WHITE = chess.attack.WHITE
local BLACK = chess.attack.BLACK

local atak = chess.attack.atak

TestAttack = {} -- class
    function TestAttack:test_01_invalid_arguments()
        assert(not pcall(atak, PAWN - 1))
        assert(not pcall(atak, KING + 1))
        assert(not pcall(atak, KING, -1))
        assert(not pcall(atak, KING, 64))
        assert(not pcall(atak, PAWN))
        assert(not pcall(atak, PAWN, nil))
        assert(not pcall(atak, PAWN, WHITE - 1))
        assert(not pcall(atak, PAWN, BLACK + 1))
        assert(not pcall(atak, BISHOP))
        assert(not pcall(atak, ROOK, nil))
        assert(not pcall(atak, QUEEN, nil, 1))
    end
    -- TODO we don't check whether bits for unreachable squares are unset.
    function TestAttack:test_02_atak_king()
        for sq=0,63 do
            if sq % 8 ~= 0 then
                -- Can the king move left?
                assert(atak(KING, sq):tstbit(sq - 1),
                    "square=" .. sq .. " attacked=" .. (sq - 1))
                if sq < 56 then
                    -- Can the king move up left?
                    assert(atak(KING, sq):tstbit(sq + 7),
                        "square=" .. sq .. " attacked=" .. (sq + 7))
                end
                if sq > 7 then
                    -- Can the king move down left?
                    assert(atak(KING, sq):tstbit(sq - 9),
                        "square=" .. sq .. " attacked=" .. (sq - 9))
                end
            end
            if sq % 8 ~= 7 then
                -- Can the king move right?
                assert(atak(KING, sq):tstbit(sq + 1),
                    "square=" .. sq .. " attacked=" .. (sq + 1))
                if sq < 56 then
                    -- Can the king move up right?
                    assert(atak(KING, sq):tstbit(sq + 9),
                        "square=" .. sq .. " attacked=" .. (sq + 9))
                end
                if sq > 7 then
                    -- Can the king move down right?
                    assert(atak(KING, sq):tstbit(sq - 7),
                        "square=" .. sq .. " attacked=" .. (sq - 7))
                end
            end
            if sq < 56 then
                -- Can the king move up?
                assert(atak(KING, sq):tstbit(sq + 8),
                    "square=" .. sq .. " attacked=" .. (sq + 8))
            end
            if sq > 7 then
                -- Can the king move down?
                assert(atak(KING, sq):tstbit(sq - 8),
                    "square=" .. sq .. " attacked=" .. (sq - 8))
            end
        end
    end
    function TestAttack:test_03_atak_knight()
        for sq=0,63 do
            -- Two squares up, one square left
            if sq % 8 ~= 0 and sq < 48 then
                assert(atak(KNIGHT, sq):tstbit(sq + 15),
                    "square=" .. sq .. " attacked=" .. (sq + 15))
            end
            -- One square up, two squares left
            if sq % 8 > 1 and sq < 56 then
                assert(atak(KNIGHT, sq):tstbit(sq + 6),
                    "square=" .. sq .. " attacked=" .. (sq + 6))
            end
            -- One square down, two squares left
            if sq % 8 > 1 and sq > 7 then
                assert(atak(KNIGHT, sq):tstbit(sq - 10),
                    "square=" .. sq .. " attacked=" .. (sq - 10))
            end
            -- Two squares down, one square left
            if sq % 8 ~= 0 and sq > 15 then
                assert(atak(KNIGHT, sq):tstbit(sq - 17),
                    "square=" .. sq .. " attacked=" .. (sq - 17))
            end
            -- Two squares down, one square right
            if sq % 8 ~= 7 and sq > 15 then
                assert(atak(KNIGHT, sq):tstbit(sq - 15),
                    "square=" .. sq .. " attacked=" .. (sq - 15))
            end
            -- One square down, two squares right
            if sq % 8 < 6 and sq > 7 then
                assert(atak(KNIGHT, sq):tstbit(sq - 6),
                    "square=" .. sq .. " attacked=" .. (sq - 6))
            end
            -- One square up, two squares right
            if sq % 8 < 6 and sq < 56 then
                assert(atak(KNIGHT, sq):tstbit(sq + 10),
                    "square=" .. sq .. " attacked=" .. (sq + 10))
            end
            -- Two squares up, one square right
            if sq % 8 ~= 7 and sq < 48 then
                assert(atak(KNIGHT, sq):tstbit(sq + 17),
                    "square=" .. sq .. " attacked=" .. (sq + 17))
            end
        end
    end
    function TestAttack:test_04_atak_pawn()
        for sq=0,63 do
            local rank = bit.rshift(sq, 3) + 1
            if rank ~= 1 and rank ~= 8 then
                if sq % 8 ~= 0 then
                    assert(atak(PAWN, sq, WHITE):tstbit(sq + 7),
                        "square=" .. sq .. " attacked=" .. (sq + 7))
                    assert(atak(PAWN, sq, BLACK):tstbit(sq - 9),
                        "square=" .. sq .. " attacked=" .. (sq - 9))
                end
                if sq % 8 ~= 7 then
                    assert(atak(PAWN, sq, WHITE):tstbit(sq + 9),
                        "square=" .. sq .. " attacked=" .. (sq + 9))
                    assert(atak(PAWN, sq, BLACK):tstbit(sq - 7),
                        "square=" .. sq .. " attacked=" .. (sq - 7))
                end
            else
                assert(atak(PAWN, sq, WHITE) == bb(0))
                assert(atak(PAWN, sq, BLACK) == bb(0))
            end
        end
    end
    function TestAttack:test_05_atak_bishop_TODO()
    end
    function TestAttack:test_06_atak_rook_TODO()
    end
    function TestAttack:test_07_atak_queen_TODO()
    end
-- class

ret = LuaUnit:run()
if ret > 0 then os.exit(1) end
