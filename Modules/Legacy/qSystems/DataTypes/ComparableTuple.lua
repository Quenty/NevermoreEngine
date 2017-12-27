--- Be able to compare tuples
-- @classmod ComparableTuple

local ComparableTuple = {}
ComparableTuple.__index = ComparableTuple
ComparableTuple.ClassName = "ComparableTuple"

function ComparableTuple.new(...)
	local self = setmetatable({}, ComparableTuple)

	self.Args = {...}

	return self
end

function ComparableTuple:__eq(Value)
	if #self.Args ~= #Value.Args then
		return false
	end

	local a = self.Args
	local b = Value.Args

	for i=1, #self.Args do
		if a[i] ~= b[i] then
			return false
		end
	end

	return true
end

return ComparableTuple