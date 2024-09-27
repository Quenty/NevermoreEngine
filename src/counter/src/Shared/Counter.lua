--[=[
	@class Counter
]=]

local require = require(script.Parent.loader).load(script)

local BaseObject = require("BaseObject")
local Maid = require("Maid")
local Observable = require("Observable")
local ValueObject = require("ValueObject")

local Counter = setmetatable({}, BaseObject)
Counter.ClassName = "Counter"
Counter.__index = Counter

--[=[
	Creates a new counter

	@return Counter
]=]
function Counter.new()
	local self = setmetatable(BaseObject.new(), Counter)

	self._count = self._maid:Add(ValueObject.new(0, "number"))

	self.Changed = assert(self._count.Changed, "Bad .Changed")

	return self
end


--[=[
	Returns the current count

	@return number
]=]
function Counter:GetValue()
	return self._count.Value
end

--[=[
	Observes the current count

	@return number
]=]
function Counter:Observe()
	return self._count:Observe()
end


--[=[
	Adds an amount to the counter.

	@param amount number | Observable<number>
	@return MaidTask
]=]
function Counter:Add(amount)
	if type(amount) == "number" then
		self._count.Value = self._count.Value + amount

		local cleanedUp = false
		return function()
			if cleanedUp then
				return
			end

			cleanedUp = true
			if self._count.Destroy then
				self._count.Value = self._count.Value - amount
			end
		end
	elseif Observable.isObservable(amount) then
		return self:_addObservable(amount)
	else
		error("Bad amount")
	end
end

function Counter:_addObservable(observeAmount)
	assert(Observable.isObservable(observeAmount), "Bad observeAmount")

	local lastCount = 0

	local maid = Maid.new()
	maid:GiveTask(observeAmount:Subscribe(function(count)
		assert(type(count) == "number", "Bad count")
		local delta = count - lastCount
		lastCount = count

		self._count.Value = self._count.Value + delta
	end))

	maid:GiveTask(function()
		if not self._count.Destroy then
			return
		end

		local delta = lastCount
		lastCount = 0
		self._count.Value = self._count.Value - delta
	end)

	self._maid[maid] = maid
	maid:GiveTask(function()
		self._maid[maid] = nil
	end)

	return function()
		self._maid[maid] = nil
	end
end

return Counter