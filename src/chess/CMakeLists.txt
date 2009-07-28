# CMakeLists.txt for LuaChess
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

cmake_minimum_required(VERSION 2.6)

# {{{ Checks
include(CheckFunctionExists)
check_function_exists(snprintf HAVE_SNPRINTF)
check_function_exists(strtoull HAVE_STRTOULL)
include(CheckTypeSize)
check_type_size("unsigned long long int" HAVE_UNSIGNED_LONG_LONG_INT)
# }}}

# {{{ Modules
set(chess_bitboard bitboard.h bitboard.c)
add_library(chess_bitboard MODULE ${chess_bitboard})
set_target_properties(chess_bitboard PROPERTIES
        PREFIX ""
        OUTPUT_NAME "bitboard"
)

set(chess_attack bitboard.h attack.c magicmoves.h magicmoves.c)
add_library(chess_attack MODULE ${chess_attack})
set_target_properties(chess_attack PROPERTIES
        PREFIX ""
        OUTPUT_NAME "attack"
)

set(chess ${PROJECT_SOURCE_DIR}/src/chess/chess.lua)
set(chess_move ${PROJECT_SOURCE_DIR}/src/chess/move.lua)
# }}}

# {{{ Tests
add_test(bitboard lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-bitboard.lua)
add_test(attack lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-attack.lua)
add_test(move lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-move.lua)
add_test(chess lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-chess.lua)
add_test(chessboard lua -e ${GET_LUAUNIT} ${TEST_DIR}/chess/test-chess-board.lua)
# }}}

# Output
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

# Install
install(TARGETS chess_bitboard chess_attack DESTINATION ${LUAPACKAGE_CDIR}/chess)
install(FILES ${chess} DESTINATION ${LUAPACKAGE_LDIR})
install(FILES ${chess_move} DESTINATION ${LUAPACKAGE_LDIR}/chess)

