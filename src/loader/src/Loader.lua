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
		local object = self._script.Parent[value]
		if object:IsA("ObjectValue") then
			return require(waitForValue(object))
		else
			return require(object)
		end
	else
		return require(value)
	end
end

function Loader:__index(value)
	if type(value) == "string" then
		local object = self._script.Parent[value]
		if object:IsA("ObjectValue") then
			return require(waitForValue(object))
		else
			return require(object)
		end
	else
		return require(value)
	end
end


return Loader