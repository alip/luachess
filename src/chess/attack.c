/* Attack module for LuaChess.
 * requires the bitboard module.
 * vim: set et ts=4 sts=4 sw=4 fdm=syntax :
 *
 * Copyright (c) 2009 Ali Polatel <polatel@gmail.com>
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

#include "lua.h"
#include "lauxlib.h"

#include "bitboard.h"
#include "magicmoves.h"

#define WHITE 1
#define BLACK 2
#define NOCOLOUR 3

#define PAWN 1
#define KNIGHT 2
#define BISHOP 3
#define ROOK 4
#define QUEEN 5
#define KING 6

/* Prototypes */
LUALIB_API int luaopen_chess_attack(lua_State *L);

static const U64 PAWN_ATTACKS[2][64] = {
    {0, 0, 0, 0, 0, 0, 0, 0,
    0x0000000000020000, 0x0000000000050000, 0x00000000000a0000, 0x0000000000140000,
    0x0000000000280000, 0x0000000000500000, 0x0000000000a00000, 0x0000000000400000,
    0x0000000002000000, 0x0000000005000000, 0x000000000a000000, 0x0000000014000000,
    0x0000000028000000, 0x0000000050000000, 0x00000000a0000000, 0x0000000040000000,
    0x0000000200000000, 0x0000000500000000, 0x0000000a00000000, 0x0000001400000000,
    0x0000002800000000, 0x0000005000000000, 0x000000a000000000, 0x0000004000000000,
    0x0000020000000000, 0x0000050000000000, 0x00000a0000000000, 0x0000140000000000,
    0x0000280000000000, 0x0000500000000000, 0x0000a00000000000, 0x0000400000000000,
    0x0002000000000000, 0x0005000000000000, 0x000a000000000000, 0x0014000000000000,
    0x0028000000000000, 0x0050000000000000, 0x00a0000000000000, 0x0040000000000000,
    0x0200000000000000, 0x0500000000000000, 0x0a00000000000000, 0x1400000000000000,
    0x2800000000000000, 0x5000000000000000, 0xa000000000000000, 0x4000000000000000,
    0, 0, 0, 0, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 0, 0, 0,
    0x0000000000000002, 0x0000000000000005, 0x000000000000000a, 0x0000000000000014,
    0x0000000000000028, 0x0000000000000050, 0x00000000000000a0, 0x0000000000000040,
    0x0000000000000200, 0x0000000000000500, 0x0000000000000a00, 0x0000000000001400,
    0x0000000000002800, 0x0000000000005000, 0x000000000000a000, 0x0000000000004000,
    0x0000000000020000, 0x0000000000050000, 0x00000000000a0000, 0x0000000000140000,
    0x0000000000280000, 0x0000000000500000, 0x0000000000a00000, 0x0000000000400000,
    0x0000000002000000, 0x0000000005000000, 0x000000000a000000, 0x0000000014000000,
    0x0000000028000000, 0x0000000050000000, 0x00000000a0000000, 0x0000000040000000,
    0x0000000200000000, 0x0000000500000000, 0x0000000a00000000, 0x0000001400000000,
    0x0000002800000000, 0x0000005000000000, 0x000000a000000000, 0x0000004000000000,
    0x0000020000000000, 0x0000050000000000, 0x00000a0000000000, 0x0000140000000000,
    0x0000280000000000, 0x0000500000000000, 0x0000a00000000000, 0x0000400000000000,
    0, 0, 0, 0, 0, 0, 0, 0}
};
static const U64 KNIGHT_ATTACKS[64] = {
    0x0000000000020400, 0x0000000000050800, 0x00000000000a1100, 0x0000000000142200,
    0x0000000000284400, 0x0000000000508800, 0x0000000000a01000, 0x0000000000402000,
    0x0000000002040004, 0x8000000005080008, 0x000000000a110011, 0x0000000014220022,
    0x0000000028440044, 0x0000000050880088, 0x00000000a0100010, 0x0000000040200020,
    0x0000000204000402, 0x0000000508000885, 0x0000000a1100110a, 0x0000001422002214,
    0x0000002844004428, 0x0000005088008850, 0x000000a0100010a0, 0x0000004020002040,
    0x0000020400040200, 0x0000050800088500, 0x00000a1100110a00, 0x0000142200221400,
    0x0000284400442800, 0x0000508800885000, 0x0000a0100010a000, 0x0000402000204000,
    0x0002040004020000, 0x0005080008850000, 0x000a1100110a0000, 0x0014220022140000,
    0x0028440044280000, 0x0050880088500000, 0x00a0100010a00000, 0x0040200020400000,
    0x0204000402000000, 0x0508000885000000, 0x0a1100110a000000, 0x1422002214000000,
    0x2844004428000000, 0x5088008850000000, 0xa0100010a0000000, 0x4020002040000000,
    0x0400040200000000, 0x0800088500000000, 0x1100110a00000000, 0x2200221400000000,
    0x4400442800000000, 0x8800885000000000, 0x100010a000000000, 0x2000204000000000,
    0x0004020000000000, 0x0008850000000000, 0x00110a0000000000, 0x0022140000000000,
    0x0044280000000000, 0x0088500000000000, 0x0010a00000000000, 0x0020400000000000
};
static const U64 KING_ATTACKS[64] = {
    0x0000000000000302, 0x0000000000000705, 0x0000000000000e0a, 0x0000000000001c14,
    0x0000000000003828, 0x0000000000007050, 0x000000000000e0a0, 0x000000000000c040,
    0x0000000000030203, 0x0000000000070507, 0x00000000000e0a0e, 0x00000000001c141c,
    0x0000000000382838, 0x0000000000705070, 0x0000000000e0a0e0, 0x0000000000c040c0,
    0x0000000003020300, 0x0000000007050700, 0x000000000e0a0e00, 0x000000001c141c00,
    0x0000000038283800, 0x0000000070507000, 0x00000000e0a0e000, 0x00000000c040c000,
    0x0000000302030000, 0x0000000705070000, 0x0000000e0a0e0000, 0x0000001c141c0000,
    0x0000003828380000, 0x0000007050700000, 0x000000e0a0e00000, 0x000000c040c00000,
    0x0000030203000000, 0x0000070507000000, 0x00000e0a0e000000, 0x00001c141c000000,
    0x0000382838000000, 0x0000705070000000, 0x0000e0a0e0000000, 0x0000c040c0000000,
    0x0003020300000000, 0x0007050700000000, 0x000e0a0e00000000, 0x001c141c00000000,
    0x0038283800000000, 0x0070507000000000, 0x00e0a0e000000000, 0x00c040c000000000,
    0x0302030000000000, 0x0705070000000000, 0x0e0a0e0000000000, 0x1c141c0000000000,
    0x3828380000000000, 0x7050700000000000, 0xe0a0e00000000000, 0xc040c00000000000,
    0x0203000000000000, 0x0507000000000000, 0x0a0e000000000000, 0x141c000000000000,
    0x2838000000000000, 0x5070000000000000, 0xa0e0000000000000, 0x40c0000000000000
};

static int atak(lua_State *L) {
    int piece, square, colour;
    U64 *ret = NULL;
    U64 *occupancy = NULL;

    /* Get function arguments */
    piece = luaL_checkinteger(L, 1);
    if (piece < PAWN || piece > KING)
        return luaL_argerror(L, 1, "invalid piece");
    square = luaL_checkinteger(L, 2);
    if (square < 0 || square > 63)
        return luaL_argerror(L, 2, "invalid square");
    if (!lua_isnoneornil(L, 3)) {
        colour = luaL_checkinteger(L, 3);
        if (colour < WHITE || colour > BLACK)
            return luaL_argerror(L, 3, "invalid colour");
    }
    else colour = NOCOLOUR;
    if (!lua_isnoneornil(L, 4))
        occupancy = luaL_checkudata(L, 4, BITBOARD_T);

    ret = (U64 *)lua_newuserdata(L, sizeof(U64));
    luaL_getmetatable(L, BITBOARD_T);
    lua_setmetatable(L, -2);

    switch (piece) {
        case PAWN:
            if (colour == NOCOLOUR)
                return luaL_argerror(L, 3, "invalid colour");
            *ret = PAWN_ATTACKS[colour - 1][square];
            break;
        case KNIGHT:
            *ret = KNIGHT_ATTACKS[square];
            break;
        case KING:
            *ret = KING_ATTACKS[square];
            break;
        case BISHOP: case ROOK: case QUEEN:
            if (occupancy == NULL)
                return luaL_argerror(L, 4, "invalid occupancy");
            switch (piece) {
                case BISHOP:
                    *ret = Bmagic(square, *occupancy);
                    break;
                case ROOK:
                    *ret = Rmagic(square, *occupancy);
                    break;
                case QUEEN:
                    *ret = Qmagic(square, *occupancy);
                    break;
            }
            break;
    }
    return 1;
}

static const struct luaL_reg attack_global[] = {
    {"atak", atak},
    {NULL, NULL}
};

LUALIB_API int luaopen_chess_attack(lua_State *L) {
    initmagicmoves();
    luaL_register(L, "chess.attack", attack_global);

    /* Push colours */
    lua_pushliteral(L, "WHITE");
    lua_pushinteger(L, WHITE);
    lua_settable(L, -3);

    lua_pushliteral(L, "BLACK");
    lua_pushinteger(L, BLACK);
    lua_settable(L, -3);

    lua_pushliteral(L, "NOCOLOUR");
    lua_pushinteger(L, NOCOLOUR);
    lua_settable(L, -3);

    /* Push pieces */
    lua_pushliteral(L, "PAWN");
    lua_pushinteger(L, PAWN);
    lua_settable(L, -3);

    lua_pushliteral(L, "KNIGHT");
    lua_pushinteger(L, KNIGHT);
    lua_settable(L, -3);

    lua_pushliteral(L, "BISHOP");
    lua_pushinteger(L, BISHOP);
    lua_settable(L, -3);

    lua_pushliteral(L, "ROOK");
    lua_pushinteger(L, ROOK);
    lua_settable(L, -3);

    lua_pushliteral(L, "QUEEN");
    lua_pushinteger(L, QUEEN);
    lua_settable(L, -3);

    lua_pushliteral(L, "KING");
    lua_pushinteger(L, KING);
    lua_settable(L, -3);

    return 1;
}

