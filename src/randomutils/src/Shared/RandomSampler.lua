--[=[
	@class RandomSampler
]=]

local require = require(script.Parent.loader).load(script)

local RandomUtils = require("RandomUtils")

local RandomSampler = {}
RandomSampler.ClassName = "RandomSampler"
RandomSampler.__index = RandomSampler

function RandomSampler.new(samples)
	local self = setmetatable({}, RandomSampler)

	self._optionsList = {}
	self._shuffledAvailableList = {}

	if samples then
		self:SetSamples(samples)
	end

	return self
end

function RandomSampler:SetSamples(samples)
	assert(type(samples) == "table", "Bad samples")

	if self._optionsList ~= samples then
		self._optionsList = samples

		-- TODO: Smarter refill
		self:Refill()
	end
end

function RandomSampler:Sample()
	if #self._shuffledAvailableList == 0 then
		self:Refill()
	end

	local selection = table.remove(self._shuffledAvailableList)
	self._lastSelection = selection

	return selection
end

function RandomSampler:Refill()
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