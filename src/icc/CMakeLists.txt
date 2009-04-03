# CMakeLists.txt for luachess.fics
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

SET(chess_icc ${PROJECT_SOURCE_DIR}/src/icc/icc.lua)
SET(chess_icc_parser ${PROJECT_SOURCE_DIR}/src/icc/parser.lua)

# Install
INSTALL(FILES ${chess_icc} DESTINATION ${LUAPACKAGE_LDIR}/chess)
INSTALL(FILES ${chess_icc_parser} DESTINATION ${LUAPACKAGE_LDIR}/chess/icc)
