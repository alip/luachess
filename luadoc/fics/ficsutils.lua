#!/usr/bin/env luadoc
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:

--- <a href="http://www.freechess.org">Fics</a> utilities for LuaChess.

module "chess.fics.utils"

--- Encode a string using timeseal.
-- @param string The string to encode.
-- @param norandom If set to true don't use random values while encoding (used for testing.)
-- @return Encoded string
function timeseal_encode(string, norandom) end

--- Get timeseal initialization string.
-- This string has to be encoded and sent to server when connection is established.
function timeseal_init_string() end

--- Turn the integer given as parameter ti= from seekinfo output to table.
-- Used by parser.
-- @param titles Integer given as parameter ti= in seekinfo message.
function titles_totable(titles) end

