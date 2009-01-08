# CMakeLists.txt for luachess.fics
# vim: set sw=4 sts=4 et ft=cmake foldmethod=marker foldmarker={{{,}}} :
# Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
# Distributed under the terms of the GNU General Public License v2

CMAKE_MINIMUM_REQUIRED(VERSION 2.6)

# Check for getpwuid() (*NIX) and GetUserName() (Windoze)
INCLUDE(CheckFunctionExists)
CHECK_FUNCTION_EXISTS(getpwuid HAVE_PWUID)
IF(NOT HAVE_PWUID)
    CHECK_FUNCTION_EXISTS(GetUserName HAVE_GETUSERNAME)
    IF(NOT HAVE_GETUSERNAME)
        MESSAGE(FATAL_ERROR "Neither getpwuid() nor GetUserName() found!")
    ENDIF(NOT HAVE_GETUSERNAME)
ENDIF(NOT HAVE_PWUID)

SET(luachess_FICSUTILS ficsutils.c)
ADD_LIBRARY(luachess_ficsutils_module MODULE ${luachess_FICSUTILS})
SET_TARGET_PROPERTIES(luachess_ficsutils_module PROPERTIES
        PREFIX ""
        OUTPUT_NAME "ficsutils"
)

# Output
CONFIGURE_FILE(${CMAKE_CURRENT_SOURCE_DIR}/config.h.in
        ${CMAKE_CURRENT_BINARY_DIR}/config.h)

