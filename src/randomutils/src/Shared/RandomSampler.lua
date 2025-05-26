--!strict
--[=[
	@class RandomSampler
]=]

local require = require(script.Parent.loader).load(script)

local RandomUtils = require("RandomUtils")

local RandomSampler = {}
RandomSampler.ClassName = "RandomSampler"
RandomSampler.__index = RandomSampler

export type RandomSampler<T> = typeof(setmetatable(
	{} :: {
		_optionsList: { T },
		_shuffledAvailableList: { T },
		_lastSelection: T?,
	},
	{} :: typeof({ __index = RandomSampler })
))

--[=[
	Constructs a new RandomSampler

	@param samples { T } -- The list of samples to sample from
	@return RandomSampler<T>
]=]
function RandomSampler.new<T>(samples): RandomSampler<T>
	local self: RandomSampler<T> = setmetatable({} :: any, RandomSampler)

	self._optionsList = {}
	self._shuffledAvailableList = {}
	self._lastSelection = nil

	if samples then
		self:SetSamples(samples)
	end

	return self
end

--[=[
	Sets the samples to sample from

	@param samples { T } -- The list of samples to sample from
]=]
function RandomSampler.SetSamples<T>(self: RandomSampler<T>, samples: { T })
	assert(type(samples) == "table", "Bad samples")

	if self._optionsList ~= samples then
		self._optionsList = samples

		-- TODO: Smarter refill
		self:Refill()
	end
end

--[=[
	Samples from the list

	@return T -- The sample
]=]
function RandomSampler.Sample<T>(self: RandomSampler<T>): T
	if #self._shuffledAvailableList == 0 then
		self:Refill()
	end

	local selection: T = table.remove(self._shuffledAvailableList) :: any
	self._lastSelection = selection

	return selection
end

--[=[
	Refills the list
]=]
function RandomSampler.Refill<T>(self: RandomSampler<T>)
	local newList = RandomUtils.shuffledCopy(self._optionsList)

	if #newList > 1 then
		-- prevent repeat on restart
		if newList[#newList] == self._lastSelection then
			newList[1], newList[#newList] = newList[#newList], newList[1]
		end
	end

	self._shuffledAvailableList = newList
end

return RandomSampler
