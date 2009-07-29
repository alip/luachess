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

--- bitboard module for luachess
module "chess.bitboard"


--- Create a new bitboard
-- @param n number to initialize bitboard.<br />
-- If <a href="http://linux.die.net/man/3/strtoull">strtoull</a>
-- function is available at compile time n can also be a string which will
-- be converted to an unsigned long long using strtoull.
-- @param base If n is a string, this argument specifies the base.<br />
-- Defaults to <b>16</b>.
-- @return bitboard userdata. If the argument is a string and strtoull fails
-- the function returns nil and error message.
function bb(n, base) end

--- Bitboard userdata method to set bits.
-- @param ... indexes of bits to set.
-- These arguments have to be numbers between 0 and 63.
-- @return This function returns nil.
function bb:setbit(...) end

--- Bitboard userdata method to clear bits.
-- @param ... indexes of bits to clear.
-- These arguments have to be numbers between 0 and 63.
-- @return This function returns nil.
function bb:clrbit(...) end

--- Bitboard userdata method to toggle bits.
-- @param ... indexes of bits to toggle.
-- These arguments have to be numbers between 0 and 63.
-- @return This function returns nil.
function bb:tglbit(...) end

--- Bitboard userdata method to test bits.
-- @param index index of the bit to test.
-- @return This function returns a boolean.
function bb:tstbit(index) end

--- Bitboard userdata method to clear bits.<br />
-- This function treats the leftmost bit as position 0 and rightmost bit as position 63.
-- @param ... indexes of bits to clear
-- @see bb:clrbit
function bb:clrbit63(...) end

--- Bitboard userdata method to set bits.<br />
-- This function treats the leftmost bit as position 0 and rightmost bit as position 63.
-- @param ... indexes of bits to set
-- @see bb:setbit
function bb:setbit63(...) end

--- Bitboard userdata method to copy a bitboard.
-- @return This function returns a bitboard userdata equal to the bitboard
-- userdata this function is called from.
function bb:copy() end

--- Bitboard userdata method to return the leading bit in a bitboard.
-- Leftmost bit is 0 and rightmost bit is 63.
-- @return the index of the leading bit
-- @see bb:clrbit63
-- @see bb:setbit63
function bb:leadz() end

--- Bitboard userdata method to return the trailing bit in a bitboard.
-- Leftmost bit is 0 and rightmost bit is 63.
-- @return the index of the trailing bit.
-- @see bb:clrbit63
-- @see bb:setbit63
-- @see bb:leadz
function bb:trailz() end

--- Bitboard metamethod to test equality.
function bb:__eq(self, other) end

--- Bitboard metamethod to test whether a bitboard is little than the other bitboard.
function bb:__lt(self, other) end

--- Bitboard metamethod to test whether a bitboard is little than or equal to
-- the other bitboard.
function bb:__le(self, other) end

--- Bitboard metamethod for adddition.
-- @return A new bitboard which is equal to the bitwise OR of two bitboards.
function bb:__add(self, other) end

--- Bitboard metamethod for subtraction.
-- @return A new bitboard which is equal to the bitwise AND of two bitboards.
function bb:__sub(self, other) end

--- Bitboard metamethod for the modulo operation.
-- @return A new bitboard which is equal to the bitwise XOR of the two
-- bitboards.
function bb:__mod(self, other) end

--- Bitboard metamethod for multiplication.
-- @return A new bitboard which is equal to the first bitboard left shifted by
-- the second bitboard.
function bb:__mul(self, other) end

--- Bitboard metamethod for division.
-- @return A new bitboard which is equal to the first bitboard right shifted by
-- the second bitboard.
function bb:__div(self, other) end

--- Bitboard metamethod for the unary - operation.
-- @return A new bitboard which is equal to bitwise NOT applied to the bitboard.
function bb:__unm(self) end

--- Bitboard metamethod for tostring.<br />
-- This function is available if
-- <a href="http://linux.die.net/man/3/snprintf">snprintf</a> was available at
-- compile time.
-- @return A string representation of the bitboard.
function bb:__tostring(self) end

