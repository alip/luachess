# CMakeLists.txt for LuaChess
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

cmake_minimum_required(VERSION 2.6)
project(luachess)
set(PACKAGE_NAME "luachess")
set(VERSION "0.02")

# {{{ Check for Lua
find_package(Lua51 REQUIRED)

set(LUAPACKAGE_CDIR "lib/lua/5.1" CACHE STRING
        "Path for Lua packaged platform specific things.")
set(LUAPACKAGE_LDIR "share/lua/5.1" CACHE STRING
        "Path for Lua packages platform independent things.")

include_directories(
    ${LUA_INCLUDE_DIR}
)
# }}}
# {{{ Set extra CFLAGS
include(CheckCCompilerFlag)
check_c_compiler_flag("-std=c99" HAS_CFLAG_STD_C99)
if(HAS_CFLAG_STD_C99)
    add_definitions("-std=c99")
endif(HAS_CFLAG_STD_C99)
check_c_compiler_flag("-W" HAS_CFLAG_W)
if(HAS_CFLAG_W)
    add_definitions("-W")
endif(HAS_CFLAG_W)
check_c_compiler_flag("-Wall" HAS_CFLAG_WALL)
if(HAS_CFLAG_WALL)
    add_definitions("-Wall")
endif(HAS_CFLAG_WALL)
check_c_compiler_flag("-Winline" HAS_CFLAG_WINLINE)
if(HAS_CFLAG_WINLINE)
    add_definitions("-Winline")
endif(HAS_CFLAG_WINLINE)
# }}}
# {{{ Testing
enable_testing()
set(TEST_DIR ${PROJECT_SOURCE_DIR}/test)
set(GET_LUAUNIT "package.path = [[${TEST_DIR}/?.lua;]] .. package.path")
#}}}

option(WITH_FICS "Build chess.fics module" ON)
option(WITH_ICC  "Build chess.icc module" ON)

add_subdirectory(src/chess)
if(WITH_FICS)
    add_subdirectory(src/fics)
endif(WITH_FICS)
if(WITH_ICC)
    add_subdirectory(src/icc)
endif(WITH_ICC)

