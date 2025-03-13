--[=[
	@class WeightedRandomChooser
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local WeightedRandomChooser = {}
WeightedRandomChooser.ClassName = "WeightedRandomChooser"
WeightedRandomChooser.__index = WeightedRandomChooser

--[=[
	Creates a new weighted random chooser

	@return WeightedRandomChooser<T>
]=]
function WeightedRandomChooser.new()
	local self = setmetatable({}, WeightedRandomChooser)

	self._optionToWeight = {}

	return self
end

--[=[
	Sets the weight for a given option. Setting the weight to nil
	removes the option.

	@param option T
	@param weight number | nil
]=]
function WeightedRandomChooser:SetWeight(option, weight)
	assert(option ~= nil, "Bad option")
	assert(type(weight) == "number" or weight == nil, "Bad weight")

	if self._optionToWeight[option] == weight then
		return
	end

	self._cache = nil
	self._optionToWeight[option] = weight
end

--[=[
	Removes the option from the chooser. Equivalent of setting the weight to nil

	@param option T
]=]
function WeightedRandomChooser:Remove(option)
	self:SetWeight(option, nil)
end

--[=[
	Gets the weight for the option

	@param option T
	@return number | nil
]=]
function WeightedRandomChooser:GetWeight(option): number?
	return self._optionToWeight[option]
end

--[=[
	Gets the percent probability from 0 to 1

	@param option T
	@return number | nil
]=]
function WeightedRandomChooser:GetProbability(option): number?
	local weight = self._optionToWeight[option]
	if weight then
		return nil
	end

	local cache = self:_getOrCreateDataCache()
	return weight / cache.total
end

--[=[
	Picks a weighted choise

	@param random Random
	@return T
]=]
function WeightedRandomChooser:Choose(random: Random?)
	local data = self:_getOrCreateDataCache()

	local randomNum
	if random then
		randomNum = random:NextNumber()
	else
		randomNum = math.random()
	end

	local totalSum = 0

	-- TODO: Binary search
	for i = 1, #data.options do
		totalSum = totalSum + data.weights[i]

		-- TODO: cache threshold?
		local threshold = totalSum / data.total
		if randomNum <= threshold then
			return data.options[i]
		end
	end

	warn("[WeightedRandomChooser.Choose] - Failed to reach threshold! Algorithm is wrong!")
	return data.options[#data.options]
end

function WeightedRandomChooser:_getOrCreateDataCache()
	if self._cache then
		return self._cache
	end

	local options = Table.keys(self._optionToWeight)
	local weights = {}

	local total = 0
	for index, key in pairs(options) do
		local weight = self._optionToWeight[key]
		total = total + weight
		weights[index] = weight
	end

	self._cache = {
		options = options,
		weights = weights,
		total = total,
	}
	return self._cache
end

return WeightedRandomChooser
