# CMakeLists.txt for LuaChess
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)
PROJECT(luachess)

# {{{ Check for Lua
FIND_PACKAGE(Lua51 REQUIRED)

SET(LUAPACKAGE_CDIR "lib/lua/5.1" CACHE STRING
        "Path for Lua packaged platform specific things.")
SET(LUAPACKAGE_LDIR "share/lua/5.1" CACHE STRING
        "Path for Lua packages platform independent things.")

INCLUDE_DIRECTORIES(
    ${LUA_INCLUDE_DIR}
)
# }}}
# {{{ Set extra CFLAGS
INCLUDE(CheckCCompilerFlag)
CHECK_C_COMPILER_FLAG("-std=c99" HAS_CFLAG_STD_C99)
IF(HAS_CFLAG_STD_C99)
    ADD_DEFINITIONS("-std=c99")
ENDIF(HAS_CFLAG_STD_C99)
CHECK_C_COMPILER_FLAG("-W" HAS_CFLAG_W)
IF(HAS_CFLAG_W)
    ADD_DEFINITIONS("-W")
ENDIF(HAS_CFLAG_W)
CHECK_C_COMPILER_FLAG("-Wall" HAS_CFLAG_WALL)
IF(HAS_CFLAG_WALL)
    ADD_DEFINITIONS("-Wall")
ENDIF(HAS_CFLAG_WALL)
CHECK_C_COMPILER_FLAG("-Winline" HAS_CFLAG_WINLINE)
IF(HAS_CFLAG_WINLINE)
    ADD_DEFINITIONS("-Winline")
ENDIF(HAS_CFLAG_WINLINE)
# }}}
# {{{ Testing
ENABLE_TESTING()
SET(LUNIT ${PROJECT_SOURCE_DIR}/test/lunit/lunit)
SET(TEST_DIR ${PROJECT_SOURCE_DIR}/test)
#}}}
ADD_SUBDIRECTORY(src)