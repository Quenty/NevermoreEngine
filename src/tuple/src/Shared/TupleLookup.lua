--[=[
	Helps look up tuples that can be used as keys

	@class TupleLookup
]=]

local require = require(script.Parent.loader).load(script)

local Tuple = require("Tuple")

local TupleLookup = {}
TupleLookup.ClassName = "TupleLookup"
TupleLookup.__index = TupleLookup

function TupleLookup.new()
	local self = setmetatable({}, TupleLookup)

	self._tuples = setmetatable({}, { __mode = "k"})

	return self
end

--[=[
	Gets a shared tuple with a weak table

	@param ... any
	@return Tuple<T>
]=]
function TupleLookup:ToTuple(...)
	local created = Tuple.new(...)

	for item, _ in pairs(self._tuples) do
		if item == created then
			return item
		end
	end

	self._tuples[created] = true

	return created
end

return TupleLookup