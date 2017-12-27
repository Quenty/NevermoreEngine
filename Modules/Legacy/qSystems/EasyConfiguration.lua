--- A better EasyConfiguration system.
-- @classmod EasyConfiguration
-- @author Quenty

local EasyConfiguration = {}
EasyConfiguration.ClassName = "EasyConfiguration"

function EasyConfiguration.new(container)
	local self = setmetatable({
		_container = container or error("No container")
		}, EasyConfiguration)

	return self
end

function EasyConfiguration:Get(valueName)
	local rbxObj = self._container:FindFirstChild(valueName)
	if not rbxObj then
		error(("[EasyConfiguration] - Value '%s' does not exist"):format(tostring(valueName)))
	end
	return rbxObj
end

function EasyConfiguration:__index(index)
	if EasyConfiguration[index] then
		return EasyConfiguration[index]
	elseif type(index) == "string" then
		local rbxObj = EasyConfiguration.Get(self, index)
		return rbxObj.Value
	else
		error(("[EasyConfiguration] - Bad index of type '%s'"):format(type(index)))
	end
end

function EasyConfiguration:__newindex(index, newindex)
	if EasyConfiguration[index] then
		error(("[EasyConfiguration] - Cannot set '%s'"):format(tostring(index)))
	elseif type(index) == "string" then
		local rbxObj = EasyConfiguration.Get(self, index)
		rbxObj.Value = newindex
	else
		error(("[EasyConfiguration] - Bad index of type '%s'"):format(type(index)))
	end
end

return EasyConfiguration
