--[[

 lua_chat.lua

 This behaviour allows users to 'chat' over a TCP connection in a manner
 similar to the UNIX 'talk' program.

 Copyright © Blu Wireless. All Rights Reserved.
 Licensed under the MIT license. See LICENSE file in the project.
 Feedback: james@james-pascoe.com

]]

local socket = require("socket")
local client = nil

function sender (host, port)

  while true do

    local ret = require "posix".rpoll(0, 1000)
    if (ret == 1) then
      local message = io.read()
      if (message ~= "" and client) then
        client:send(message .. "\n")
      end
    end

    coroutine.yield()

  end

end

function receiver (host, port)

  local server = assert(socket.bind("*", 0))
  server:settimeout(0.1)

  while true do

local ip, port = server:getsockname()
print("Waiting for connection on " .. ip .. " port " .. port);

local err
client, err = server:accept()
if (not client and err == "timeout") then
  coroutine.yield()
else
  client:send("Welcome to LuaChat !\n")
  client:settimeout(0.1)

  local err = ""
  while err ~= "closed" do
    local line
    line, err = client:receive()

    if not err then
      print("Received: " .. line)
    else
      coroutine.yield()
    end
  end
end



    -- Yield until a message arrives, at which point, print it
    --[[
    repeat
      coroutine.yield()
    until talk:IsMessageAvailable()

    message = talk:GetNextMessage()

    Actions.Log.info(
      string.format(
        "Received from %s:%s %s", host, port, message
      )
    )

    print(host .. ":" .. tostring(port) .. "> " .. message)
]]

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

print("Welcome to Lua Chat !")

--[[
if (#arg) then
  print("Arguments passed to Lua:")
  for k,v in pairs(args) do
    print(string.format("  %s %s", tostring(k), tostring(v)))
  end
end

-- Validate and process the command-line arguments. The 'host' parameter
-- specifies the host to connect to (and is mandatory). If the user wishes
-- to run two instances of LuaChat on the same machine (e.g. for testing)
-- then check that the 'port' and 'server_port' arguments are also present.
if (not args or not args["host"]) then
  print("destination hostname (or IP) must be specified " ..
        "e.g. -a host=192.168.1.1")
end

if (args["host"] == "localhost" or args["host"] == "127.0.0.1") then
  if (not args["port"] or not args["server_port"]) then
    print("destination port and server port must be provided " ..
          "when running multiple instances of LuaChat on the " ..
          "same host e.g. -a port=7777 -a server_port=8888")
  end
end
--]]

-- Create co-routines
local coroutines = {}
coroutines["receiver"] = coroutine.create(receiver)
coroutine.resume(coroutines["receiver"], "localhost", 6666)

coroutines["sender"] = coroutine.create(sender)
coroutine.resume(coroutines["sender"], "localhost", 7777)

-- Run the main loop
dispatcher(coroutines)
