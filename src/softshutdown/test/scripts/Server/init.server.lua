--[[
	This bootstraps both the server and the client code for pretty soft shutdown logic.

	Originally written by Merely, this is Quenty's version of it from here:
	https://github.com/Quenty/NevermoreEngine

	This version supports a nice UI and reserved servers in a normal usage.

	INSTRUCTIONS:
	Insert into ServerScriptService. This script will take care of the rest of it.

	HELP:
	Tweet @quenty on Twitter


	----
	MIT License

	Copyright (c) 2014-2022 Quenty

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
	----

	@class SoftShutdown
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

if true then
	error("TODO: Update this code before publishing again to support new loader")
end

local client, server, shared = require(script:FindFirstChild("LoaderUtils", true)).toWallyFormat(script.src, false)

server.Name = "_SoftShutdownServerPackages"
server.Parent = script

client.Name = "_SoftShutdownClientPackages"
client.Parent = ReplicatedFirst

shared.Name = "_SoftShutdownSharedPackages"
shared.Parent = ReplicatedFirst

local clientScript = script.ClientScript
clientScript.Name = "QuentySoftShutdownClientScript"
clientScript:Clone().Parent = ReplicatedFirst

local serviceBag = require(server.ServiceBag).new()
serviceBag:GetService(require(server.SoftShutdownService))

serviceBag:Init()
serviceBag:Start()