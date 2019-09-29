local draw = require(script:WaitForChild("draw"))

local DrawClass = {}
local DrawClass_mt = {__index = DrawClass}

local storage = setmetatable({}, {__mode = "k"})

function DrawClass.new()
	local self = {}

	for k, func in next, draw do
		self[k] = function(_, ...)
			local t = {func(...)}
			for i = 1, #t do
				table.insert(storage[self], t[i])
			end
			return unpack(t)
		end
	end

	storage[self] = {}
	return setmetatable(self, DrawClass_mt)
end

function DrawClass:Clear()
	local t = storage[self]
	while (#t > 0) do
		table.remove(t):Destroy()
	end
	storage[self] = {}
end

return DrawClass