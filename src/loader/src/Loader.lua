--- Loading logic
-- @module loader

local Loader = {}
Loader.ClassName = "Loader"
Loader.__index = Loader

function Loader.new(script)
	return setmetatable({
		_script = script;
	}, Loader)
end

function Loader:__call(value)
	if type(value) == "string" then
		return require(self._script.Parent[value])
	else
		return require(value)
	end
end

function Loader:__index(value)
	if type(value) == "string" then
		return require(self._script.Parent[value])
	else
		return require(value)
	end
end


return Loader