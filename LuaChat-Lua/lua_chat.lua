--[[

 lua_chat.lua

 This behaviour allows users to 'chat' over a TCP connection in a manner
 similar to the UNIX 'talk' program.

 Copyright © Blu Wireless. All Rights Reserved.
 Licensed under the MIT license. See LICENSE file in the project.
 Feedback: james@james-pascoe.com

 Install and run:

 1. Install Lua 5.4 from lua.org
 2. sudo luarocks install luaposix
 3. sudo luarocks install luasocket
 3. lua lua_chat <local port> <remote host> <remote port> on both

]]

local socket = require("socket")
local client = nil

function sender (host, port)

  while true do

    local remote, err = socket.connect(host, port)
    while not remote do
      coroutine.yield()

      remote, err = socket.connect(host, port)
    end

    print("Connected to " .. host .. ":" .. port)

    while err ~= "closed" do

      local ret = require "posix".rpoll(0, 1000)
      if (ret == 1) then
        local message = io.read()
        if (message ~= "") then
          _, err = remote:send(message .. "\n")
        end
      else
        _, err = remote:send("\0")
      end

      coroutine.yield()

    end

  end

end

function receiver (port)

  local server = assert(socket.bind("*", port))
  server:settimeout(0.1)

  while true do

    local _, port = server:getsockname()
    print("Waiting for connection on port " .. port);

    local client, err = server:accept()
    if (not client and err == "timeout") then
      coroutine.yield()
    else
      local peer_ip, peer_port = client:getpeername()

      client:send("Connected to LuaChat !\n")
      client:settimeout(0.1)

      while err ~= "closed" do
        local line
        line, err = client:receive("*l")

        if not err then
          print(
            string.format("%s:%d> %s", peer_ip, peer_port, line)
          )
        else
          coroutine.yield()
        end
      end
    end

  end

end

-- Coroutine dispatcher (see Section 9.4 of 'Programming in Lua')
function dispatcher (coroutines)

  while true do
    if next(coroutines) == nil then break end -- no more coroutines to run

    for name, co in pairs(coroutines) do
      local status, res = coroutine.resume(co)

      if res then -- coroutine has returned a result (i.e. finished)

        if type(res) == "string" then  -- runtime error
          print("Lua coroutine '" .. tostring(name) ..
                "' has exited with runtime error " .. res)
        else
          print("Lua coroutine '" .. tostring(name) .. "' exited")
        end

        coroutines[name] = nil

        break
      end
    end
  end
end

print("Welcome to Lua Chat !\n")

if (#arg ~= 3) then
  print("Usage: lua lua_chat.lua <local port> <remote IP> <remote port>")
  os.exit(1)
end

local port, remote_ip, remote_port = tonumber(arg[1]), arg[2], tonumber(arg[3])
print(
  string.format("Starting LuaChat:\n" ..
                "  local port: %d\n" ..
                "  remote IP: %s\n" ..
                "  remote port: %d\n\n", port, remote_ip, remote_port)
)

-- Create co-routines
local coroutines = {}
coroutines["receiver"] = coroutine.create(receiver)
coroutine.resume(coroutines["receiver"], port)

coroutines["sender"] = coroutine.create(sender)
coroutine.resume(coroutines["sender"], remote_ip, remote_port)

-- Run the main loop
dispatcher(coroutines)
