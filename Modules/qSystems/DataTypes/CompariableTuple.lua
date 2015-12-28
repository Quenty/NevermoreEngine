-- Intent: Be able to comparable tuples

local CompariableTuple = {}
CompariableTuple.__index = CompariableTuple
CompariableTuple.ClassName = "CompariableTuple"

function CompariableTuple.new(...)
	local self = setmetatable({}, CompariableTuple)

	self.Args = {...}

	return self
end

function CompariableTuple:__eq(Value)
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

return CompariableTuple