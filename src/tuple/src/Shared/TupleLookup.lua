--!strict
--[=[
	Helps look up tuples that can be used as keys

	@class TupleLookup
]=]

local require = require(script.Parent.loader).load(script)

local Tuple = require("Tuple")

local TupleLookup = {}
TupleLookup.ClassName = "TupleLookup"
TupleLookup.__index = TupleLookup

export type TupleLookup = typeof(setmetatable(
	{} :: {
		_tuples: { [Tuple.Tuple<...any>]: boolean },
		_singleArgTuples: { [any]: Tuple.Tuple<...any> },
	},
	{} :: typeof({ __index = TupleLookup })
))

function TupleLookup.new(): TupleLookup
	local self = setmetatable({}, TupleLookup)

	self._tuples = setmetatable({}, { __mode = "k" })
	self._singleArgTuples = setmetatable({}, { __mode = "kv" })

	return self :: any
end

--[=[
	Gets a shared tuple with a weak table

	@param ... any
	@return Tuple<T...>
]=]
function TupleLookup.ToTuple<T...>(self: TupleLookup, ...): Tuple.Tuple<T...>
	local n = select("#", ...)
	if n == 1 then
		local arg = ...
		if arg ~= nil and self._singleArgTuples[arg] then
			return self._singleArgTuples[arg]
		end
	end

	local created = Tuple.new(...)

	for item, _ in self._tuples do
		if (item :: any) == created then
			return item :: any
		end
	end

	if n == 1 then
		self._singleArgTuples[...] = created
	end
	self._tuples[created] = true

	return created
end

return TupleLookup
