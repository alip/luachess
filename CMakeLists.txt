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
macro(add_c_compiler_flag flag)
    check_c_compiler_flag(${flag} HAS_${flag})
    if(HAS_${flag})
        add_definitions(${flag})
    endif(HAS_${flag})
endmacro()
set(WANTED_CFLAGS
    "-std=c99"               # LuaChess requires a compiler that supports C99.
    "-pedantic"              # Issue all the warnings demanded by strict ISO C and ISO C++.
    "-W" "-Wall" "-Wextra"   # Enable all warnings.
    "-Winline"               # Warn if a function can't be inlined.
    "-Wvla"                  # Warn if variable length array is used in the code.
    "-Wformat=2"             # Enable -Wformat plus format checks not included in -Wformat.
    "-Wformat-security"      # Warn about uses of format functions that represent possible security problems.
    "-Wformat-nonliteral"    # Warn if the format string is not a string literal.
    "-Wlogical-op"           # Warn about suspicious uses of logical operators in expressions.
    "-Winit-self"            # Warn about uninitialized variables which are initialized with themselves.
    "-Wpointer-arith"        # Warn about anything that depends on the "size of" a function type or of "void".
    "-Wfloat-equal"          # Warn if floating point values are used in equality comparisons.
    "-Wmissing-prototypes"   # Warn if a global function is defined without a previous prototype declaration.
    "-Wmissing-declarations" # Warn if a global function is defined without a previous declaration.
    "-Wredundant-decls"      # Warn if anything is declared more than once in the same scope.
    "-Wmissing-noreturn"     # Warn about functions which might be candidates for attribute "noreturn".
    "-Wshadow"               # Warn whenever a local variable shadows another local variable.
    "-Wcast-align"           # Warn whenever a pointer is cast such that the required alignment is increased.
)
foreach(cflag ${WANTED_CFLAGS})
    add_c_compiler_flag(${cflag})
endforeach(cflag ${WANTED_CFLAGS})
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

