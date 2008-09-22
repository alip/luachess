#!/usr/bin/env lua
-- vim: set ft=lua et sts=4 sw=4 ts=4 fdm=marker:
--[[
  Copyright (c) 2008 Ali Polatel <polatel@itu.edu.tr>

  This file is part of LuaFics. LuaFics is free software; you can redistribute
  it and/or modify it under the terms of the GNU General Public License version
  2, as published by the Free Software Foundation.

  LuaFics is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
  A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along with
  this program; if not, write to the Free Software Foundation, Inc., 59 Temple
  Place, Suite 330, Boston, MA  02111-1307  USA
--]]

--- Unit tests for LuaFics parser.

require("lunit")
require("fics")

module("test-parser", package.seeall, lunit.testcase)

function test_prompt_login()
    c = fics.client:new{}
    c.send_ivars = false

    local called = false

    c:register_callback("login", function (client) called = true end)
    c:parseline("login: ")

    assert(called == true, "parsing login failed")
end

function test_prompt_password()
    c = fics.client:new{}

    local called = false

    c:register_callback("password", function (client) called = true end)
    c:parseline("password: ")

    assert(called == true, "parsing password failed")
end

function test_prompt_server()
    c = fics.client:new{}

    local called = false

    c:register_callback("prompt", function (client) called = true end)
    c:parseline("fics% ")

    assert(called == true, "parsing prompt failed")
end

function test_handle_too_short()
    c = fics.client:new{}

    local called = false

    c:register_callback("handle_too_short", function (client) called = true end)
    c:parseline("A name should be at least three characters long. Please try again.")

    assert(called == true, "parsing handle_too_short failed")
end

function test_handle_too_long()
    c = fics.client:new{}

    local called = false

    c:register_callback("handle_too_long", function (client) called = true end)
    c:parseline("Sorry, names may be at most 17 characters long. Please try again.")

    assert(called == true, "parsing handle_too_long failed")
end

function test_handle_not_registered()
    c = fics.client:new{}

    local called = false
    local phandle

    c:register_callback("handle_not_registered", function (client, handle)
        called = true
        phandle = handle
        end)
    c:parseline("\"tsot\" is not a registered name RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing handle_not_registered failed")
    assert(phandle == "tsot", "handle_not_registered failed to grab handle")
end

function test_invalid_password()
    c = fics.client:new{}

    local called = false

    c:register_callback("password_invalid", function (client) called = true end)
    c:parseline("**** Invalid password! **** RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing password_invalid failed")
end

function test_session_start()
    c = fics.client:new{}

    local called = false
    local phandle, ptags

    c:register_callback("session_start", function (client, handle, tags)
        called = true
        phandle = handle
        ptags = tags
        end)
    c:parseline("**** Starting FICS session as blindTal(B)(CA)(*)(SR)")

    assert(called == true, "parsing session_start failed")
    assert(phandle == "blindTal", "session_start failed to grab handle")
    assert(ptags[1] == "B", "session_start failed to grab tags[1]")
    assert(ptags[2] == "CA", "session_start failed to grab tags[2]")
    assert(ptags[3] == "*", "session_start failed to grab tags[3]")
    assert(ptags[4] == "SR", "session_start failed to grab tags[4]")
end

function test_news()
    c = fics.client:new{}

    local called = false
    local pno, pdate, psubject

    c:register_callback("news", function (client, no, date, subject)
        called = true
        pno = no
        pdate = date
        psubject = subject
        end)
    c:parseline("1309 (Thu, Mar 27) FICS user hits 200,000 lightning games!")

    assert(called == true, "parsing news failed")
    assert(pno == 1309, "news failed to grab no")
    assert(pdate == "Thu, Mar 27", "news failed to grab date")
    assert(psubject == "FICS user hits 200,000 lightning games!",
        "news failed to grab subject")
end

function test_messages()
    c = fics.client:new{}

    local called = false
    local ptotal, punread

    c:register_callback("messages", function (client, total, unread)
        called = true
        ptotal = total
        punread = unread
        end)
    c:parseline("You have 10 messages (5 unread)")

    assert(called == true, "parsing messages failed")
    assert(ptotal == 10, "messages failed to grab total")
    assert(punread == 5, "messages failed to grab unread")
end

function test_notify_include()
    c = fics.client:new{}

    local called = false
    local phandles

    c:register_callback("notify_include", function (client, handles)
        called = true
        phandles = handles
        end)
    c:parseline("Present company includes: foo bar baz.")

    assert(called == true, "parsing notify_include failed")
    assert(phandles[1] == "foo", "notify_include failed to grab handle[1]")
    assert(phandles[2] == "bar", "notify_include failed to grab handle[2]")
    assert(phandles[3] == "baz", "notify_include failed to grab handle[3]")
end

function test_notify_note()
    c = fics.client:new{}

    local called = false
    local phandles

    c:register_callback("notify_note", function (client, handles)
        called = true
        phandles = handles
        end)
    c:parseline("Your arrival was noted by: foo bar baz.")

    assert(called == true, "parsing notify_note failed")
    assert(phandles[1] == "foo", "notify_note failed to grab handle[1]")
    assert(phandles[2] == "bar", "notify_note failed to grab handle[2]")
    assert(phandles[3] == "baz", "notify_note failed to grab handle[3]")
end

function test_notify_arrive1()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_arrive", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has arrived and isn't on your notify list.")

    assert(called == true, "parsing notify_arrive failed")
    assert(phandle == "foo", "notify_arrive failed to grab handle")
    assert(pinlist == false, "notify_arrive failed to grab inlist")
end

function test_notify_arrive2()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_arrive", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has arrived RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing notify_arrive failed")
    assert(phandle == "foo", "notify_arrive failed to grab handle")
    assert(pinlist == true, "notify_arrive failed to grab inlist")
end

function test_notify_depart1()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_depart", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has departed and isn't on your notify list.")

    assert(called == true, "parsing notify_depart failed")
    assert(phandle == "foo", "notify_depart failed to grab handle")
    assert(pinlist == false, "notify_depart failed to grab inlist")
end

function test_notify_depart2()
    c = fics.client:new{}

    local called = false
    local phandle, pinlist

    c:register_callback("notify_depart", function (client, handle, inlist)
        called = true
        phandle = handle
        pinlist = inlist
        end)
    c:parseline("Notification: foo has departed RANDOM DATA ATAD MODNAR")

    assert(called == true, "parsing notify_depart failed")
    assert(phandle == "foo", "notify_depart failed to grab handle")
    assert(pinlist == true, "notify_depart failed to grab inlist")
end

