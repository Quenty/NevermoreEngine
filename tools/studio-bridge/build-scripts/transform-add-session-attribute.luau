local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local inputPath = process.args[1]
local outputPath = process.args[2]
local sessionId = process.args[3]

if not inputPath or not outputPath or not sessionId then
	process.exit(1)
end

local contents = fs.readFile(inputPath)
local game = roblox.deserializePlace(contents)
game:GetService("Workspace"):SetAttribute("StudioBridgeSessionId", sessionId)
local output = roblox.serializePlace(game)
fs.writeFile(outputPath, output)
