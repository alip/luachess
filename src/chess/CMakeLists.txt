# CMakeLists.txt for LuaChess
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

# {{{ Checks
INCLUDE(CheckFunctionExists)
CHECK_FUNCTION_EXISTS(snprintf HAVE_SNPRINTF)
CHECK_FUNCTION_EXISTS(strtoull HAVE_STRTOULL)
INCLUDE(CheckTypeSize)
CHECK_TYPE_SIZE("unsigned long long int" HAVE_UNSIGNED_LONG_LONG_INT)
# }}}

# {{{ Modules
SET(chess_bitboard bitboard.h bitboard.c)
ADD_LIBRARY(chess_bitboard MODULE ${chess_bitboard})
SET_TARGET_PROPERTIES(chess_bitboard PROPERTIES
        PREFIX ""
        OUTPUT_NAME "bitboard"
)

SET(chess_attack bitboard.h attack.c magicmoves.h magicmoves.c)
ADD_LIBRARY(chess_attack MODULE ${chess_attack})
SET_TARGET_PROPERTIES(chess_attack PROPERTIES
        PREFIX ""
        OUTPUT_NAME "attack"
)

SET(chess ${PROJECT_SOURCE_DIR}/src/chess/chess.lua)
SET(chess_move ${PROJECT_SOURCE_DIR}/src/chess/move.lua)
# }}}

# {{{ Tests
ADD_TEST(bitboard lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-bitboard.lua)
ADD_TEST(attack lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-attack.lua)
ADD_TEST(move lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-move.lua)
ADD_TEST(chess lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-chess.lua)
ADD_TEST(chessboard lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-chess-board.lua)
# }}}

# Output
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

# Install
INSTALL(TARGETS chess_bitboard chess_attack DESTINATION ${LUAPACKAGE_CDIR}/chess)
INSTALL(FILES ${chess} DESTINATION ${LUAPACKAGE_LDIR})
INSTALL(FILES ${chess_move} DESTINATION ${LUAPACKAGE_LDIR}/chess)
