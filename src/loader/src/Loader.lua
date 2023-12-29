--[=[
	Loading logic for Nevermore

	@private
	@class LoaderClass
]=]

local Loader = {}
Loader.ClassName = "Loader"
Loader.__index = Loader

function Loader.new(script)
	return setmetatable({
		_script = script;
		_cache = {}
	}, Loader)
end

local function waitForValue(objectValue)
	local value = objectValue.Value
	if value then
		return value
	end

	return objectValue.Changed:Wait()
end

function Loader:__call(value)
	if type(value) == "string" then
		local cache = rawget(self, "_cache")
		if cache[value] ~= nil then
			return cache[value]
		end

		local object = self._script.Parent[value]
		if object:IsA("ObjectValue") then
			local result = require(waitForValue(object))
			cache[value] = result
			return result
		else
			local result = require(object)
			cache[value] = result
			return result
		end
	else
		return require(value)
	end
end

Loader.__index = Loader.__call

return Loader