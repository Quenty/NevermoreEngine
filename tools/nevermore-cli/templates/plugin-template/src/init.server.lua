--!strict
--[[
    {{pluginName}} initialization script
]]

local loader = script.Parent:FindFirstChild("LoaderUtils", true).Parent
local require = (require :: any)(loader).bootstrapPlugin(script) :: typeof(require(script.Parent.loader).load(script))

local ServiceBag = require("ServiceBag")

-- Initialize the plugin here
local serviceBag = ServiceBag.new()
serviceBag:Init()
serviceBag:Start()