# CMakeLists.txt for luachess.icc
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

cmake_minimum_required(VERSION 2.6)

set(chess_icc ${PROJECT_SOURCE_DIR}/src/icc/icc.lua)
set(chess_icc_parser ${PROJECT_SOURCE_DIR}/src/icc/parser.lua)

# Install
install(FILES ${chess_icc} DESTINATION ${LUAPACKAGE_LDIR}/chess)
install(FILES ${chess_icc_parser} DESTINATION ${LUAPACKAGE_LDIR}/chess/icc)

