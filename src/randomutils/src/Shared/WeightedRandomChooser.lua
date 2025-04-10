--!strict
--[=[
	@class WeightedRandomChooser
]=]

local require = require(script.Parent.loader).load(script)

local Table = require("Table")

local WeightedRandomChooser = {}
WeightedRandomChooser.ClassName = "WeightedRandomChooser"
WeightedRandomChooser.__index = WeightedRandomChooser

type WeightedRandomChooserCache<T> = { options: { T }, weights: { number }, total: number }

export type WeightedRandomChooser<T> = typeof(setmetatable(
	{} :: {
		_optionToWeight: { [T]: number },
		_cache: WeightedRandomChooserCache<T>?,
	},
	{} :: typeof({ __index = WeightedRandomChooser })
))

--[=[
	Creates a new weighted random chooser

	@return WeightedRandomChooser<T>
]=]
function WeightedRandomChooser.new<T>(): WeightedRandomChooser<T>
	local self: WeightedRandomChooser<T> = setmetatable({} :: any, WeightedRandomChooser)

	self._optionToWeight = {}

	return self
end

--[=[
	Sets the weight for a given option. Setting the weight to nil
	removes the option.

	@param option T
	@param weight number | nil
]=]
function WeightedRandomChooser.SetWeight<T>(self: WeightedRandomChooser<T>, option: T, weight: number | nil)
	assert(option ~= nil, "Bad option")
	assert(type(weight) == "number" or weight == nil, "Bad weight")

	if self._optionToWeight[option] == weight then
		return
	end

	self._cache = nil
	self._optionToWeight[option] = weight :: any
end

--[=[
	Removes the option from the chooser. Equivalent of setting the weight to nil

	@param option T
]=]
function WeightedRandomChooser.Remove<T>(self: WeightedRandomChooser<T>, option: T)
	self:SetWeight(option, nil)
end

--[=[
	Gets the weight for the option

	@param option T
	@return number?
]=]
function WeightedRandomChooser.GetWeight<T>(self: WeightedRandomChooser<T>, option): number?
	return self._optionToWeight[option]
end

--[=[
	Gets the percent probability from 0 to 1

	@param option T
	@return number?
]=]
function WeightedRandomChooser.GetProbability<T>(self: WeightedRandomChooser<T>, option): number?
	local weight = self._optionToWeight[option]
	if not weight then
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
function WeightedRandomChooser.Choose<T>(self: WeightedRandomChooser<T>, random: Random?)
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

function WeightedRandomChooser._getOrCreateDataCache<T>(self: WeightedRandomChooser<T>): WeightedRandomChooserCache<T>
	if self._cache then
		return self._cache
	end

	local options = Table.keys(self._optionToWeight)
	local weights = {}

	local total = 0
	for index, key in options do
		local weight = self._optionToWeight[key]
		total += weight
		weights[index] = weight
	end

	local cache: WeightedRandomChooserCache<T> = {
		options = options,
		weights = weights,
		total = total,
	}
	self._cache = cache
	return cache
end

return WeightedRandomChooser
