/* Bitboard module for LuaChess.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
 *  based in part upon GNU Chess 5.0 which is
 *  Copyright (c) 1999-2002 Free Software Foundation, Inc.
 *
 * This file is part of LuaChess. LuaChess is free software; you can redistribute
 * it and/or modify it under the terms of the GNU General Public License
 * version 2, as published by the Free Software Foundation.

 * LuaChess is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.

 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#else
#define PACKAGE "luachess"
#define VERSION "?"
#endif

#ifndef __64_BIT_INTEGER_DEFINED__
#define __64_BIT_INTEGER_DEFINED__
typedef unsigned long long U64;
#endif

#define BITBOARD_T "LuaChess.BitBoard"

#ifdef HAVE_STRTOULL
#define STRTOULL_DEFAULT_BASE 16
#endif
