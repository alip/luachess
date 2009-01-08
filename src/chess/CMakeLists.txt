# CMakeLists.txt for LuaChess
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

INCLUDE(CheckFunctionExists)
CHECK_FUNCTION_EXISTS(snprintf HAVE_SNPRINTF)
CHECK_FUNCTION_EXISTS(strtoull HAVE_STRTOULL)
INCLUDE(CheckTypeSize)
CHECK_TYPE_SIZE("unsigned long long int" HAVE_UNSIGNED_LONG_LONG_INT)
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

SET(luachess_BITBOARD bitboard.h bitboard.c)
ADD_LIBRARY(luachess_bitboard_module MODULE ${luachess_BITBOARD})
SET_TARGET_PROPERTIES(luachess_bitboard_module PROPERTIES
        PREFIX ""
        OUTPUT_NAME "bitboard"
)

SET(luachess_ATTACK bitboard.h attack.c magicmoves.h magicmoves.c)
ADD_LIBRARY(luachess_attack_module MODULE ${luachess_ATTACK})
SET_TARGET_PROPERTIES(luachess_attack_module PROPERTIES
        PREFIX ""
        OUTPUT_NAME "attack"
)

SET(LUA_PATH "${PROJECT_SOURCE_DIR}/src/chess/?.lua")
SET(LUA_CPATH "${PROJECT_SOURCE_DIR}/src/chess/?.so")

ADD_TEST(luachess.bitboard ${LUNIT}
        --path "${LUA_PATH}" --cpath "${LUA_CPATH}"
        ${TEST_DIR}/chess/test-bitboard.lua)
ADD_TEST(luachess.attack ${LUNIT}
        --path "${LUA_PATH}" --cpath "${LUA_CPATH}"
        ${TEST_DIR}/chess/test-attack.lua)
ADD_TEST(luachess.move ${LUNIT}
        --path "${LUA_PATH}" --cpath "${LUA_CPATH}"
        ${TEST_DIR}/chess/test-move.lua)
ADD_TEST(luachess.chess ${LUNIT}
        --path "${LUA_PATH}" --cpath "${LUA_CPATH}"
        ${TEST_DIR}/chess/test-chess.lua)
ADD_TEST(luachess.chess.Board ${LUNIT}
        --path "${LUA_PATH}" --cpath "${LUA_CPATH}"
        ${TEST_DIR}/chess/test-chess-board.lua)


