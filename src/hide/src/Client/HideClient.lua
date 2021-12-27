--[=[
	See [HideBindersClient] for usage.
	@client
	@class HideClient
]=]

local HideClient = {}
HideClient.ClassName = "HideClient"
HideClient.__index = HideClient

--[=[
	Cleans up the instance
	@param _adornee Instance
	@return HideClient
]=]
function HideClient.new(_adornee)
	return setmetatable({}, HideClient)
end

--[=[
	Cleans up the instance
]=]
function HideClient:Destroy()
	setmetatable(self, nil)
end

return HideClient