--!strict
--[[
    {{pluginName}} initialization script
]]

local root = script.Parent
local loader = root:FindFirstChild("LoaderUtils", true).Parent
local require = (require :: any)(loader).bootstrapPlugin(script) :: typeof(require(root.loader).load(script))

local ServiceBag = require("ServiceBag")

-- Initialize the plugin here
local serviceBag = ServiceBag.new()
serviceBag:Init()
serviceBag:Start()
