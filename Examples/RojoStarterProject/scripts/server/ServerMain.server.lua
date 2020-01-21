--- Main injection point for the game
-- @script ServerMain

local require = require(game:GetService("ReplicatedStorage"):WaitForChild("Nevermore"))

local SampleClass = require("SampleClass")

print("Server loaded")

SampleClass.new()
