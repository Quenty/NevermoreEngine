--[=[
	See [Binder] for usage.

	@client
	@class HideClient
]=]

local require = require(script.Parent.loader).load(script)

local Binder = require("Binder")

local HideClient = {}
HideClient.ClassName = "HideClient"
HideClient.__index = HideClient

--[=[
	Cleans up the instance
	@param _adornee Instance
	@return HideClient
]=]
function HideClient.new(_adornee: Instance)
	return setmetatable({}, HideClient)
end

--[=[
	Cleans up the instance
]=]
function HideClient:Destroy()
	setmetatable(self, nil)
end

return Binder.new("Hide", HideClient)