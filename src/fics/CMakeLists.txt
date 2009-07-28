# CMakeLists.txt for luachess.fics
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

cmake_minimum_required(VERSION 2.6)

set(chess_fics_utils utils.c)
add_library(chess_fics_utils MODULE ${chess_fics_utils})
set_target_properties(chess_fics_utils PROPERTIES
        PREFIX ""
        OUTPUT_NAME "utils"
)
set(chess_fics ${PROJECT_SOURCE_DIR}/src/fics/fics.lua)
set(chess_fics_parser ${PROJECT_SOURCE_DIR}/src/fics/parser.lua)

# Output
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

# Install
install(TARGETS chess_fics_utils DESTINATION ${LUAPACKAGE_CDIR}/chess/fics)
install(FILES ${chess_fics} DESTINATION ${LUAPACKAGE_LDIR}/chess)
install(FILES ${chess_fics_parser} DESTINATION ${LUAPACKAGE_LDIR}/chess/fics)

