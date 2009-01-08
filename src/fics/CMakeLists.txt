# CMakeLists.txt for luachess.fics
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

SET(chess_fics_utils utils.c)
ADD_LIBRARY(chess_fics_utils MODULE ${chess_fics_utils})
SET_TARGET_PROPERTIES(chess_fics_utils PROPERTIES
        PREFIX ""
        OUTPUT_NAME "utils"
)
SET(chess_fics ${PROJECT_SOURCE_DIR}/src/fics/fics.lua)
SET(chess_fics_parser ${PROJECT_SOURCE_DIR}/src/fics/parser.lua)

# Output
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

# Install
INSTALL(TARGETS chess_fics_utils DESTINATION ${LUAPACKAGE_CDIR}/chess/fics)
INSTALL(FILES ${chess_fics} DESTINATION ${LUAPACKAGE_LDIR}/chess)
INSTALL(FILES ${chess_fics_parser} DESTINATION ${LUAPACKAGE_LDIR}/chess/fics)
