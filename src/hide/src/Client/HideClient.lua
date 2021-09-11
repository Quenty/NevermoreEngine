---
-- @classmod HideClient
-- @author Quenty

local HideClient = {}
HideClient.ClassName = "HideClient"
HideClient.__index = HideClient

function HideClient.new(_adornee)
	return setmetatable({}, HideClient)
end

function HideClient:Destroy()

end

return HideClient